//
//  PhotoCaptureProcessor.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 19.12.21.
//

import Foundation
import Photos
import UIKit

class PhotoCaptureProcessor: NSObject {

    lazy var context = CIContext()

    private(set) var requestedPhotoSettings: AVCapturePhotoBracketSettings

    private let willCapturePhotoAnimation: () -> Void

    private let completionHandler: (PhotoCaptureProcessor) -> Void

    private let photoProcessingHandler: (Bool) -> Void

    private var photoStack: PhotoStack

    private var intrinsicMatrix = simd_float3x3(0)

    private let queue = DispatchQueue(label: "com.jungemeyer.preview-merge-queue")
//    The actual captured photo's data

    private var rawFileURLs: [URL] = []
    private var captureTime: Date?
    private var metadata: [String: Any]?
//    The maximum time lapse before telling UI to show a spinner
    private var maxPhotoProcessingTime: CMTime?

    public var previewPhoto : UIImage?
    
    private let stackingResultsCallback : (PhotoStackingResult) -> Void

//    Init takes multiple closures to be called in each step of the photco capture process
    init(with requestedPhotoSettings: AVCapturePhotoBracketSettings,
         willCapturePhotoAnimation: @escaping () -> Void,
         completionHandler: @escaping (PhotoCaptureProcessor) -> Void,
         photoProcessingHandler: @escaping (Bool) -> Void,
         photoStack: PhotoStack,
         stackingResultsCallback: @escaping (PhotoStackingResult) -> Void) {

        self.requestedPhotoSettings = requestedPhotoSettings
        self.willCapturePhotoAnimation = willCapturePhotoAnimation
        self.completionHandler = completionHandler
        self.photoProcessingHandler = photoProcessingHandler

        self.photoStack = photoStack
        self.stackingResultsCallback = stackingResultsCallback
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
        print("Finished processing photo \(photo.photoCount)")

        //TODO: WHY??
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
            } catch {
                fatalError("Couldn't write DNG file to the URL.")
            }
        } else {
            // Store compressed bitmap data.
            print("Something went wrong")
        }

    }

    private func makeUniqueDNGFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = ProcessInfo.processInfo.globallyUniqueString
        let dir = tempDir.appendingPathComponent(self.photoStack.STRING_ID, isDirectory: true)
                .appendingPathComponent(fileName)
                .appendingPathExtension("dng")
        print(dir)
        return dir
        
    }


    /// - Tag: DidFinishCapture
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        print("Finished processing photo")

        if let error = error {
            print("Error capturing photo: \(error)")
            DispatchQueue.main.async {
                self.completionHandler(self)
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


            //self.saveToPhotoLibrary(data)
            for rawURL in rawFileURLs {
                let captureObject = CaptureObject(url: rawURL, time: self.captureTime!, metadata: self.metadata!)
                self.previewPhoto = self.photoStack.add(captureObject: captureObject, statusUpdateCallback: self.stackingResultsCallback)
            }
            DispatchQueue.main.async {
                self.completionHandler(self)
            }
        }

    }
}
