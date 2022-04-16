//
//  VideoManager.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 13.04.22.
//

import Foundation
import AssetsLibrary
import Photos


class VideoSaver {
    
    static public func saveToGallery(atUrl: URL, onSuccess: (()->())?, onError: ((Error) -> ())?) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in

            // Don't continue if not authorized.
            guard status == .authorized else {
                onError?(ExportError.unauthorised)
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: atUrl)
            }) { saved, error in
                if saved {
                    onSuccess?()
                } else {
                    onError?(error!)
                }
            }
        }
    }
    
    
}
