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
}