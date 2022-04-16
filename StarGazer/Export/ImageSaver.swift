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
    func saveImageToPNG(url: URL) -> Bool {
        if let data = self.pngData() {
            do {
                try data.write(to: url)
                return true
            } catch {
                print(error.localizedDescription)
            }
        } else {
            print("Couldnt convert data")
        }
        return false
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


    func saveToGallery(metadata: [String: Any]?, orientation: UIImage.Orientation = .up, onSuccess: (() -> ())? = nil, onFailed: (() -> ())? = nil) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in

            // Don't continue if not authorized.
            guard status == .authorized else {
                onFailed?()
                return
            }

            var data = metadata

            var exportImage = self
            if data != nil {
                // Set to proper image orientation
                /*
                var orientation : UIImage.Orientation = .up
                if let imageOrientation = data![kCGImagePropertyOrientation as String] as? Int{
                    orientation = UIImage.Orientation(rawValue: imageOrientation)!
                }
                */
                var exifOrientation = 1
                switch orientation {
                case .up:
                    exifOrientation = 1
                case .down:
                    exifOrientation = 3
                    exportImage = self.rotate(radians: .pi)!
                case .left:
                    exifOrientation = 8
                    exportImage = self.rotate(radians: .pi / 2 * 3)!
                case .right:
                    exifOrientation = 6
                    exportImage = self.rotate(radians: .pi / 2)!
                default:
                    exifOrientation = 1
                }

                print("Exif orientation: \(exifOrientation)")
                print("Image orientation: \(orientation.rawValue)")

                data![kCGImagePropertyOrientation as String] = 1
            } else {
                data = [:]
            }

            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo,
                        data: self.mergeImageData(image: exportImage, with: data! as NSDictionary),
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

    private func rotate(radians: Float) -> UIImage? {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!

        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
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
