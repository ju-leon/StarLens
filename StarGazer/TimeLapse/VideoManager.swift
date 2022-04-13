//
//  VideoManager.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 13.04.22.
//

import Foundation
import AssetsLibrary
import Photos


class VideoManager {
    
    static public func saveToGallery(atUrl: URL, onSuccess: (()->())?, onError: ((Error) -> ())?) {
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
