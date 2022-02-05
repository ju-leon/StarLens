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
    enum PhotoStackingResult: Int {
        case SUCCESS = 0
        case FAILED = 1
        case INIT_FAILED = 2
    }

    // TIME FOR ONE REVOLUTION OF THE EARTH IN SECONDS
    public let STRING_ID: String
    public let EXIF_IDENTIFIER = "StarGazer"

    private let maskEnabled: Bool
    private let alignEnabled: Bool
    private let enhanceEnabled: Bool

    private var coverPhoto: UIImage

    private var stacked: CGImage?
    private var trailing: CGImage?

    private let location: CLLocationCoordinate2D?

    private var captureObjects: [CaptureObject] = []
    private var stacker: OpenCVStacker?;

    private var dispatch: DispatchQueue = DispatchQueue(label: "StarStacker.stackingQueue")

    private let segmentationModel: DeepLabClean
    private let modelInputDimension = [513, 513]

    private var captureProject: Project

    private var initAttempts: Int = 0
    private var MAX_INIT_ATTEMPTS: Int = 3

    //TODO: Init with actual size
    init(mask: Bool, align: Bool, enhance: Bool, location: CLLocationCoordinate2D?) {
        self.STRING_ID = ProcessInfo.processInfo.globallyUniqueString

        let tempDir = FileManager.default.temporaryDirectory
        do {
            try FileManager.default.createDirectory(atPath: tempDir.appendingPathComponent(self.STRING_ID, isDirectory: true).path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error.localizedDescription)
            print("OPEN FAILED??")
            //TODO: HANDLE SOMEHOW
        }

        self.maskEnabled = mask
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

        self.captureProject = Project(url: tempDir.appendingPathComponent(self.STRING_ID),
                captureStart: Date())
    }

    deinit {
    }

    func markEndCapture() {
        self.captureProject.setCaptureEnd(date: Date())
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

    func add(captureObject: CaptureObject, statusUpdateCallback: ((PhotoStackingResult) -> ())?) -> UIImage {
        self.dispatch.async {
            autoreleasepool {

                
                self.captureProject.addUnprocessedPhotoURL(url: captureObject.getURL())
                self.captureProject.setMetadata(data: captureObject.metadata)

                let image = captureObject.toUIImage()
                //self.savePreview(image: image)
                
                self.coverPhoto = image

                let prediction = self.predict(image)
                let maskImage = UIImage(cgImage: prediction!.cgImage()!)

                /**
                 Check if the stacker is called for the first time, if so, we need to init it.
                 */
                if self.stacker == nil {
                    self.stacker = OpenCVStacker.init(image: image, self.maskEnabled)
                    
                    if (self.stacker == nil) {
                        print("Failed to init OpenCVStacker")
                        self.initAttempts += 1

                        if (self.initAttempts > self.MAX_INIT_ATTEMPTS) {
                            print("Failed to init OpenCVStacker after \(self.MAX_INIT_ATTEMPTS) attempts")
                            statusUpdateCallback?(PhotoStackingResult.INIT_FAILED)
                            self.dispatch.suspend()
                            return
                        }
                    }

                } else {
                    /**
                     Otherwise, the photo can be merged
                     */
                    if let stackedImage = self.stacker!.addAndProcess(image, maskImage) {
                        self.coverPhoto = stackedImage
                        self.savePhotoToFile(image: self.coverPhoto, url: self.captureProject.getUrl().appendingPathComponent(PREVIEW_FILE_NAME))

                        statusUpdateCallback?(.SUCCESS)
                    } else {
                        statusUpdateCallback?(.FAILED)
                    }
                }


            }
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

    func saveStack(statusUpdateCallback: ((PhotoStackingResult) -> ())?) {

        print("Saving stack")

        self.dispatch.async {
            let imageStacked = self.stacker!.getProcessedImage()
            self.savePhoto(image: imageStacked)

            self.savePhotoToFile(image: imageStacked, url: self.captureProject.getUrl().appendingPathComponent(AVERAGED_FILE_NAME))

            let imageMaxed = self.stacker!.getPreviewImage()
            self.savePhoto(image: imageMaxed)

            self.savePhotoToFile(image: imageMaxed, url: self.captureProject.getUrl().appendingPathComponent(MAXED_FILE_NAME))

            self.captureProject.save()

            statusUpdateCallback?(PhotoStackingResult.SUCCESS)
            print("Stack exported")

        }
        //savePhoto(image: self.trailing!)
    }

    func mergeImageData(image: UIImage, with metadata: NSDictionary) -> Data {
        let imageData = image.pngData()!
        let source: CGImageSource = CGImageSourceCreateWithData(imageData as NSData, nil)!
        let UTI: CFString = CGImageSourceGetType(source)!
        let newImageData = NSMutableData()
        let cgImage = image.cgImage!

        print(metadata)

        let imageDestination: CGImageDestination = CGImageDestinationCreateWithData((newImageData as CFMutableData), UTI, 1, nil)!
        CGImageDestinationAddImage(imageDestination, cgImage, metadata as CFDictionary)
        CGImageDestinationFinalize(imageDestination)

        return newImageData as Data
    }

    func savePreview(image: UIImage) {
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
    
    func savePhoto(image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in

            // Don't continue if not authorized.
            guard status == .authorized else {
                return
            }

            var data = self.captureProject.getMetadata()!

            if var exifData = data["{Exif}"] as? [String: Any] {
                exifData["ExposureTime"] = Int(self.captureProject.getCaptureEnd()!.timeIntervalSince(self.captureProject.getCaptureStart()))
                data["{Exif}"] = exifData
            }

            if let loc = self.location {
                var locationData: [String: Any] = [:]

                locationData[kCGImagePropertyGPSLatitude as String] = abs(loc.latitude)
                locationData[kCGImagePropertyGPSLongitude as String] = abs(loc.longitude)
                locationData[kCGImagePropertyGPSLatitudeRef as String] = loc.latitude > 0 ? "N" : "S"
                locationData[kCGImagePropertyGPSLongitudeRef as String] = loc.longitude > 0 ? "E" : "W"
                data[kCGImagePropertyGPSDictionary as String] = locationData
            }

            // Set to proper image orientation
            data[kCGImagePropertyOrientation as String] = image.imageOrientation.rawValue

            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo,
                        data: self.mergeImageData(image: image, with: data as NSDictionary),
                        options: nil)


            } completionHandler: { success, error in
                // Process the Photos library error.
            }

        }
    }

    func savePhotoToFile(image: UIImage, url: URL) {
        if let data = image.pngData() {
            do {
                try data.write(to: url)
                print("Saved photo to \(url.path)")

            } catch {
                print(error.localizedDescription)
            }
        } else {
            print("Couldnt convert data")
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
