//
//  TimeLapseBuilder.swift
//
//  Created by Leon Jungemeyer on 11.04.2022.
import AVFoundation

import UIKit
import Photos


let kErrorDomain = "TimeLapseBuilder"
let kFailedToStartAssetWriterError = 0
let kFailedToAppendPixelBufferError = 1
let kFailedToDetermineAssetDimensions = 2
let kFailedToProcessAssetPath = 3

public protocol TimelapseBuilderDelegate: AnyObject {
    func timeLapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didMakeProgress progress: Progress)
    func timeLapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didFinishWithURL url: URL)
    func timeLapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didFailWithError error: Error)
}

public class TimeLapseBuilder {
    //private var delegate: TimelapseBuilderDelegate
    public let canvasSize: CGSize
    public let frameRate: Int32
    public let outputPath: String
    
       
    private var videoWriter: AVAssetWriter
    private let videoSettings: [String: AnyObject]
    private let videoWriterInput: AVAssetWriterInput
    private let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    private var frameCount: Int64 = 0
    
    let timelapseQueue = DispatchQueue(label: "timelapseQueue")
    
    /**
     Creates a new time lapse genertor that can iteratively add new frames.
     Throws if an error in creating an asset writer occurs.
     */
    public init(videoResolution: CGSize,
                frameRate: Int32,
                type: AVFileType,
                outputPath: String
    ) throws {
        self.canvasSize = videoResolution
        self.frameRate = frameRate
        self.outputPath = outputPath
        
        /*
         Make sure the provided filepath is valid.
         Delete the video at this spot if necessary
         */
        var error: NSError?
        let videoOutputURL = URL(fileURLWithPath: outputPath)
        
        do {
            try FileManager.default.removeItem(at: videoOutputURL)
        } catch {}
        
        do {
            try videoWriter = AVAssetWriter(outputURL: videoOutputURL, fileType: type)
        } catch let writerError as NSError {
            error = writerError
            throw error!
        }
        
        print(videoWriter.outputURL)
        
        /*
         Configure the video writer
         */
        videoSettings = [
            AVVideoCodecKey  : AVVideoCodecType.hevc as AnyObject,
            AVVideoWidthKey  : canvasSize.width as AnyObject,
            AVVideoHeightKey : canvasSize.height as AnyObject
            //        AVVideoCompressionPropertiesKey : [
            //          AVVideoAverageBitRateKey : NSInteger(1000000),
            //          AVVideoMaxKeyFrameIntervalKey : NSInteger(16),
            //          AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel
            //        ]
        ]
        
        videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        
        let sourceBufferAttributes = [
            (kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32ARGB),
            (kCVPixelBufferWidthKey as String): Float(canvasSize.width),
            (kCVPixelBufferHeightKey as String): Float(canvasSize.height)] as [String : Any]
        
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput,
            sourcePixelBufferAttributes: sourceBufferAttributes
        )
        
        videoWriter.add(videoWriterInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: CMTime.zero)
        
    }
    
    func addImage(image: UIImage,
                  onSucess: (() -> ())?,
                  onError: ((Error) -> ())?) {
        //videoWriterInput.requestMediaDataWhenReady(on: timelapseQueue) {
            while !self.videoWriterInput.isReadyForMoreMediaData {
                print("Not ready, spinning...")
                usleep(100)
            }
            
            let presentationTime = CMTimeMake(value: self.frameCount, timescale: self.frameRate)
            
            if self.appendPixelBufferForImageAtURL(image, pixelBufferAdaptor: self.pixelBufferAdaptor, presentationTime: presentationTime) {
                self.frameCount += 1
                onSucess?()
            } else {
                let error = NSError(
                    domain: kErrorDomain,
                    code: kFailedToAppendPixelBufferError,
                    userInfo: ["description": "AVAssetWriterInputPixelBufferAdapter failed to append pixel buffer"]
                )
                print("ERROR CREATING TIMELAPSE: \(error)")
                onError?(error)
            }
        //}
    }
    
    func completeStack(onSucess: (() -> ())?) {
        videoWriterInput.markAsFinished()
        
        videoWriter.finishWriting {
            print("Sucessfully finished")
            onSucess?()
        }
        
    }
    
    func dimensionsOfImage(url: URL) -> CGSize? {
        guard let imageData = try? Data(contentsOf: url),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        return image.size
    }
    
    func appendPixelBufferForImageAtURL(_ image: UIImage, pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor, presentationTime: CMTime) -> Bool {
        var appendSucceeded = false
        
        autoreleasepool {
            if let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool {
                let pixelBufferPointer = UnsafeMutablePointer<CVPixelBuffer?>.allocate(capacity: 1)
                let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(
                    kCFAllocatorDefault,
                    pixelBufferPool,
                    pixelBufferPointer
                )

                if let pixelBuffer = pixelBufferPointer.pointee, status == 0 {
                    fillPixelBufferFromImage(image, pixelBuffer: pixelBuffer)
                    appendSucceeded = pixelBufferAdaptor.append(
                        pixelBuffer,
                        withPresentationTime: presentationTime
                    )
                    
                    pixelBufferPointer.deinitialize(count: 1)
                } else {
                    NSLog("error: Failed to allocate pixel buffer from pool")
                }
                
                pixelBufferPointer.deallocate()
            }
        }
        
        return appendSucceeded
    }
    
    func fillPixelBufferFromImage(_ image: UIImage, pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: pixelData,
            width: Int(image.size.width),
            height: Int(image.size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        
        context?.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    }
}
