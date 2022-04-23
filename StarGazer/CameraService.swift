//
//  CameraService.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 19.12.21.
//

import Foundation
import Combine
import AVFoundation
import Photos
import UIKit
import CoreLocation
import CoreMotion
import SwiftUI

public struct CameraZoomLevel: Identifiable {
    public var id = UUID()

    let zoomLevel: Float
    let device: AVCaptureDevice
}


public struct AlertError {
    public var title: String = ""
    public var message: String = ""
    public var primaryButtonTitle = "Accept"
    public var secondaryButtonTitle: String?
    public var primaryAction: (() -> ())?
    public var secondaryAction: (() -> ())?

    public init(title: String = "", message: String = "", primaryButtonTitle: String = "Accept", secondaryButtonTitle: String? = nil, primaryAction: (() -> ())? = nil, secondaryAction: (() -> ())? = nil) {
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryAction = secondaryAction
    }
}

public class CameraService: NSObject {
    typealias PhotoCaptureSessionID = String

    @Published public var shouldShowAlertView = false
    @Published public var shouldShowSpinner = false
    @Published public var blackOutCamera = false
    @Published public var isCameraButtonDisabled = true
    @Published public var isCameraUnavailable = true

    @Published public var captureStatus: CaptureStatus = .preparing

    @Published public var previewPhoto: UIImage?

    @Published public var numPicures = 0
    @Published public var numProcessed = 0
    @Published public var numFailed = 0

    @Published public var processingProgress = 0

    @Published public var focusDistance: Double = 0.5

    @Published public var galleryPreviewImage: UIImage = UIImage()

    @Published public var minIso: Float = 0
    @Published public var maxIso: Float = 0
    @Published public var activeIso: Float = 400.0
    
    @Published var flashEnabled: Bool = false
    @Published var maskEnabled: Bool = true
    @Published var timerEnabled: Bool = false
    
    /**
        Values do not need to be published since they will never change during execution.
     */
    public var availableZoomLevels: [CameraZoomLevel] = []
    public var activeZoomLevel: CameraZoomLevel

    private var debugEnabled = false

    private var alignEnabled = false
    private var enhanceEnabled = false

// MARK: Alert properties
    public var alertError: AlertError = AlertError()

// MARK: Session Management Properties

    public let session = AVCaptureSession()
    public let locationManager = CLLocationManager()

    var deviceOrientation: AVCaptureVideoOrientation = .portrait

    var isSessionRunning = false
    var isConfigured = false
    var setupResult: SessionSetupResult = .success

    let defaults = UserDefaults.standard

    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue")

    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!

    // MARK: Device Configuration Properties
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera], mediaType: .video, position: .unspecified)

    // MARK: Capturing Photos

    private let photoOutput = AVCapturePhotoOutput()
    private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
    private var captureQueue: DispatchQueue = DispatchQueue(label: "StarStacker.captureQueue")

    // MARK: KVO and Notifications Properties

    private var keyValueObservations = [NSKeyValueObservation]()

    private var photoStack: PhotoStack?
    private var location: CLLocationCoordinate2D?

    private var isoRotation: [Float] = [400, 400, 400, 400] //[800, 800, 800, 800]
    private var isoRotationIndex = 0

    public static let biasRotation: [Float] = [-1, -0.5, 0, 0.5]
    private var biasRotationIndex = 0

    private var focusUpdate = false
    
    private var orientation = AVCaptureVideoOrientation.portrait
    private var orientationManager = DeviceOrientationManager(onOrientationUpdate: {_ in})


    public override init() {
        let availableCameras = videoDeviceDiscoverySession.devices
        
        // Init activeZoomLevelwith first available camer to silence warnings
        // Should always we overwritten inside the switch case, since all devices should have a wide angle camera
        self.activeZoomLevel = CameraZoomLevel(zoomLevel: -1, device: availableCameras[0])
        super.init()


        for camera in availableCameras {
            if camera.position == .back {
                switch camera.deviceType {
                case .builtInTelephotoCamera:
                    availableZoomLevels.append(CameraZoomLevel(zoomLevel: 3.0, device: camera))
                case .builtInUltraWideCamera:
                    availableZoomLevels.append(CameraZoomLevel(zoomLevel: 0.5, device: camera))
                case .builtInWideAngleCamera:
                    let zoomLevel = CameraZoomLevel(zoomLevel: 1.0, device: camera)
                    self.activeZoomLevel = zoomLevel
                    availableZoomLevels.append(zoomLevel)
                    
                    self.minIso = camera.activeFormat.minISO
                    self.maxIso = camera.activeFormat.maxISO
                default:
                    print("Unsupported camera")
                }
            }
            print(camera.activeFormat.videoFieldOfView)
        }

        availableZoomLevels = availableZoomLevels.sorted(by: { $0.zoomLevel < $1.zoomLevel })
        
        self.orientationManager = DeviceOrientationManager(onOrientationUpdate: { orientation in
            self.orientation = orientation
        })

    }

    deinit {
    }
    
    public func configure() {
        let imageSize = CGSize(width: 300, height: 400)
        let color: UIColor = .black
        UIGraphicsBeginImageContextWithOptions(imageSize, true, 0)
        let context = UIGraphicsGetCurrentContext()!
        color.setFill()
        context.fill(CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        self.previewPhoto = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        previewPhoto = UIImage()

        if let image = ProjectController.loadPreviewImage() {
            self.galleryPreviewImage = image
        } else {
            self.galleryPreviewImage = UIImage()
        }

        // Start updating the users location
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestLocation()
        }

        // Start updating device orientation
        orientationManager.startUpdatingOrientation()
        
        self.configureCaptureSession()

    }


    public func checkForPermissions() {
        /*
        self.locationManager.requestWhenInUseAuthorization()
        */

        /*
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            break
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant
             video access. Suspend the session queue to delay session
             setup until the access request has completed.
             
             Handled by PermissionSwiftUI
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
             */
            break

        default:
            // The user has previously denied access.
            setupResult = .notAuthorized

            DispatchQueue.main.async {
                self.alertError = AlertError(title: "Camera Access", message: "SwiftCamera doesn't have access to use your camera, please update your privacy settings.", primaryButtonTitle: "Settings", secondaryButtonTitle: nil, primaryAction: {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                            options: [:], completionHandler: nil)

                }, secondaryAction: nil)
                self.shouldShowAlertView = true
                self.isCameraUnavailable = true
                self.isCameraButtonDisabled = true
            }
        }
         */
    }

    //  MARK: Session Management
    public func configureCaptureSession() {
        if setupResult != .success {
            return
        }

        if self.isConfigured {
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        // Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?

            if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                // If a rear dual camera is not available, default to the rear wide angle camera.
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                // If the rear wide angle camera isn't available, default to the front wide angle camera.
                defaultVideoDevice = frontCameraDevice
            }


            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }

            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)

            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            } else {
                print("Couldn't add video device input to the session.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            print("Couldn't create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }

        // Add the photo output.
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)

            photoOutput.isLivePhotoCaptureEnabled = false
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.maxPhotoQualityPrioritization = .quality
            photoOutput.isAppleProRAWEnabled = photoOutput.isAppleProRAWSupported
        } else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }

        session.commitConfiguration()

        self.isConfigured = true

        self.captureStatus = .ready

        self.start()
    }

    /// - Tag: Stop capture session
    public func stop(completion: (() -> ())? = nil) {
        self.captureQueue.async {
            self.orientationManager.stopUpdateingOrientation()
            
            if self.isSessionRunning {
                if self.setupResult == .success {
                    self.session.stopRunning()
                    self.isSessionRunning = self.session.isInterrupted

                    if !self.session.isRunning {
                        DispatchQueue.main.async {
                            self.isCameraButtonDisabled = true
                            self.isCameraUnavailable = true
                            completion?()
                        }
                    }
                }
            }
        }
    }

    /// - Tag: Start capture session
    public func start(completion: (() -> ())? = nil) {
//        We use our capture session queue to ensure our UI runs smoothly on the main thread.
        self.captureQueue.async {
            if !self.isSessionRunning && self.isConfigured {
                switch self.setupResult {
                case .success:
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning

                    if self.session.isRunning {
                        DispatchQueue.main.async {
                            self.isCameraButtonDisabled = false
                            self.isCameraUnavailable = false
                            completion?()
                            self.adjustViewfinderSettings()
                        }
                    }

                case .configurationFailed, .notAuthorized:
                    print("Application not authorized to use camera")

                    DispatchQueue.main.async {
                        self.alertError = AlertError(title: "Camera Error", message: "Camera configuration failed. Either your device camera is not available or its missing permissions", primaryButtonTitle: "Accept", secondaryButtonTitle: nil, primaryAction: nil, secondaryAction: nil)
                        self.shouldShowAlertView = true
                        self.isCameraButtonDisabled = true
                        self.isCameraUnavailable = true
                    }
                }
            }
        }
    }

    public func toggleEnhance(enabled: Bool) {
        self.enhanceEnabled = enabled
    }

    public func toggleMask(enabled: Bool) {
        self.maskEnabled = enabled
    }

    public func toggleDebug(enabled: Bool) {
        self.debugEnabled = enabled
    }

    private func clip(value: Float, min: Float, max: Float) -> Float {
        if value < min {
            return min
        }
        if value > max {
            return max
        }
        return value
    }
    
    //    MARK: Capture Photo

    public func startTimelapse() {
        self.captureStatus = .starting

        self.isoRotation = []
        for x in 2...5 {
            self.isoRotation.append(self.videoDeviceInput.device.activeFormat.maxISO / Float(x))
        }

        self.captureQueue.async {
            self.photoStack = PhotoStack(
                    mask: self.maskEnabled,
                    align: self.alignEnabled,
                    enhance: self.enhanceEnabled,
                    location: self.location,
                    orientation: self.orientation
            )

            DispatchQueue.main.async {
                self.captureStatus = .capturing
                self.capturePhoto()
            }

        }
    }


    public func changeCamera(_ device: AVCaptureDevice) {
        self.blackOutCamera = true
        self.captureQueue.async {

            do {
                try device.lockForConfiguration()
                //device.exposureMode = .continuousAutoExposure

                device.setExposureTargetBias(device.maxExposureTargetBias)
                print("Done adjusting brightness to \(device.maxExposureTargetBias)")
                //device.exposureMode = .continuousAutoExposure
                device.unlockForConfiguration()

            } catch {
                print("Failed to adjust brightness")
                // just ignore
            }

            do {
                let videoDevice = try AVCaptureDeviceInput(device: device)

                self.session.removeInput(self.videoDeviceInput)

                if self.session.canAddInput(videoDevice) {
                    self.session.addInput(videoDevice)
                    self.videoDeviceInput = videoDevice
                } else {
                    self.session.addInput(self.videoDeviceInput)
                }


            } catch {
                print("Camera config failed")
            }

            //self.adjustViewfinderSettings()

            DispatchQueue.main.async {
                self.minIso = device.activeFormat.minISO
                self.maxIso = device.activeFormat.maxISO
                self.blackOutCamera = false
            }
        }


    }


    public func focus(_ point: CGPoint) {
        self.captureQueue.async {
            let device = self.videoDeviceInput.device
            do {
                try device.lockForConfiguration()

                device.focusPointOfInterest = point

                device.focusMode = .autoFocus
                device.unlockForConfiguration()
            } catch {
                // just ignore
            }

            DispatchQueue.main.async {
                withAnimation {
                    self.focusDistance = Double(device.lensPosition)
                }
            }
        }
    }

    /**
     Triggers a continous focus update until the methods is called again to stop.
     */
    public func focusUpdate(_ enabled: Bool) {
        if (enabled) {
            self.focusUpdate = true
            continousFocusUpdate()
        } else {
            self.focusUpdate = false
        }
    }

    public func continousFocusUpdate() {
        self.captureQueue.async {
            let device = self.videoDeviceInput.device
            do {
                try device.lockForConfiguration()


                while (self.focusUpdate) {
                    var doneChangingFocus = false;
                    device.setFocusModeLocked(lensPosition: Float(self.focusDistance), completionHandler: { _ in
                        doneChangingFocus = true
                    })

                    while (!doneChangingFocus) {
                        usleep(1000)
                    }
                }
                device.unlockForConfiguration()
            } catch {
                // just ignore
            }

        }
    }

    public func lockFocus() {
        self.captureQueue.async {
            let device = self.videoDeviceInput.device
            do {
                try device.lockForConfiguration()
                //
                device.focusMode = .locked
                device.unlockForConfiguration()
            } catch {
                // just ignore
            }

        }
    }

    /// - Tag: CapturePhoto
    public func capturePhoto() {
        if self.setupResult != .configurationFailed {
            if self.captureStatus == .capturing {
                self.captureQueue.async {
                    //self.isCameraButtonDisabled = true
                    self.photoOutput.connection(with: .video)?.videoOrientation = .portrait

                    let query = self.photoOutput.isAppleProRAWEnabled ?
                            {
                                AVCapturePhotoOutput.isAppleProRAWPixelFormat($0)
                            } :
                            {
                                AVCapturePhotoOutput.isBayerRAWPixelFormat($0)
                            }

                    //guard let rawFormat =
                    //self.photoOutput.availableRawPhotoPixelFormatTypes.first(where: query) else {
                    //    fatalError("No RAW format found.")
                    //}

                    let processedFormat = [AVVideoCodecKey: AVVideoCodecType.hevc]

                    //let photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat, processedFormat: processedFormat)


                    let manualExpSetting = AVCaptureManualExposureBracketedStillImageSettings.manualExposureSettings

                    let autoExpSetting = AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings

                    let maxExposure = self.videoDeviceInput.device.activeFormat.maxExposureDuration

                    var photoSettings: AVCapturePhotoBracketSettings? = nil

                    if self.defaults.bool(forKey: UserOption.rawEnabled.rawValue) {
                        print("Capturing RAW")

                        //TODO: Make sure to only end up here if the device actually supports RAW
                        photoSettings = AVCapturePhotoBracketSettings(
                                rawPixelFormatType: self.photoOutput.availableRawPhotoPixelFormatTypes.first(where: query)!,
                                processedFormat: nil,
                                bracketedSettings: self.isoRotation.map {
                                    if self.defaults.bool(forKey: UserOption.shortExposure.rawValue
                                    ) {
                                        return autoExpSetting(Float($0) / Float($0))
                                    } else {
                                        return manualExpSetting(maxExposure,
                                                                self.clip(value: self.activeIso,
                                                                          min: self.videoDeviceInput.device.activeFormat.minISO,
                                                                          max: self.videoDeviceInput.device.activeFormat.maxISO))
                                    }
                                }
                        )
                    } else {
                        photoSettings = AVCapturePhotoBracketSettings(
                                rawPixelFormatType: 0,
                                processedFormat: processedFormat,
                                bracketedSettings: self.isoRotation.map {
                                    if self.defaults.bool(forKey: UserOption.shortExposure.rawValue
                                    ) {
                                        return autoExpSetting(Float($0) / Float($0))
                                    } else {
                                        return manualExpSetting(maxExposure,
                                                                self.clip(value: self.activeIso,
                                                                          min: self.videoDeviceInput.device.activeFormat.minISO,
                                                                          max: self.videoDeviceInput.device.activeFormat.maxISO))
                                    }
                                }
                        )
                    }

                

                    let photoCaptureProcessor = PhotoCaptureProcessor(with: photoSettings!, willCapturePhotoAnimation: { [weak self] in
                        // Tells the UI to flash the screen to signal that SwiftCamera took a photo.
                        DispatchQueue.main.async {
                            self?.blackOutCamera = true
                        }


                    }, completionHandler: { [weak self] (result, photoCaptureProcessor) in
                        if result == .fatal_error {

                            DispatchQueue.main.async {
                                // Stop the capture and send the thread into processing mode
                                self?.captureStatus = .processing
                                // Call capturePhoto again to make the system recognize it should start processing
                                self?.capturePhoto()

                                self?.alertError = AlertError(
                                        title: "Our of memory",
                                        message: "The capture had to be aborted because your device has run out of memory. If this error keeps appearing, please try to free up device memory, reduce capture size or change capture format to JPEG.",
                                        primaryButtonTitle: "OK",
                                        secondaryButtonTitle: nil,
                                        primaryAction: nil,
                                        secondaryAction: nil
                                )
                                self?.shouldShowAlertView = true
                            }
                        } else {
                            self?.capturePhoto()
                        }

                        DispatchQueue.main.async {
                            // Let the main thread know there's more photos photo
                            self?.numPicures += self!.isoRotation.count
                            self?.isCameraButtonDisabled = false
                        }


                        // Allow settings to the camera again
                        self!.videoDeviceInput.device.unlockForConfiguration()

                        self?.captureQueue.async {
                            self?.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
                        }

                    }, photoProcessingHandler: { [weak self] animate in
                        // Animates a spinner while photo is processing
                        if animate {
                            self?.shouldShowSpinner = true
                        } else {
                            self?.shouldShowSpinner = false
                        }
                    }, photoStack: self.photoStack!, stackingResultsCallback: {
                        // Notfies the UI about the processing progress
                        (result) in
                        DispatchQueue.main.async {
                            switch result {
                            case .SUCCESS:
                                self.numProcessed += 1
                            case .FAILED:
                                self.numFailed += 1
                            case .INIT_FAILED:
                                self.abortCapture()
                            }
                        }
                    }, previewImageCallback: {
                        // Notifies the UI about the preview image
                        (image) in
                        DispatchQueue.main.async {
                            self.previewPhoto = image
                        }
                    })

                    // The photo output holds a weak reference to the photo capture delegate and stores it in an array to maintain a strong reference.
                    self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor

                    //let current_exposure_duration : CMTime = (self.videoDeviceInput.device.exposureDuration)
                    //let current_exposure_ISO : Float = (self.videoDeviceInput.device.iso)

                    DispatchQueue.main.async {
                        self.photoOutput.capturePhoto(with: photoSettings!, delegate: photoCaptureProcessor)
                    }
                }
            } else if self.captureStatus == .processing {


                self.photoStack?.markEndCapture()
                sessionQueue.async {
                    self.photoStack!.saveStack(finished: true, statusUpdateCallback:
                    { (result) in
                        //self.stop(completion: {
                        self.resetCamera(deletingStack: false)
                        //})
                    }
                    )
                }
            }
        } else {
            print("Cannot start. Config failed.")
        }
    }

    public func adjustViewfinderSettings() {
        self.captureQueue.async {
            let device = self.videoDeviceInput.device
            do {
                try device.lockForConfiguration()
                //device.exposureMode = .continuousAutoExposure

                //device.setExposureTargetBias(device.maxExposureTargetBias)
                print("Done adjusting brightness to \(device.maxExposureTargetBias)")
                device.unlockForConfiguration()

            } catch {
                print("Failed to adjust brightness")
                // just ignore
            }

        }
    }

    public func updatePreview(photo: UIImage) {
        self.previewPhoto = photo
    }

    public func abortCapture() {
        DispatchQueue.main.async {
            self.captureStatus = .failed
        }

        //TODO: Delete the stack

        self.resetCamera(deletingStack: true)

        self.alertError = AlertError(
                title: "No stars detected",
                message: "Could not detect enough stars to track. Please make sure the night sky is clearly visible without too many objects in the foreground.",
                primaryButtonTitle: "OK",
                secondaryButtonTitle: nil,
                primaryAction: nil,
                secondaryAction: nil
        )
        self.shouldShowAlertView = true


    }

    private func resetCamera(deletingStack: Bool) {
        print("Camera reset")
        self.start()
        DispatchQueue.main.async {
            self.blackOutCamera = false
            self.captureStatus = .ready
            self.processingProgress = 0
            self.numPicures = 0
            self.numProcessed = 0
            self.numFailed = 0
            self.photoStack = nil
        }
    }

    func processLater() {
        photoStack!.suspendProcessing()
        DispatchQueue.main.async {
            self.captureStatus = .preparing
        }

        photoStack!.saveStack(finished: false, statusUpdateCallback: {
            _ in
            self.stop()

            DispatchQueue.main.async {
                self.resetCamera(deletingStack: false)
            }
        })
    }

}

extension CameraService: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else {
            locationManager.requestLocation()
            return
        }

        self.location = locValue
        print("location = \(locValue.latitude) \(locValue.longitude)")

    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
        locationManager.requestLocation()
    }

}

extension CameraService {
    enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }

    public enum CaptureStatus {
        case preparing
        case ready
        case starting
        case capturing
        case processing
        case failed
    }
}
