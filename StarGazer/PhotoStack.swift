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
import CoreML

class PhotoStack {
    // TIME FOR ONE REVOLUTION OF THE EARTH IN SECONDS
    public let STRING_ID: String

    private let hdrEnabled: Bool
    private let alignEnabled: Bool
    private let enhanceEnabled: Bool

    private var coverPhoto: UIImage

    private var stacked: CGImage?
    private var trailing: CGImage?

    private let location: CLLocationCoordinate2D?

    private var captureObjects: [CaptureObject] = []
    private var stacker: OpenCVStacker = OpenCVStacker()

    private var dispatch: DispatchQueue = DispatchQueue(label: "StarStacker.stackingQueue")

    private let segmentationModel: DeepLabClean
    private let modelInputDimension = [513, 513]

    //TODO: Init with actual size
    init(hdr: Bool, align: Bool, enhance: Bool, location: CLLocationCoordinate2D?) {
        self.STRING_ID = ProcessInfo.processInfo.globallyUniqueString

        let tempDir = FileManager.default.temporaryDirectory
        do {
            try FileManager.default.createDirectory(atPath: tempDir.appendingPathComponent(self.STRING_ID, isDirectory: true).path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error.localizedDescription)
        }

        self.hdrEnabled = hdr
        self.alignEnabled = align
        self.enhanceEnabled = enhance

        self.location = location

        self.segmentationModel = DeepLabClean()

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

    deinit {
        self.stacker.reset()
    }

    func toUIImageArray(fromCaptureArray: [CaptureObject]) -> [UIImage] {
        var images: [UIImage] = []
        for captureObject in fromCaptureArray {
            let image = captureObject.toUIImage()
            print(image)
            images.append(image)
        }
        return images
    }

    func resizeImage(_ image: UIImage, _ targetSize: [Int]) -> UIImage? {

        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(CGSize(width: targetSize[0], height: targetSize[1]), false, 1.0)
        image.draw(in: CGRect(x: 0, y: 0, width: targetSize[0], height: targetSize[1]))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }

    func predict(_ image: UIImage) -> MLMultiArray? {
        let resizedImage = resizeImage(image, modelInputDimension)!

        let ciImage = CIImage(cgImage: resizedImage.cgImage!)

        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary

        CVPixelBufferCreate(kCFAllocatorDefault,
                modelInputDimension[0],
                modelInputDimension[1],
                kCVPixelFormatType_32ARGB,
                attrs,
                &pixelBuffer)
        let context = CIContext()
        context.render(ciImage, to: pixelBuffer!)

        if (pixelBuffer != nil) {
            let out = try? self.segmentationModel.prediction(image: pixelBuffer!)
            return out!.output
        } else {
            print("PixelBufferGeneration failed")
            return nil;
        }
    }

    func stackHdr() {
        let copiedStack = self.captureObjects
        captureObjects = []
        self.dispatch.async {
            autoreleasepool {
                let images = self.toUIImageArray(fromCaptureArray: copiedStack)
                let previewImage = self.stacker.hdrMerge(images, self.alignEnabled)

                let prediction = self.predict(self.coverPhoto)
                let maskImage = UIImage(cgImage: prediction!.cgImage()!)

                //self.savePhoto(image: self.coverPhoto)
                self.stacker.addSegmentationMask(maskImage)

                self.coverPhoto = previewImage
            }
            for object in copiedStack {
                object.deleteReference()
            }
        }
    }

    func add(captureObject: CaptureObject) -> UIImage {
        /*
        if (hdrEnabled) {
            self.captureObjects.append(captureObject)
            if (self.captureObjects.count == CameraService.biasRotation.count) {
                stackHdr()
            }
        } else {
            self.dispatch.async {
                let image = captureObject.toUIImage()
                self.savePhoto(image: image)

                self.stacker.addImage(toStack: image)

                let prediction = self.predict(image)
                let maskImage = UIImage(cgImage: prediction!.cgImage()!)
                self.stacker.addSegmentationMask(maskImage)

                let previewImage = self.blendPreview(image1: self.coverPhoto, image2: image)

                self.coverPhoto = previewImage
            }
        }
        */
        //TODO: ENABLE HDR AGAIN

        self.dispatch.async {
            let image = captureObject.toUIImage()
            self.savePhoto(image: image)

            let prediction = self.predict(image)
            let maskImage = UIImage(cgImage: prediction!.cgImage()!)

            self.coverPhoto = self.stacker.addAndProcess(image, maskImage)
        }

        return self.coverPhoto
    }

    func addPhoto(photo: Data) -> UIImage {
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


    func scale(image: CIImage, factor: CGFloat) -> CIImage {
        let scaleDownFilter = CIFilter(name: "CILanczosScaleTransform")!

        let targetSize = CGSize(width: image.extent.width * factor, height: image.extent.height * factor)
        let scale = targetSize.height / (image.extent.height)
        let aspectRatio = targetSize.width / ((image.extent.width) * scale)

        scaleDownFilter.setValue(image, forKey: kCIInputImageKey)
        scaleDownFilter.setValue(scale, forKey: kCIInputScaleKey)
        scaleDownFilter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)

        return scaleDownFilter.outputImage!
    }

    func stackPhotos(_ statusUpdateCallback: ((Double) -> ())?) {
        print("Sceduled merge")
        /*
        self.dispatch.async {
            print("Merging")
            let images = self.toUIImageArray(fromCaptureArray: self.captureObjects)
            self.coverPhoto = self.stacker.hdrMerge(images, self.alignEnabled)

            for captureObject in self.captureObjects {
                captureObject.deleteReference()
            }
            self.captureObjects = []

            statusUpdateCallback?(0.5)

            let imageStacked = self.stacker.composeStack()
            self.savePhoto(image: imageStacked)

            if self.enhanceEnabled {
                // Enhance the image with Apples predefined filters
                let ciImageStacked = self.autoEnhance(CIImage(cgImage: imageStacked.cgImage!))
                self.savePhoto(image: UIImage(ciImage: ciImageStacked))
            }

            statusUpdateCallback?(0.75)

            let imageTrailing = self.stacker.composeTrailing()
            self.savePhoto(image: imageTrailing)

            if self.enhanceEnabled {
                // Enhance the image with Apples predefined filters
                let ciImageTrailing = self.autoEnhance(CIImage(cgImage: imageTrailing.cgImage!))
                self.savePhoto(image: UIImage(ciImage: ciImageTrailing))
            }

            self.coverPhoto = imageStacked

            statusUpdateCallback?(1.0)

        }
      */

        let imageStacked = self.stacker.getProcessedImage()
        self.savePhoto(image: imageStacked)
        statusUpdateCallback?(1.0)
    }

    func saveStack() {
        //savePhoto(image: self.trailing!)
    }

    func savePhoto(image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in

            // Don't continue if not authorized.
            guard status == .authorized else {
                return
            }

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

    private func blendPreview(image1: UIImage, image2: UIImage) -> UIImage {
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
