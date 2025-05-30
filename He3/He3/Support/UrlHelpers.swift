//
//  UrlHelpers.swift
//  He3 (Helium 3)
//
//  Created by Viktor Oreshkin on 9.5.17.
//  Copyright © 2017 Jaden Geller. All rights reserved.
//  Copyright © 2017-2021 CD M Santiago. All rights reserved.
//

import Foundation
import AppKit

fileprivate var defaults : UserDefaults {
    get {
        return UserDefaults.standard
    }
}

struct UrlHelpers {
    //   Prepends `http://` if scheme no scheme was found
    static func ensureScheme(_ urlString: String) -> String {
        guard let scheme = URL.init(string: urlString)?.scheme, scheme.count > 0 else {
            return "http://" + urlString
        }
        
        return urlString
    }
    
    // https://mathiasbynens.be/demo/url-regex
    static func isValidURL(urlString: String) -> Bool {
		// built-in cache scheme url
		if let url = URL.init(string: urlString), [k.scheme,k.local].contains(url.scheme) {
			let paths = url.pathComponents
			guard paths.count > 2 else { return false }
			guard [k.asset,k.defaults,k.html,k.text].contains(paths[1]) else { return false }
			let keyPath = paths[2]
			
			switch paths[1] {
			case k.asset:
				guard let asset = NSDataAsset.init(name: keyPath) else { return false }
				let data = NSData.init(data: (asset.data))
				guard let string = String.init(data: data as Data, encoding: String.Encoding.utf8) else { return false }
				return string.count > 0
			
			case k.defaults:
				if nil != defaults.object(forKey: keyPath) {
					return true
				}
				
			case k.html, k.text:
				if nil != defaults.object(forKey: keyPath) {
					return true
				}

			default:
				let message = String(format: "Unknown scheme: %@", paths[1])
				fatalError(message)
			}
		}
		
        // swiftlint:disable:next force_try
        if urlString.lowercased().hasPrefix("file:"), let url = URL.init(string: urlString) {
            return FileManager.default.fileExists(atPath:url.path)
        }

        let regex = try! NSRegularExpression(pattern: "^(https?://)[^\\s/$.?#].[^\\s]*$")
        return (regex.firstMatch(in: urlString, range: urlString.nsrange) != nil)
    }
}

// MARK: - Magic Handlers
extension UrlHelpers {
    static func doMagic(_ url: URL) -> URL? {
        //  Skip file urls
        if url.isFileURL { return url }
        return UrlHelpers.Magic(url).newUrl
    }
    
    static func doMagic(stringURL: String) -> URL? {
        let stringURL = UrlHelpers.ensureScheme(stringURL)
        if let url = URL(string: stringURL) {
            return UrlHelpers.doMagic(url)
        } else {
            return nil
        }
    }
    
    class Magic {
        fileprivate var modified: URLComponents
        fileprivate var converted: Bool = false
        public var newUrl: URL? {
            return self.converted ? self.modified.url : nil
        }
        
        fileprivate let url: URL
        fileprivate let urlString: String
        
        init(_ url: URL) {
            self.url = url
            self.urlString = url.absoluteString
            
            self.modified = URLComponents()
            self.modified.scheme = url.scheme
            
            // Paranoind check
            if url.host != nil {
                self.converted = self.hYouTube() ||
                    self.hTwitch() ||
                    self.hVimeo() ||
                    self.hYouku() ||
                    self.hDailyMotion()
            }
        }
    }
}

// MARK: Generic Handler Factory - just replaces prefix
extension UrlHelpers.Magic {
    fileprivate static func genericHandlerFactory(prefix: String, replacement: String) -> ((UrlHelpers.Magic) -> Bool) {
        return { (instance: UrlHelpers.Magic) in
            if instance.urlString.hasPrefix(prefix) {
                let urlStringModified = instance.urlString.replacePrefix(prefix, replacement: replacement)
                if let newComponents = URLComponents(string: urlStringModified) {
                    instance.modified = newComponents
                    return true
                }
            }
            return false
        }
    }
}

// MARK: Youku Handler
extension UrlHelpers.Magic {
    private static let YoukuClosure = UrlHelpers.Magic.genericHandlerFactory(
        prefix: "http://v.youku.com/v_show/id_",
        replacement: "http://player.youku.com/embed/")
    
    fileprivate func hYouku() -> Bool {
        return UrlHelpers.Magic.YoukuClosure(self)
    }
}

// MARK: DailyMotion Handler
extension UrlHelpers.Magic {
    private static let DailyMotionShort = UrlHelpers.Magic.genericHandlerFactory(
        prefix: "http://www.dailymotion.com/video/",
        replacement: "http://www.dailymotion.com/embed/video/")
    
    private static let DailyMotionLong = UrlHelpers.Magic.genericHandlerFactory(
        prefix: "http://dai.ly/video/",
        replacement: "http://www.dailymotion.com/embed/video/")
    
    fileprivate func hDailyMotion() -> Bool {
        return UrlHelpers.Magic.DailyMotionLong(self) ||
            UrlHelpers.Magic.DailyMotionShort(self)
    }
}

// MARK: Twitch.tv Handler
extension UrlHelpers.Magic {
    fileprivate func hTwitch() -> Bool {
        // swiftlint:disable:next force_try
        let TwitchRegExp = try! NSRegularExpression(pattern: "https?://(?:www\\.)?twitch\\.tv/([\\w\\d\\_]+)(?:/([\\w\\d]+))?")
        
        // https://dev.twitch.tv/docs/embed/video-and-clips/
        if let match = TwitchRegExp.firstMatch(in: urlString, range: urlString.nsrange),
            let path = urlString.substring(with:match.range(at: 1)) {
            var magicd = false
            switch path {
            case "directory", "products", "p", "user", "downloads", "jobs", "store", "turbo":
                break
            case "videos":
                if let idString = urlString.substring(with:match.range(at: 2)) {
                    modified.query = "?autoplay=true&parent=com.slashlos.he3&video=v" + idString
                    magicd = true
                }
            case "collections":
                if let idString = urlString.substring(with:match.range(at: 2)) {
                    modified.query = "?autoplay=true&parent=com.slashlos.he3&collection=" + idString
                    magicd = true
                }
            default:
                if let idString = urlString.substring(with:match.range(at:1)) {
                    modified.query = "?autoplay=true&parent=com.slashlos.he3&channel=" + idString
                    magicd = true
                }
            }
            
            if magicd {
                // Enforce https
                modified.scheme = "https"
                modified.host = "player.twitch.tv"
            }
            
            return magicd
        }
        
        return false
    }
}

// MARK: Vimeo Handler
extension UrlHelpers.Magic {
    fileprivate func hVimeo() -> Bool {
        // Enforce https
        let urlStringModified = self.urlString.replacingOccurrences(
            of: "(?:https?://)?(?:www\\.)?vimeo\\.com/(\\d+)",
            with: "https://player.vimeo.com/video/$1",
            options: .regularExpression)
        
        if urlStringModified != self.urlString, let newComponents = URLComponents(string: urlStringModified) {
            self.modified = newComponents
            
            return true
        }
        
        return false
    }
}

// MARK: YouTube Handler
extension UrlHelpers.Magic {
    fileprivate func hYouTube() -> Bool {
        // (video id) (hours)?(minutes)?(seconds)
        // swiftlint:disable:next force_try line_length
        let YTRegExp = try! NSRegularExpression(pattern: "(?:https?://)?(?:www\\.)?(?:youtube\\.com/watch\\?v=|youtu.be/)([\\w\\_\\-]+)(?:[&?]t=(?:(\\d+)h)?(?:(\\d+)m)?(?:(\\d+)s?))?")
        
        if let match = YTRegExp.firstMatch(in: self.urlString, range: self.urlString.nsrange) {
            // Enforce https
            self.modified.scheme = "https"
            self.modified.host = "youtube.com"
            self.modified.path = "/embed/" + self.urlString.substring(with: match.range(at: 1))!
            
            var start = 0
            var multiplier = 60 * 60
            for idx in 2...4 {
                if let tStr = self.urlString.substring(with: match.range(at: idx)), let tInt = Int(tStr) {
                    start += tInt * multiplier
                }
                multiplier /= 60
            }
            if start != 0 {
                self.modified.query = "start=" + String(start)
            }
            
            return true
        }
        
        return false
    }
}

//  read back webloc contents
extension URL {
//  https://medium.com/@francishart/swift-how-to-determine-file-type-4c46fc2afce
    func hasHTMLContent() -> Bool {
        let type = self.pathExtension as CFString
        let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, type, nil)
        
        return UTTypeConformsTo((uti?.takeRetainedValue())!, kUTTypeHTML)
    }
    func hasUserContent() -> Bool {
        let type = self.pathExtension as CFString
        guard let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, type, nil) else { return false }
        
        let utiCheck = uti.takeRetainedValue()
        return  UTTypeConformsTo(utiCheck, kUTTypeContent)
    }
    func hasVideoContent() -> Bool {
        let type = self.pathExtension as CFString
        guard let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, type, nil) else { return false }
        
        let utiCheck = uti.takeRetainedValue()
        return UTTypeConformsTo(utiCheck, kUTTypeMovie) || UTTypeConformsTo(utiCheck, kUTTypeVideo)
    }
    func hasDataContent() -> Bool {
        let type = self.pathExtension as CFString
        guard let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, type, nil) else { return false }
        
        let utiCheck = uti.takeRetainedValue()
        return UTTypeConformsTo(utiCheck, kUTTypeData) && !self.hasVideoContent() && !self.hasHTMLContent()
    }
    var webloc : URL? {
        get {
            guard pathExtension == k.webloc else { return nil }
            do {
                let data = try Data.init(contentsOf: self) as Data
                let dict = try PropertyListSerialization.propertyList(from:data, options: [], format: nil) as! [String:Any]
                if let urlString = dict["URL"] as? String, let webloc = URL.init(string: urlString) {
                    return webloc
                }
            }
            catch
            {
            }
            return nil
        }
    }
    
    var resourceSpecifier: String {
        get {
            let nrl : NSURL = self as NSURL
            return nrl.resourceSpecifier ?? self.absoluteString
        }
    }
    var simpleSpecifier: String {
        get {
            let str = self.resourceSpecifier
            return str[2..<str.count]
        }
    }
    
    func hideFileExtensionInPath() -> Bool {
        guard self.isFileURL else { return false }
        
        let fileAttrs = [FileAttributeKey.extensionHidden : "1"]
        let fm = FileManager.default

        do {
            try fm.setAttributes(fileAttrs, ofItemAtPath: self.path)
            return true
        }
        catch let error {
            NSApp.presentError(error)
        }
        return false
    }
    
    func hasDirectory() -> Bool {
        guard let paths = FileManager.default.componentsToDisplay(forPath: self.path) else { return false }
        return paths.count > 0
    }
    func settingDirectoryPath(_ value: String) -> URL {
        let components = NSURLComponents.init(url: self, resolvingAgainstBaseURL: true)
        let path = components?.path ?? "/"
        components?.path = value + "/" + path
        return (components?.url!)!
    }
    func settingScheme(_ value: String) -> URL {
        let components = NSURLComponents.init(url: self, resolvingAgainstBaseURL: true)
        components?.scheme = value
        return (components?.url!)!
    }
    
    //  TAD encoded resource name URLs for data, html, text, …
    init?(cache data: Data) {
        let name = String(format: "data/%@", String.timestamp())
        self = URL.init(string: String(format: "%@:///%@", k.local, name))!
        
        let mime = "data/data"
        let text = data.hexEncodedString()
        let dict = [k.mime : mime, k.text : text]
        
        defaults.set(dict, forKey: name)
    }
    init?(cache text: String, embed: Bool = false) {
        let name = String(format: "text/%@", String.timestamp())
        self = URL.init(string: String(format: "%@:///%@", k.local, name))!
        
        let mime = embed ? "text/html" : "text/plain-text"
        let text = embed ? String(format: "<html><body><pre>%@</pre></body></html>", text) : text
        let dict = [k.mime : mime, k.text : text]
        
        defaults.set(dict, forKey: name)
    }
    init?(cache text: NSAttributedString, embed: Bool = true) {
        let name = String(format: "html/%@", String.timestamp())
        self = URL.init(string: String(format: "%@:///%@", k.local, name))!
        
        do {
            let docAttrs = [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.html]
            let data = try text.data(from: NSMakeRange(0, text.length), documentAttributes: docAttrs)
               
            let mime = "text/html"
            let text = data.hexEncodedString()
            let dict = [k.mime : mime, k.text : text]
            
            defaults.set(dict, forKey: name)
        } catch let error as NSError {
            print("attributedString -> data: \(error.code):\(error.localizedDescription): \(text)")
        }
    }
}

extension NSURL {
    
    func compare(_ other: URL ) -> ComparisonResult {
        return (self.absoluteString?.compare(other.absoluteString))!
    }
}

extension URL {
	/// https://stackoverflow.com/a/44945279/564870
	func isFinderAlias() -> Bool? {
		let values = try? self.resourceValues(forKeys: [.isSymbolicLinkKey,.isAliasFileKey])
		let alias = values?.isAliasFile
		let symbolic = values?.isSymbolicLink
		
		guard alias != nil, symbolic != nil else { return nil }
		
		return (alias! && !symbolic!)
	}
}

extension URL {
    func saveAs(responseHandler: @escaping (URL?) -> Void) {
        let savePanel = NSSavePanel()
        
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = self.lastPathComponent
        savePanel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        
        if let keyWindow = NSApp.keyWindow {
            savePanel.beginSheetModal(for: keyWindow, completionHandler: { result in
                responseHandler( result == .OK ? savePanel.url : nil )
             })
        }
        else
        {
            NSApp.activate(ignoringOtherApps: true)
            
            let result = savePanel.runModal()
            responseHandler( result == .OK ? savePanel.url : nil )
        }
    }
}

extension URL {
	func isAcceptableType(_ acceptableTypes: [CFString] =
		[kUTTypeMovie,kUTTypeVideo,kUTTypeImage,kUTTypeText,kUTTypePDF]) -> Bool {
		
		// Non-files pay no never mind
		guard self.isFileURL else { return true }
		
		// Make sure the file contents we can handle
		do {
			let resourceValues = try self.resourceValues(forKeys: Set([.typeIdentifierKey, URLResourceKey.isRegularFileKey]))
			guard let isRegularFileResourceValue = resourceValues.isRegularFile else { return false }
			guard isRegularFileResourceValue else { return false }
			guard let fileType = resourceValues.typeIdentifier else { return false }
			
			for type in acceptableTypes {
				if UTTypeConformsTo(fileType as CFString, type) { return true }
			}
		} catch { }
		
		//	Wah
		return false
	}
}

extension URL {
	//	KUDOS: https://stackoverflow.com/a/59120311/564870
	static var PrivacyServices : URL? {
		return URL(string: "x-apple.systempreferences:com.apple.preference.security")
	}
	static var PrivacyLocationServices : URL? {
		return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
	}
	static var PrivacyMicrophoneServices : URL? {
		return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
	}
	static var PrivaryCameraServices : URL? {
		return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
	}
}
