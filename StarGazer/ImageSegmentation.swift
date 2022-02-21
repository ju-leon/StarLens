//
//  ImageSegmentation.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 21.02.22.
//

import Foundation
import UIKit

class ImageSegementation {

    public static let modelInputDimension = [512, 512]
    
    /**
        Returns segementations for the image of size  @link modelInputDimension
     */
    public static func segementImage(image: UIImage) -> UIImage? {
        let resizedImage = ImageResizer.resizeImage(image, modelInputDimension)!
        if let cgImage = resizedImage.cgImage {
            let ciImage = CIImage(cgImage: cgImage)
            
            var pixelBuffer: CVPixelBuffer?
            let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                         kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary

            CVPixelBufferCreate(kCFAllocatorDefault,
                    modelInputDimension[0],
                    modelInputDimension[1],
                    kCVPixelFormatType_32ARGB,
                    attrs,
                    &pixelBuffer)
            
            if (pixelBuffer == nil) {
                return nil
            }
            
            let context = CIContext()
            context.render(ciImage, to: pixelBuffer!)
            
            let prediction = predict(pixelBuffer: pixelBuffer!)
            
            if (prediction != nil) {
                return UIImage(pixelBuffer: prediction!)
            }
        }
        return nil
    }
    
    private static func predict(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let segmentationModel = try? MobileNet()
        if (segmentationModel == nil) {
            return nil
        }
        
        let out = try? segmentationModel!.prediction(image: pixelBuffer)
        return out?.class_prediction
    }
    
    
}
