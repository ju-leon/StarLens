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

class PhotoStack {
    private var coverPhoto : UIImage
    
    private var photos : [UIImage] = []
    private var matricies : [double3x3] = []
    
    let location: CLLocationCoordinate2D
    let heading: Double
    let gyro: [Double]
    
    private func degToRad(deg: Double) -> Double{
        return (deg * Double.pi) / 180
    }
    
    private func getRotation(alpha: Float64, beta: Float64, gamma: Float64) -> [Double] {
        let R_x = [1.0, 0.0, 0.0, 0.0, cos(alpha), -sin(alpha), 0.0, sin(alpha), cos(alpha)]
        let R_y = [cos(beta), 0.0, sin(beta), 0.0, 1.0, 0.0, -sin(beta), 0.0, cos(beta)]
        let R_z = [cos(gamma), -sin(gamma), 0.0, sin(gamma), cos(gamma), 0.0, 0.0,0.0,1.0]
        
        var rotation = [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
        
        vDSP_mmulD(R_x, 1, R_z, 1, &rotation, 1, 3, 3, 3)
        var rotation2 = [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
        vDSP_mmulD(R_y, 1, rotation, 1, &rotation2, 1, 3, 3, 3)
        
        return rotation2
    }
    
    
    //TODO: Init with actual size
    init(location: CLLocationCoordinate2D, heading: Double, gyro: [Double]) {
        
        self.location = location
        self.heading = heading
        self.gyro = gyro
        
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
    

    func add(photo: Data, matrix: double3x3) -> UIImage {
        let image = UIImage(data: photo)!
        self.photos.append(image)
        self.matricies.append(matrix)
        
        coverPhoto = blend(image1: coverPhoto, image2: image, cameraMatrix: matrix, orientation: [0.0, 0.0, 0.0])
        
        return coverPhoto
    }
    
    func getCoverPhoto() -> UIImage {
        return coverPhoto
    }
    
    func stackPhotos() {
        
    }
    
    func saveStack() {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                UIImageWriteToSavedPhotosAlbum(self.coverPhoto, self, nil, nil)
            } else {
                
                print("Cannot access photo libary")
            }
        }
    }
    
    private func blend(image1 : UIImage, image2: UIImage, cameraMatrix: double3x3, orientation: [Double]) -> UIImage {
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
