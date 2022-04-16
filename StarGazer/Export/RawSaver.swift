//
//  RawSever.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 15.04.22.
//

import Foundation
import Photos

class RawSaver {

    static func saveToGallery(url: URL, metadata: [String: Any]?, onSuccess: (() -> ())? = nil, onFailed: ((Error) -> ())? = nil) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in

            // Don't continue if not authorized.
            guard status == .authorized else {
                onFailed?(ExportError.unauthorised)
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, fileURL: url, options: nil)
                               
            } completionHandler: { success, error in
                // Process the Photos library error.
                if success {
                    onSuccess?()
                } else {
                    onFailed?(error!)
                }

            }

        }
    }
    
}
