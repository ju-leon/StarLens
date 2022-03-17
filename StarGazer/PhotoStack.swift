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

public enum PhotoStackingResult: Int {
    case SUCCESS = 0
    case FAILED = 1
    case INIT_FAILED = 2
}

public class PhotoStack {

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
    private var stacker: OpenCVStacker?

    private var orientation: UIImage.Orientation = .up

    private var dispatch: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Stacking Queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private var captureProject: Project

    private var initAttempts: Int = 0
    private var MAX_INIT_ATTEMPTS: Int = 1

    private var numImages = 0

    init(mask: Bool, align: Bool, enhance: Bool, location: CLLocationCoordinate2D?, orientation: AVCaptureVideoOrientation) {
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

        // Init the photo to a black photo
        self.coverPhoto = UIImage()

        self.captureProject = Project(url: tempDir.appendingPathComponent(self.STRING_ID),
                captureStart: Date())
        
        // Set the photo project to tthe proper orientation
        switch orientation {
        case .portrait:
            self.orientation = .up
        case .portraitUpsideDown:
            self.orientation = .down
        case .landscapeLeft:
            self.orientation = .right
        case .landscapeRight:
            self.orientation = .left
        default:
            self.orientation = .up
        }

        self.captureProject.setOrientation(orientation: self.orientation)
        
    }

    init(project: Project) {
        self.captureProject = project

        self.maskEnabled = true
        self.alignEnabled = true
        self.enhanceEnabled = false

        self.coverPhoto = UIImage()

        self.STRING_ID = project.getUrl().lastPathComponent

        location = nil
    }

    deinit {
    }

    func suspendProcessing() {
        self.dispatch.cancelAllOperations()
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


    func add(captureObject: CaptureObject,
             statusUpdateCallback: ((PhotoStackingResult) -> ())?,
             previewImageCallback: ((UIImage) -> Void)?,
             addToProject: Bool = false) -> UIImage {
        self.dispatch.addOperation {

            let image = captureObject.toUIImage()
            autoreleasepool {
                if (addToProject) {
                    self.captureProject.addUnprocessedPhotoURL(url: captureObject.getURL())
                    self.captureProject.setMetadata(data: captureObject.metadata)
                    self.captureProject.save()
                }

            }

            /**
             Check if the stacker is called for the first time, if so, we need to init it.
             */
            if self.stacker == nil {
                self.coverPhoto = image

                if (addToProject) {
                    self.captureProject.setCoverPhoto(image: image)
                    self.captureProject.save()
                }

                /**
                 On first call, apply background//foreground segmentation.
                 Make sure the image is rotated upright
                 */
                
                //let rotatedImage = UIImage(cgImage: image.cgImage!, scale: 1.0, orientation: self.orientation)
                let maskImage = ImageSegementation.segementImage(image: image)

                autoreleasepool {
                    if self.maskEnabled {
                        self.stacker = OpenCVStacker.init(image: image, withMask: maskImage, visaliseTrackingPoints: true)
                    } else {
                        self.stacker = OpenCVStacker.init(image: image, withMask: nil, visaliseTrackingPoints: true)
                    }

                    self.numImages += 1
                    if (self.stacker == nil) {
                        print("Failed to init OpenCVStacker")
                        self.initAttempts += 1
                        self.numImages += 1
                        if (self.initAttempts > self.MAX_INIT_ATTEMPTS) {
                            print("Failed to init OpenCVStacker after \(self.MAX_INIT_ATTEMPTS) attempts")
                            statusUpdateCallback?(PhotoStackingResult.INIT_FAILED)
                            self.dispatch.cancelAllOperations()
                            return
                        }
                        statusUpdateCallback?(PhotoStackingResult.FAILED)
                    } else {
                        self.captureProject.setCoverPhoto(image: self.coverPhoto)
                        previewImageCallback?(self.coverPhoto)
                        statusUpdateCallback?(PhotoStackingResult.SUCCESS)
                    }
                }

            } else {
                /**
                 Otherwise, the photo can be merged
                 */
                autoreleasepool {
                    if let stackedImage = self.stacker!.addAndProcess(image) {
                        self.coverPhoto = stackedImage
                        self.numImages += 1
                        statusUpdateCallback?(.SUCCESS)
                    } else {
                        statusUpdateCallback?(.FAILED)
                    }
                }

                var previewImage = UIImage()
                autoreleasepool {
                    let image = self.stacker!.getPreviewImage()
                    if image != nil {
                        previewImage = image!
                    }
                }
                previewImageCallback?(previewImage)
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

    func saveStack(finished: Bool, statusUpdateCallback: ((PhotoStackingResult) -> ())?) {
        self.dispatch.addOperation {
            print("Attempting to save stack")
            if (self.stacker == nil) {
                statusUpdateCallback?(PhotoStackingResult.INIT_FAILED)
                return
            }

            var previewPhoto = UIImage()
            autoreleasepool {
                let image = self.stacker!.getPreviewImage()
                if image != nil {
                    previewPhoto = image!
                }
            }

            if finished {
                self.captureProject.setNumImages(self.numImages)
                self.captureProject.doneProcessing()
            }

            let processedImage = self.stacker!.getProcessedImage()
            if processedImage != nil {
                self.captureProject.setCoverPhoto(image: processedImage!)
            } else {
                self.captureProject.setCoverPhoto(image: previewPhoto)
            }
            autoreleasepool {
                self.stacker!.saveFiles(self.captureProject.getUrl().path)
            }

            self.captureProject.save()


            processedImage?.saveToGallery(metadata: self.captureProject.getMetadata(), orientation: self.captureProject.getOrientation())

            /*
            let imageStacked = self.stacker!.getProcessedImage()
            let imageMaxed = self.stacker!.getPreviewImage()
            */

            statusUpdateCallback?(PhotoStackingResult.SUCCESS)


            // Update preview image in camera view
            let resized = ImageResizer.resize(image: previewPhoto, targetWidth: 100.0)
            ProjectController.storePreviewImage(image: resized)

            self.stacker?.deallocMerger()
        }
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
