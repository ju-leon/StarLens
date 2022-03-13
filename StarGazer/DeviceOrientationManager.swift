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

    init() {
        queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        motionManager = CMMotionManager()
        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.gyroUpdateInterval = 0.2
    }

    private func outputAccelertionData(_ acceleration: CMAcceleration, onDone: @escaping (AVCaptureVideoOrientation) -> Void) {
        var orientation = AVCaptureVideoOrientation.portrait

        if acceleration.x >= 0.75 {
            orientation = .landscapeLeft
            print("landscapeLeft")
        } else if acceleration.x <= -0.75 {
            orientation = .landscapeRight
            print("landscapeRight")
        } else if acceleration.y <= -0.75 {
            orientation = .portrait
            print("portrait")

        } else if acceleration.y >= 0.75 {
            orientation = .portraitUpsideDown
            print("portraitUpsideDown")
        }

        self.motionManager.stopAccelerometerUpdates()
        onDone(orientation)
    }

    func getDeviceOrientation(resultCallback:  @escaping (AVCaptureVideoOrientation) -> Void) {
        self.motionManager.startAccelerometerUpdates(to: self.queue, withHandler: {
            (accelerometerData, error) -> Void in
            if error == nil {
                self.outputAccelertionData((accelerometerData?.acceleration)! , onDone: resultCallback)
            } else {
                resultCallback(AVCaptureVideoOrientation.portrait)
            }
        })
    }

}