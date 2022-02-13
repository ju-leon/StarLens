//
//  ImageResizer.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 19.12.21.
//

import Foundation
import UIKit

enum ImageResizingError: Error {
    case cannotRetrieveFromURL
    case cannotRetrieveFromData
}

public struct ImageResizer {
    public static func resize(at url: URL, targetWidth: CGFloat) -> UIImage? {
        guard let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }

        return self.resize(image: image, targetWidth: targetWidth)
    }

    public static func resize(image: UIImage, targetWidth: CGFloat) -> UIImage {
        let originalSize = image.size
        let targetSize = CGSize(width: targetWidth, height: targetWidth * originalSize.height / originalSize.width)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { (context) in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    public static func resizeImage(_ image: UIImage, _ targetSize: [Int]) -> UIImage? {
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(CGSize(width: targetSize[0], height: targetSize[1]), false, 1.0)
        image.draw(in: CGRect(x: 0, y: 0, width: targetSize[0], height: targetSize[1]))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }

    public static func resize(data: Data, targetWidth: CGFloat) -> UIImage? {
        guard let image = UIImage(data: data) else {
            return nil
        }
        return resize(image: image, targetWidth: targetWidth)
    }
}

struct MemorySizer {
    static func size(of data: Data) -> String {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useMB] // optional: restricts the units to MB only
        bcf.countStyle = .file
        let string = bcf.string(fromByteCount: Int64(data.count))
        return string
    }
}
