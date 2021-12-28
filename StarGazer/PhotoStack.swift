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

class PhotoStack {
    // TIME FOR ONE REVOLUTION OF THE EARTH IN SECONDS
    let EARTH_TIME_PER_ROTATION = 86164
    
    private var coverPhoto : UIImage
    
    private var captureObjects: [CaptureObject] = []
    private var calibrationMatrix : [Double]? = [3020.6292, 0, 2009, 0, 3020.6292, 1528, 0,0,1]
    private var calibrationMatrixInverse : [Double]?
    
    let startTime : Date?
    
    let location: CLLocationCoordinate2D
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
    
    func stackPhotos(_ statusUpdateCallback: ((Double)->())?) {
        var finalImage = CIImage(contentsOf: captureObjects[0].getURL())
        let filter = AverageStackingFilter()
        
        for (i, captureObject) in self.captureObjects.dropFirst(1).enumerated(){
            print("Stacking \(captureObject.getURL())")
            
            autoreleasepool {
                filter.inputCurrentStack = finalImage

                let newImage = CIImage(contentsOf: captureObject.getURL())!.transformed(by: getTranslation(captureTime: captureObject.captureTime))
                
                filter.inputNewImage = newImage
                filter.inputStackCount = Double(i)
            
                let context = CIContext() // Prepare for create CGImage
                let cgimg = context.createCGImage(filter.outputImage()!, from: finalImage!.extent)!
                context.clearCaches()
                
                finalImage = CIImage(cgImage: cgimg)
            }
            
            let progress = Double(i + 1) / Double(captureObjects.count - 1)
            statusUpdateCallback?(progress)
        }
        
        captureObjects = []
  
        let context = CIContext() // Prepare for create CGImage
        let cgimg = context.createCGImage(finalImage!, from: finalImage!.extent)
        let output = UIImage(cgImage: cgimg!)
        
        self.coverPhoto = output
    }
    
    func saveStack() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                
                // Don't continue if not authorized.
                guard status == .authorized else { return }
                
                PHPhotoLibrary.shared().performChanges {
             
                    // Save the RAW (DNG) file as the main resource for the Photos asset.
                    let options = PHAssetResourceCreationOptions()
                    options.shouldMoveFile = true
                    /*
                    creationRequest.addResource(with: .photo,
                                                fileURL: rawFileURL,
                                                options: options)
                    */
                    // Add the compressed (HEIF) data as an alternative resource.
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo,
                                                data: self.coverPhoto.pngData()!,
                                                options: nil)
                    
                    
                } completionHandler: { success, error in
                    //print("error: \(error!)")
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
