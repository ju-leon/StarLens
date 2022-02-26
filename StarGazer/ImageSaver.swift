//
// Created by Leon Jungemeyer on 13.02.22.
//

import Foundation
import Combine
import AVFoundation
import Photos
import UIKit
import CoreLocation
import CoreMotion
import SwiftUI


extension UIImage {
    func saveImageToPNG(url: URL) {
        if let data = self.pngData() {
            do {
                try data.write(to: url)
            } catch {
                print(error.localizedDescription)
            }
        } else {
            print("Couldnt convert data")
        }
    }

    func saveImageToJPG(url: URL) {
        if let data = self.jpegData(compressionQuality: 0.99) {
            do {
                try data.write(to: url)
            } catch {
                print(error.localizedDescription)
            }
        } else {
            print("Couldnt convert data")
        }
    }
    
    
    func saveToGallery(metadata: [String: Any]?, onSuccess: (()->())? = nil, onFailed: (()->())? = nil) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in

            // Don't continue if not authorized.
            guard status == .authorized else {
                return
            }
            
            var data = metadata
            
            if data != nil {
                // Set to proper image orientation
                data![kCGImagePropertyOrientation as String] = self.imageOrientation.rawValue
            } else {
                data = [:]
            }
            
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo,
                        data: self.mergeImageData(image: self, with: data! as NSDictionary),
                        options: nil)


            } completionHandler: { success, error in
                // Process the Photos library error.
                if success {
                    onSuccess?()
                } else {
                    onFailed?()
                }
                
            }

        }
    }
    
    private func mergeImageData(image: UIImage, with metadata: NSDictionary) -> Data {
        let imageData = image.pngData()!
        let source: CGImageSource = CGImageSourceCreateWithData(imageData as NSData, nil)!
        let UTI: CFString = CGImageSourceGetType(source)!
        let newImageData = NSMutableData()
        let cgImage = image.cgImage!

        let imageDestination: CGImageDestination = CGImageDestinationCreateWithData((newImageData as CFMutableData), UTI, 1, nil)!
        CGImageDestinationAddImage(imageDestination, cgImage, metadata as CFDictionary)
        CGImageDestinationFinalize(imageDestination)

        return newImageData as Data
    }
}
