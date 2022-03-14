//
// Created by Leon Jungemeyer on 13.03.22.
//

import Foundation

import Foundation
import CoreMotion
import AVFoundation

/**
 Utility class for device orientation.
 */
class DeviceOrientationManager {
    private let queue: OperationQueue
    let motionManager: CMMotionManager
    let onOrientationUpdate: (AVCaptureVideoOrientation) -> Void
    var orientation: AVCaptureVideoOrientation
    
    init(onOrientationUpdate:  @escaping (AVCaptureVideoOrientation) -> Void) {
        queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        motionManager = CMMotionManager()
        motionManager.accelerometerUpdateInterval = 0.5
        motionManager.gyroUpdateInterval = 0.5
        
        self.onOrientationUpdate = onOrientationUpdate
        self.orientation = .portrait
    }

    private func outputAccelertionData(_ acceleration: CMAcceleration) {
        var newOrientation = AVCaptureVideoOrientation.portrait

        if acceleration.x >= 0.75 {
            newOrientation = .landscapeLeft
        } else if acceleration.x <= -0.75 {
            newOrientation = .landscapeRight
        } else if acceleration.y <= -0.75 {
            newOrientation = .portrait
        } else if acceleration.y >= 0.75 {
            newOrientation = .portraitUpsideDown
        }
        
        if newOrientation != self.orientation {
            print("Changed orientation to \(newOrientation.rawValue)")
            self.orientation = newOrientation
            self.onOrientationUpdate(orientation)
        }
    }

    func startUpdatingOrientation() {
        self.motionManager.startAccelerometerUpdates(to: self.queue, withHandler: {
            (accelerometerData, error) -> Void in
            if error == nil {
                self.outputAccelertionData((accelerometerData?.acceleration)!)
            }
        })
    }
    
    func stopUpdateingOrientation() {
        self.motionManager.stopAccelerometerUpdates()
    }

}
