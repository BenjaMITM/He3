//
//  ThumbnailProvider.swift
//  He3 QLExtension
//
//  Created by Carlos D. Santiago on 6/13/20.
//  Copyright © 2020-2021 Carlos D. Santiago. All rights reserved.
//

import QuickLookThumbnailing

@available(OSXApplicationExtension 10.15, *)
class ThumbnailProvider: QLThumbnailProvider {
    
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
		let url = request.fileURL
		
        // There are three ways to provide a thumbnail through a QLThumbnailReply. Only one of them should be used.
        
        // First way: Draw the thumbnail into the current context, set up with UIKit's coordinate system.
        handler(QLThumbnailReply(contextSize: request.maximumSize, currentContextDrawing: { () -> Bool in
            // Draw the thumbnail here.
            
            // Return true if the thumbnail was successfully drawn inside this block.
            return true
        }), nil)
        
        // Second way: Draw the thumbnail into a context passed to your block, set up with Core Graphics's coordinate system.
        handler(QLThumbnailReply(contextSize: request.maximumSize, drawing: { (context) -> Bool in
            // Draw the thumbnail here.
         
            // Return true if the thumbnail was successfully drawn inside this block.
            return true
        }), nil)
		
		
        // Third way: Set an image file URL.
		do {
			let resourceValues = try url.resourceValues(forKeys: Set([.typeIdentifierKey, URLResourceKey.isRegularFileKey]))
			guard let isRegularFileResourceValue = resourceValues.isRegularFile else { handler(nil,nil); return }
			guard isRegularFileResourceValue else { handler(nil,nil); return }
			guard let fileType = resourceValues.typeIdentifier else { handler(nil,nil); return }
			
			if [k.PlayName, k.ItemName].contains(fileType) {
				let resource = fileType == k.PlayName ? k.listIcon : k.itemIcon
				for type in (["png","jpg"]) {
					if let url = Bundle.main.url(forResource: resource, withExtension: type) {
						handler(QLThumbnailReply(imageFileURL: url), nil)
						return
					}
				}
			}
		} catch { }

		handler(nil,nil);
    }
}
