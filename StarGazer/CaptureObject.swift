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
    
    init(url: URL, time: Date, metadata: [String : Any]) {
        self.url = url
        self.captureTime = time
        self.metadata = metadata
    }
 
    func getURL() -> URL{
        return url
    }
    
    func getCaptureTime() -> Date {
        return captureTime
    }
    
    func toUIImage() -> UIImage {
        let newImage = CIImage(contentsOf: url)!
        return UIImage(cgImage: CIContext().createCGImage(newImage, from: newImage.extent)!, scale: 1.0, orientation: .right)
    }
    
    func deleteReference() {
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as NSError {
            print("Error - Couldn't delete file: \(error.domain)")
        }
    }
}
