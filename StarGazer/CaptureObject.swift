//
//  CaptureObject.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 27.12.21.
//

import Foundation
import UIKit


class CaptureObject {
    let url: URL
    let captureTime: Date
    let exposureBias: Float = 1.0
    let metadata: [String : Any]
    let isRaw: Bool
    
    init(url: URL, time: Date, metadata: [String : Any], isRaw: Bool) {
        self.url = url
        self.captureTime = time
        self.metadata = metadata
        self.isRaw = isRaw
    }
 
    func getURL() -> URL{
        return url
    }
    
    func getCaptureTime() -> Date {
        return captureTime
    }
    
    func toUIImage() -> UIImage {
        var uiImage : UIImage = UIImage()
        
        if isRaw {
            autoreleasepool {
                let newImage = CIImage(contentsOf: url)!
                let cgImage = CIContext().createCGImage(newImage, from: newImage.extent)!
            
                uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            }

        } else {
            let image = loadImage(filename: url)
            if image != nil {
                uiImage = image!
            }
        }
        return uiImage
    }
    
    func deleteReference() {
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as NSError {
            print("Error - Couldn't delete file: \(error.domain)")
        }
    }
    
    private func loadImage(filename: URL) -> UIImage? {
        do {
            let imageData = try Data(contentsOf: filename)
            return UIImage(data: imageData)
        } catch {
            print("Error loading image : \(error)")
        }
        return nil
    }
}
