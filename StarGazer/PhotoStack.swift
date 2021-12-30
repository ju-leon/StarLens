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
    let EARTH_TIME_PER_ROTATION = 86164
    public let STRING_ID : String
    
    let ciFilter = OpticalFlowVisualizerFilter()
    var requestHandler = VNSequenceRequestHandler()
    
    private var coverPhoto : UIImage
    
    private var stacked : CGImage?
    private var trailing : CGImage?
    
    private var captureObjects: [CaptureObject] = []
    private var calibrationMatrix : [Double]? = [3020.6292, 0, 2009, 0, 3020.6292, 1528, 0,0,1]
    private var calibrationMatrixInverse : [Double]?
    
    let startTime : Date?
    
    var location: CLLocationCoordinate2D
    let heading: Double
    let gyro: [Double]
    
    let device_alpha: Double
    let device_beta : Double
    let device_gamma: Double
    
    
    private static func degToRad(_ deg: Double) -> Double{
        return (deg * Double.pi) / 180
    }
    
    private static func invert(_ matrix : [Double]) -> [Double] {
        var inMatrix = matrix
        var N = __CLPK_integer(sqrt(Double(matrix.count)))
        var pivots = [__CLPK_integer](repeating: 0, count: Int(N))
        var workspace = [Double](repeating: 0.0, count: Int(N))
        var error : __CLPK_integer = 0

        withUnsafeMutablePointer(to: &N) {
            dgetrf_($0, $0, &inMatrix, $0, &pivots, &error)
            dgetri_($0, &inMatrix, $0, &pivots, &workspace, $0, &error)
        }
        return inMatrix
    }
    
    private static func matMul(_ matrix1: [Double], _ matrix2: [Double]) -> [Double] {
        var rotation = [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
        vDSP_mmulD(matrix1, 1, matrix2, 1, &rotation, 1, 3, 3, 3)
        
        return rotation
    }
    
    private static func simdToDouble(_ matrix: simd_float3x3) -> [Double] {
        return (0..<3).flatMap { x in (0..<3).map { y in Double(matrix[x][y]) } }
    }
    
    private static func getRotation(alpha: Float64, beta: Float64, gamma: Float64) -> [Double] {
        let R_x = [1.0, 0.0, 0.0, 0.0, cos(alpha), -sin(alpha), 0.0, sin(alpha), cos(alpha)]
        let R_y = [cos(beta), 0.0, sin(beta), 0.0, 1.0, 0.0, -sin(beta), 0.0, cos(beta)]
        let R_z = [cos(gamma), -sin(gamma), 0.0, sin(gamma), cos(gamma), 0.0, 0.0,0.0,1.0]
        
        var rotation = matMul(R_x, R_z)
        rotation = matMul(R_y, rotation)
        
        return rotation
    }
    
    private static func matrixToRotation(rotationMatrix: [Double]) -> [Double]{
        
        let alpha = atan2(rotationMatrix[7], rotationMatrix[8])
        
        let beta = atan2(-rotationMatrix[6], sqrt(pow(rotationMatrix[7], 2) + pow(rotationMatrix[8], 2)))
        
        let gamma = atan2(rotationMatrix[3], rotationMatrix[0])
        
        return [alpha, beta, gamma]
    }
    
    
    private func getEarthRotationAngle(start: Date, end: Date) -> Double {
        let differenceInSeconds = end.timeIntervalSince(start)
        
        let angle = (-2 * Double.pi * differenceInSeconds) / Double(EARTH_TIME_PER_ROTATION)
        
        return angle
    }
    
    
    
    private func getTranslation(captureTime: Date) -> CGAffineTransform {
        let angle = getEarthRotationAngle(start: startTime!, end: captureTime)
        
        let rotationBefore = PhotoStack.getRotation(alpha: self.device_alpha, beta: 0, gamma: self.device_gamma)
        let rotationAfter = PhotoStack.getRotation(alpha: self.device_alpha, beta: angle, gamma: self.device_gamma)
        
        var fullRotation = PhotoStack.matMul(self.calibrationMatrix!,
                                             PhotoStack.matMul(
                                                PhotoStack.invert(rotationAfter),
                                                PhotoStack.matMul(
                                                    rotationBefore,
                                                    self.calibrationMatrixInverse!
                                                )
                                             ))
        
        
        fullRotation = PhotoStack.invert(fullRotation)
        
        print("Alpha: \(self.device_alpha), Beta: \(angle), Gamma: \(self.device_gamma)")
        print(fullRotation)
        
        return CGAffineTransform(a: fullRotation[0],
                                 b: fullRotation[3],
                                 c: fullRotation[1],
                                 d: fullRotation[4],
                                 tx: fullRotation[2],
                                 ty: fullRotation[5])
        
    }
    
    //TODO: Init with actual size
    init(location: CLLocationCoordinate2D, heading: Double, gyro: [Double]) {
        self.STRING_ID = ProcessInfo.processInfo.globallyUniqueString
        
        let tempDir = FileManager.default.temporaryDirectory
        do {
            try FileManager.default.createDirectory(atPath: tempDir.appendingPathComponent(self.STRING_ID, isDirectory: true).path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error.localizedDescription)
        }
        
        // Init device heading
        self.location = location
        self.heading = heading
        self.gyro = gyro
        
        var rotation: [Double] = [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
        vDSP_mmulD(PhotoStack.getRotation(alpha: PhotoStack.degToRad(location.latitude), beta: PhotoStack.degToRad(location.longitude), gamma: PhotoStack.degToRad(heading)), 1,
                   PhotoStack.getRotation(alpha: PhotoStack.degToRad(gyro[0]), beta: PhotoStack.degToRad(gyro[1]), gamma: PhotoStack.degToRad(gyro[2])), 1,
                   &rotation, 1, 3, 3, 3)
        
        let angles = PhotoStack.matrixToRotation(rotationMatrix: rotation)
        
        self.calibrationMatrixInverse = PhotoStack.invert(self.calibrationMatrix!)
        print("Angles: ")
        print(angles)
        
        self.device_alpha = angles[0]
        self.device_beta = angles[1]
        self.device_gamma = angles[2]
        
        startTime = Date()
        
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
    
    func addIntrinsicMatrix(matrix: simd_float3x3) {
        // Init calibaration matrix
        //self.calibrationMatrix = PhotoStack.simdToDouble(matrix.transpose)
        //self.calibrationMatrixInverse = PhotoStack.simdToDouble(matrix.transpose.inverse)
        self.calibrationMatrixInverse = PhotoStack.invert(self.calibrationMatrix!)
    }

    func add(url: URL, preview: Data, time: Date) -> UIImage {
        self.captureObjects.append(CaptureObject(url: url, time: time))
        
        let image = UIImage(data: preview)!
        coverPhoto = blendPreview(image1: coverPhoto, image2: image)
        
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
    
    func alignImage(request: VNRequest, frame: CIImage) -> CIImage {
        
        
        do {
            let sequenceHandler = VNSequenceRequestHandler()
            try sequenceHandler.perform([request], on: frame)
        } catch {
            print(error.localizedDescription)
        }
        
        guard
            let results = request.results as? [VNImageHomographicAlignmentObservation],
            let result = results.first
        else {
            print("Falied")
            return frame
        }
        

        
        let mat = PhotoStack.simdToDouble(result.warpTransform)
        print(mat)
        //print(result.p)
        // 2
        
        let alignedFrame = frame.transformed(by: CGAffineTransform(
            a: 1,//mat[0],
            b: 0,//mat[3],
            c: 0,//mat[1],
            d: 1,//mat[4],
            tx: mat[6],
            ty: mat[7])
        )
        // 3
         
        return alignedFrame//CIImage(cvPixelBuffer: alignedFrame.pixelBuffer!)
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
    
    func makeOpticalFlowImage(baseImage: CIImage, newImage: CGImage) -> CIImage? {
        var opticalFlow: CIImage?
        do {
            let request = VNGenerateOpticalFlowRequest(targetedCGImage: newImage, options: [:])
            try self.requestHandler.perform([request], on: baseImage)
            
            guard let pixelBufferObservation = request.results?.first as? VNPixelBufferObservation else { return nil }
            opticalFlow = CIImage(cvImageBuffer: pixelBufferObservation.pixelBuffer)
        } catch {
            print("Flow request failed")
            return nil
        }
        
        ciFilter.inputImage = opticalFlow
        return ciFilter.outputImage
    }
    
    func stackPhotos(_ statusUpdateCallback: ((Double)->())?) {
        let firstImage = CIImage(contentsOf: captureObjects[0].getURL())!
        let scaled = scale(image: firstImage, factor: 0.5)
        let firstImageLow = CIImage(cgImage: CIContext().createCGImage(scaled, from: scaled.extent)!)
        
        
        var finalImage = CIImage(cgImage: CIContext().createCGImage(firstImage, from: firstImage.extent)!)
        let filter = AverageStackingFilter()
        
        var image = UIImage(cgImage: CIContext().createCGImage(firstImage, from: firstImage.extent)!)
        
        var images: [UIImage] = []
        for (i, captureObject) in self.captureObjects.dropFirst(1).enumerated(){
            let newImage = CIImage(contentsOf: captureObject.getURL())!
            let uiImage = UIImage(cgImage: CIContext().createCGImage(newImage, from: newImage.extent)!)
            images.append(uiImage)
            
            let progress = Double(i + 1) / Double(captureObjects.count - 1)
            statusUpdateCallback?(progress)
            
        }
        
        image = OpenCVWrapper.stackImages(images, on: image)
        savePhoto(image: image)
        
        
        
        
        self.coverPhoto = image
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
