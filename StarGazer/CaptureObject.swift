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
    
    init(url: URL, time: Date) {
        self.url = url
        self.captureTime = time
    }
 
    deinit {
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as NSError {
            print("Error - Couldn't delte file: \(error.domain)")
        }
    }
    
    func getURL() -> URL{
        return url
    }
    
    func getCaptureTime() -> Date {
        return captureTime
    }
}
