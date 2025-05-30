//
//  PlaylistPanelController.swift
//  He3 (Helium 3)
//
//  Created by Carlos D. Santiago on 2/15/17.
//  Copyright © 2017-2021 CD M Santiago. All rights reserved.
//

import Foundation
import AppKit

class PlayItemAccessoryViewController : NSTitlebarAccessoryViewController {
	fileprivate var pvc: PlaylistViewController {
		get {
			return (self.view.window?.contentViewController as! PlaylistViewController)
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(shiftKeyDown(_:)),
			name: .shiftKeyDown,
			object: nil)
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
		
		itemActionButton.state = .off
	}
	
	@objc internal func shiftKeyDown(_ note: Notification) {
		//	Don't bother unless we're a first responder
		guard self.view.window == NSApp.keyWindow else { return }
		
		let keyPaths = ["itemActionImage","itemActionToolTip"]
		for keyPath in (keyPaths)
		{
			willChangeValue(forKey: keyPath)
		}
		
		itemActionButton.state = shiftKeyDown ? .on : .off
		view.needsDisplay = true
		
		for keyPath in (keyPaths)
		{
			didChangeValue(forKey: keyPath)
		}
	}
	
	var shiftKeyDown : Bool {
		get {
			return (NSApp.delegate as! AppDelegate).shiftKeyDown
		}
	}

	@objc @IBOutlet weak var itemActionButton: NSButton!
	var menuIconName : String {
		get {
			if shiftKeyDown {
				return "NSActionTemplate"
			}
			else
			{
				return "NSRefreshTemplate"
			}
		}
	}
	@objc @IBOutlet weak var itemActionImage : NSImage! {
		get {
			return NSImage.init(imageLiteralResourceName: self.menuIconName)
		}
		set (value) {
			
		}
	}
	@objc @IBOutlet weak var itemActionToolTip : NSString! {
		get {
			if shiftKeyDown {
				return "Consolidate"
			}
			else
			{
				return "Resequence"
			}
		}
		set (value) {
			
		}
	}

	@objc @IBAction func itemAction(_ sender: NSButton) {
		pvc.itemAction(sender)
	}
}

class PlaylistPanelController : NSWindowController,NSWindowDelegate {
    
	fileprivate var appDelegate : AppDelegate {
		get {
			return NSApp.delegate as! AppDelegate
		}
	}
	fileprivate var doc: Document? {
		get {
			return self.document as? Document
		}
	}
	fileprivate var settings: Settings? {
		get {
			return doc?.settings
		}
	}
    fileprivate var panel: NSPanel! {
        get {
            return (self.window as! NSPanel)
        }
    }
    fileprivate var pvc: PlaylistViewController {
        get {
            return (self.window?.contentViewController as! PlaylistViewController)
        }
    }

    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        return (document?.displayName)!
    }
	
	var rvc : PlayItemAccessoryViewController {
		return self.window?.titlebarAccessoryViewControllers.first as! PlayItemAccessoryViewController
	}
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
		//	Our right view controller replaces playitem tableView cornerView
		let rvc = storyboard!.instantiateController(withIdentifier: "PlayItemAccesoryViewController") as! PlayItemAccessoryViewController
		rvc.layoutAttribute = .trailing
		rvc.isHidden = false
		self.panel.addTitlebarAccessoryViewController(rvc)

        panel.isFloatingPanel = true
        
        //  Relocate to origin if any
        panel.windowController?.shouldCascadeWindows = true///.offsetFromKeyWindow()
    }
	
	func windowDidMove(_ notification: Notification) {
		if let sender : NSWindow = notification.object as? NSWindow, sender == self.window {
			if let doc : Document = self.document as? Document {
				doc.settings.rect.value = sender.frame
			}
			
			if let doc = panel.windowController?.document {
				doc.updateChangeCount(appDelegate.openForBusiness ? .changeDone : .changeCleared)
			}
		}
	}
	func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
		if sender == self.window {
			if let doc = self.doc {
				doc.settings.rect.value = sender.frame
			}
			
			if let doc = panel.windowController?.document {
				doc.updateChangeCount(appDelegate.openForBusiness ? .changeDone : .changeCleared)
			}
		}
		return frameSize
	}
	
	func windowShouldClose(_ sender: NSWindow) -> Bool {
		//  Switch to playlist view windowShouldClose() on close
		return pvc.windowShouldClose(sender)
	 }

}
