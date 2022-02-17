//
//  PhotoCaptureProcessor.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 19.12.21.
//

import Foundation
import Photos
import UIKit

public enum PhotoCaptureStatus : Int {
    /**
     Capture suceeded, next capture can be sceduled.
     */
    case success = 0
    
    /**
     Capture failed to a recoverable state, next capture can be sceduled.
     */
    case failed = 1
    
    /**
     Caputure failed to an inrecoverable state. Abort capture.
     */
    case fatal_error = 2
}

class PhotoCaptureProcessor: NSObject {

    lazy var context = CIContext()

    private(set) var requestedPhotoSettings: AVCapturePhotoBracketSettings

    private let willCapturePhotoAnimation: () -> Void

    private let completionHandler: (PhotoCaptureStatus, PhotoCaptureProcessor) -> Void

    private let photoProcessingHandler: (Bool) -> Void

    private var photoStack: PhotoStack

    private var intrinsicMatrix = simd_float3x3(0)

    private var previewImageCallback: (UIImage) -> Void

    private let queue = DispatchQueue(label: "com.jungemeyer.preview-merge-queue")
//    The actual captured photo's data

    private var rawFileURLs: [URL] = []
    private var captureTime: Date?
    private var metadata: [String: Any]?
//    The maximum time lapse before telling UI to show a spinner
    private var maxPhotoProcessingTime: CMTime?

    public var previewPhoto: UIImage?

    private let stackingResultsCallback: (PhotoStackingResult) -> Void
    
    /**
     Defaults to sucess, unless any process fails
     */
    private var captureStatus: PhotoCaptureStatus = .success

//    Init takes multiple closures to be called in each step of the photco capture process
    init(with requestedPhotoSettings: AVCapturePhotoBracketSettings,
         willCapturePhotoAnimation: @escaping () -> Void,
         completionHandler: @escaping (PhotoCaptureStatus ,PhotoCaptureProcessor) -> Void,
         photoProcessingHandler: @escaping (Bool) -> Void,
         photoStack: PhotoStack,
         stackingResultsCallback: @escaping (PhotoStackingResult) -> Void,
         previewImageCallback: @escaping (UIImage?) -> Void) {

        self.requestedPhotoSettings = requestedPhotoSettings
        self.willCapturePhotoAnimation = willCapturePhotoAnimation
        self.completionHandler = completionHandler
        self.photoProcessingHandler = photoProcessingHandler

        self.photoStack = photoStack
        self.stackingResultsCallback = stackingResultsCallback
        self.previewImageCallback = previewImageCallback
    }
}

extension PhotoCaptureProcessor: AVCapturePhotoCaptureDelegate {

    // This extension adopts AVCapturePhotoCaptureDelegate protocol methods.

    /// - Tag: WillBeginCapture
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        maxPhotoProcessingTime = resolvedSettings.photoProcessingTimeRange.start + resolvedSettings.photoProcessingTimeRange.duration
    }

    /// - Tag: WillCapturePhoto
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        self.captureTime = Date()

        DispatchQueue.main.async {
            self.willCapturePhotoAnimation()
        }

        guard let maxPhotoProcessingTime = maxPhotoProcessingTime else {
            return
        }

        // Show a spinner if processing time exceeds one second.
        let oneSecond = CMTime(seconds: 2, preferredTimescale: 1)
        if maxPhotoProcessingTime > oneSecond {
            DispatchQueue.main.async {
                self.photoProcessingHandler(true)
            }
        }
    }

    /// - Tag: DidFinishProcessingPhoto
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.main.async {
            self.photoProcessingHandler(false)
        }

        self.metadata = photo.metadata

        guard let photoData = photo.fileDataRepresentation() else {
            print("No photo data to write.")
            return
        }

        if photo.isRawPhoto {
            // Generate a unique URL to write the RAW file.
            let rawFileURL = makeUniqueDNGFileURL()
            do {
                // Write the RAW (DNG) file data to a URL.
                try photoData.write(to: rawFileURL)
                self.rawFileURLs.append(rawFileURL)
                
                let captureObject = CaptureObject(url: rawFileURL, time: self.captureTime!, metadata: self.metadata!)
                self.previewPhoto = self.photoStack.add(
                        captureObject: captureObject,
                        statusUpdateCallback: self.stackingResultsCallback,
                        previewImageCallback: self.previewImageCallback)
                
                
            } catch {
                print("Storage full! Capture needs to be aborted!")
                self.captureStatus = .fatal_error
            }
        } else {
            // Store compressed bitmap data.
            print("Couldn't capture raw photo")
            self.captureStatus = .fatal_error
        }

    }

    private func makeUniqueDNGFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = ProcessInfo.processInfo.globallyUniqueString
        let dir = tempDir.appendingPathComponent(self.photoStack.STRING_ID, isDirectory: true)
                .appendingPathComponent(fileName)
                .appendingPathExtension("dng")
        return dir
    }


    /// - Tag: DidFinishCapture
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        print("Finished processing photo")

        if let error = error {
            print("Error capturing photo: \(error)")
            DispatchQueue.main.async {
                self.completionHandler(.fatal_error, self)
            }
            return
        } else {
            /*
             //Compressed data can be ignored
            guard let data = compressedData else {
                DispatchQueue.main.async {
                    self.completionHandler(self)
                }
                return
            }
            */

            DispatchQueue.main.async {
                self.completionHandler(self.captureStatus, self)
            }
        }

    }
}
