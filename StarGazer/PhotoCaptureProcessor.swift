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

    private(set) var requestedPhotoSettings: AVCapturePhotoSettings
    
    private let willCapturePhotoAnimation: () -> Void
    
    private let completionHandler: (PhotoCaptureProcessor) -> Void
    
    private let photoProcessingHandler: (Bool) -> Void
    
    private let service : CameraService
    
    private var photoStack : PhotoStack
    
    private var intrinsicMatrix = simd_float3x3(0)
    
    private let queue = DispatchQueue(label: "com.jungemeyer.preview-merge-queue")
//    The actual captured photo's data
    var previewPhoto: UIImage?
    
    private var rawFileURL: URL?
    private var compressedData: Data?
    private var captureTime: Date?
    private var metadata: [String : Any]?
//    The maximum time lapse before telling UI to show a spinner
    private var maxPhotoProcessingTime: CMTime?
        
//    Init takes multiple closures to be called in each step of the photco capture process
    init(with requestedPhotoSettings: AVCapturePhotoSettings, willCapturePhotoAnimation: @escaping () -> Void, completionHandler: @escaping (PhotoCaptureProcessor) -> Void, photoProcessingHandler: @escaping (Bool) -> Void,
         service: CameraService,
         photoStack : PhotoStack) {
        
        self.requestedPhotoSettings = requestedPhotoSettings
        self.willCapturePhotoAnimation = willCapturePhotoAnimation
        self.completionHandler = completionHandler
        self.photoProcessingHandler = photoProcessingHandler
        
        self.service = service
        self.photoStack = photoStack
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
        // Take a new photo as soon as the old photo is processed
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
            rawFileURL = makeUniqueDNGFileURL()
            do {
                // Write the RAW (DNG) file data to a URL.
                try photoData.write(to: rawFileURL!)
            } catch {
                fatalError("Couldn't write DNG file to the URL.")
            }
        } else {
            // Store compressed bitmap data.
            compressedData = photoData
        }
        
    }
    
    private func makeUniqueDNGFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = ProcessInfo.processInfo.globallyUniqueString
        return tempDir.appendingPathComponent(self.photoStack.STRING_ID, isDirectory: true)
            .appendingPathComponent(fileName)
            .appendingPathExtension("dng")
    }
    
    
    /// - Tag: DidFinishCapture
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        // Capture next photo
        self.service.setupCameraProperties()
        
        
        if let error = error {
            print("Error capturing photo: \(error)")
            DispatchQueue.main.async {
                self.completionHandler(self)
            }
            return
        } else {
            guard let data  = compressedData else {
                DispatchQueue.main.async {
                    self.completionHandler(self)
                }
                return
            }
            
            
            guard let rawURL = rawFileURL else {
                DispatchQueue.main.async {
                    self.completionHandler(self)
                }
                return
            }
            
            print(data)
            
            //self.saveToPhotoLibrary(data)
            let captureObject = CaptureObject(url: rawURL, time: self.captureTime!, metadata: self.metadata!)
            
            self.previewPhoto = self.photoStack.add(captureObject: captureObject, preview: data)
            
            DispatchQueue.main.async {
                self.completionHandler(self)
            }
        }
        

        
    }
}
