//
//  PhotoStack.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 21.12.21.
//

import Foundation
import UIKit
import Photos
import Accelerate
import CoreImage
import Vision

class PhotoStack {
    // TIME FOR ONE REVOLUTION OF THE EARTH IN SECONDS
    public let STRING_ID : String
    
    private var coverPhoto : UIImage
    
    private var stacked : CGImage?
    private var trailing : CGImage?
    
    private var location: CLLocationCoordinate2D
    
    private var captureObjects: [CaptureObject] = []
    private var stacker: OpenCVStacker = OpenCVStacker()
    
    //TODO: Init with actual size
    init(location: CLLocationCoordinate2D) {
        self.STRING_ID = ProcessInfo.processInfo.globallyUniqueString
        
        let tempDir = FileManager.default.temporaryDirectory
        do {
            try FileManager.default.createDirectory(atPath: tempDir.appendingPathComponent(self.STRING_ID, isDirectory: true).path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error.localizedDescription)
        }
        
        self.location = location
        
        // Init the photo to a black photo
        let imageSize = CGSize(width: 300, height: 400)
        let color: UIColor = .black
        UIGraphicsBeginImageContextWithOptions(imageSize, true, 0)
        let context = UIGraphicsGetCurrentContext()!
        color.setFill()
        context.fill(CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        coverPhoto = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
    }
    
    func setLocation(location: CLLocationCoordinate2D) {
        self.location = location
    }
    
    func toUIImageArray(fromCaptureArray: [CaptureObject]) -> [UIImage] {
        var images: [UIImage] = []
        for captureObject in self.captureObjects {
            let image = captureObject.toUIImage()
            print(image)
            images.append(image)
        }
        return images
    }
    
    func add(captureObject: CaptureObject, preview: Data) -> UIImage {
        self.captureObjects.append(captureObject)
        
        if (self.captureObjects.count == CameraService.biasRotation.count) {
            let images = toUIImageArray(fromCaptureArray: self.captureObjects)
            print(images)
            coverPhoto = self.stacker.hdrMerge(images)
            captureObjects = []
        }
        /*
        let image = UIImage(data: preview)!
        coverPhoto = blendPreview(image1: coverPhoto, image2: image)
        */
        return coverPhoto
    }
    
    func addPhoto(photo: Data) -> UIImage{
        let image = UIImage(data: photo)!
        coverPhoto = blendPreview(image1: coverPhoto, image2: image)
        
        return coverPhoto
    }
    
    func getCoverPhoto() -> UIImage {
        return coverPhoto
    }
    
    func alignImage(request: VNRequest, frame: CIImage, index: Int) -> CIImage? {
        // 1
        guard
            let results = request.results as? [VNImageTranslationAlignmentObservation],
            let result = results.first
        else {
            return nil
        }
        // 2
        
        var transform = result.alignmentTransform
        
        print(transform)
        
        transform.tx = 1000
        transform.ty = 1000
        
        print(transform)
        return frame.transformed(by: CGAffineTransform(rotationAngle: 0.1 * CGFloat(index)))
    }
    
    func autoEnhance(_ image: CIImage) -> CIImage {
        let adjustments = image.autoAdjustmentFilters()
        
        var ciImage = image
        for filter in adjustments {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            if let outputImage = filter.outputImage {
                ciImage = outputImage
            }
        }
        
        return image
        
    }
    
    
    func scale(image: CIImage, factor: CGFloat) -> CIImage{
        let scaleDownFilter = CIFilter(name:"CILanczosScaleTransform")!
        
        let targetSize = CGSize(width:image.extent.width*factor, height:image.extent.height*factor)
        let scale = targetSize.height / (image.extent.height)
        let aspectRatio = targetSize.width/((image.extent.width) * scale)
        
        scaleDownFilter.setValue(image, forKey: kCIInputImageKey)
        scaleDownFilter.setValue(scale, forKey: kCIInputScaleKey)
        scaleDownFilter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)
        
        return scaleDownFilter.outputImage!
    }
    

    
    func stackPhotos(_ statusUpdateCallback: ((Double)->())?) {
        /*
        let firstImage = CIImage(contentsOf: captureObjects[0].getURL())!
        let scaled = scale(image: firstImage, factor: 0.5)
        let firstImageLow = CIImage(cgImage: CIContext().createCGImage(scaled, from: scaled.extent)!)
        
        
        var finalImage = CIImage(cgImage: CIContext().createCGImage(firstImage, from: firstImage.extent)!)
        let filter = AverageStackingFilter()
        
        var image = UIImage(cgImage: CIContext().createCGImage(firstImage, from: firstImage.extent)!)
        
        var images = toUIImageArray(fromCaptureArray: self.captureObjects)
        /*
        for (i, captureObject) in self.captureObjects.dropFirst(1).enumerated(){
            images.append(captureObject.toUIImage())
            
            let progress = Double(i + 1) / Double(captureObjects.count - 1)
            statusUpdateCallback?(progress)
            
        }*/
        
        image = self.stacker.stackImages(images, on: image)
        
        */
        
        let images = toUIImageArray(fromCaptureArray: self.captureObjects)
        coverPhoto = self.stacker.hdrMerge(images)
        captureObjects = []
        
        let image = self.stacker.composeStack()
        savePhoto(image: image)
        
        self.coverPhoto = image
        
        let progress = 1.0 //Double(i + 1) / Double(captureObjects.count - 1)
        statusUpdateCallback?(progress)
        /*
        for (i, captureObject) in self.captureObjects.dropFirst(1).enumerated(){
            print("Stacking \(captureObject.getURL())")
            
            autoreleasepool {
                let context = CIContext()
                let newImage = CIImage(contentsOf: captureObject.getURL())!
                
                let newImageLow = scale(image: newImage, factor: 0.5)
                let newCGImg = context.createCGImage(newImageLow, from: newImageLow.extent)!
                context.clearCaches()
                
                
                print(newImageLow.extent)
                
                let opticalFlowImage = makeOpticalFlowImage(baseImage: firstImageLow, newImage: newCGImg)
                
                let request = VNHomographicImageRegistrationRequest(targetedCIImage: firstImage)
                filter.inputNewImage = alignImage(request: request, frame: newImage)
                filter.inputStackCount = Double(i + 1)
                filter.inputCurrentStack = finalImage
            
                // Prepare for create CGImage
                let cgimg = context.createCGImage(filter.outputImage()!, from: finalImage.extent)!
                context.clearCaches()
                finalImage = CIImage(cgImage: cgimg)
                
                print("Final Image:")
                print(finalImage.extent)
            }
            
            let progress = Double(i + 1) / Double(captureObjects.count - 1)
            statusUpdateCallback?(progress)
        }

        captureObjects = []
  
        let context = CIContext() // Prepare for create CGImage
        let cgimg = context.createCGImage(finalImage, from: finalImage.extent)
        let output = UIImage(cgImage: cgimg!)
        
        self.coverPhoto = output
        self.stacked = cgimg
     */
    }
    
    func saveStack() {
        //savePhoto(image: self.trailing!)
    }
    
    func savePhoto(image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                
                // Don't continue if not authorized.
                guard status == .authorized else { return }
            
                PHPhotoLibrary.shared().performChanges {
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo,
                                                data: image.jpegData(compressionQuality: 0.99)!,
                                                options: nil)
                    
                } completionHandler: { success, error in
                    // Process the Photos library error.
                }
        }
    }
    
    private func blendPreview(image1 : UIImage, image2: UIImage) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: image1.size.width, height: image1.size.height)
        let renderer = UIGraphicsImageRenderer(size: image1.size)

        let result = renderer.image { ctx in
            // fill the background with white so that translucent colors get lighter
            UIColor.black.set()
            ctx.fill(rect)

            image1.draw(in: rect, blendMode: .normal, alpha: 1)
            
            image2.draw(in: rect, blendMode: .lighten, alpha: 1)
        }
        
        return result
    }
}
