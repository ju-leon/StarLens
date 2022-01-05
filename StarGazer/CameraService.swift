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

//  MARK: Class Camera Service, handles setup of AVFoundation needed for a basic camera app.
public struct Photo: Identifiable, Equatable {
//    The ID of the captured photo
    public var id: String
//    Data representation of the captured photo
    public var originalData: Data
    
    public init(id: String = UUID().uuidString, originalData: Data) {
        self.id = id
        self.originalData = originalData
    }
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

extension Photo {
    public var compressedData: Data? {
        ImageResizer(targetWidth: 800).resize(data: originalData)?.jpegData(compressionQuality: 0.5)
    }
    public var thumbnailData: Data? {
        ImageResizer(targetWidth: 100).resize(data: originalData)?.jpegData(compressionQuality: 0.5)
    }
    public var thumbnailImage: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }
    public var image: UIImage? {
        guard let data = compressedData else { return nil }
        return UIImage(data: data)
    }
}

public class CameraService : NSObject {
    typealias PhotoCaptureSessionID = String
    
//    MARK: Observed Properties UI must react to
    
//    1.
    @Published public var flashMode: AVCaptureDevice.FlashMode = .off
//    2.
    @Published public var shouldShowAlertView = false
//    3.
    @Published public var shouldShowSpinner = false
//    4.
    @Published public var willCapturePhoto = false
//    5.
    @Published public var isCameraButtonDisabled = true
//    6.
    @Published public var isCameraUnavailable = true
//    8.
    @Published public var isCaptureRunning = false
    
    @Published public var photo: Photo?
    
    @Published public var previewPhoto: UIImage?
    
    @Published public var numPicures = 0

    @Published public var isProcessing = false
    
    @Published public var processingProgress = 0.0
    
//    MARK: Alert properties
    public var alertError: AlertError = AlertError()
    
// MARK: Session Management Properties
    
//    9
    public let session = AVCaptureSession()
    public let locationManager = CLLocationManager()
    public let motionManager = CMMotionManager()
//    10
    var isSessionRunning = false
//    12
    var isConfigured = false
//    13
    var setupResult: SessionSetupResult = .success
//    14
    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    // MARK: Device Configuration Properties
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)
    
    // MARK: Capturing Photos
    
    private let photoOutput = AVCapturePhotoOutput()
    
    private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
    
    // MARK: KVO and Notifications Properties
    
    private var keyValueObservations = [NSKeyValueObservation]()
    
    private var photoStack : PhotoStack = PhotoStack(location: CLLocationCoordinate2D(latitude: 0, longitude: 0))
    private var location : CLLocationCoordinate2D?
    
    private let isoRotation: [Float] = [200, 400] //, 800, 1600]
    private var isoRotationIndex = 0

    public static let biasRotation: [Float] = [-1, -0.5, 0, 0.5]
    private var biasRotationIndex = 0
    
    public func configure() {
        /*
         Setup the capture session.
         In general, it's not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.
         
         Don't perform these tasks on the main queue because
         AVCaptureSession.startRunning() is a blocking call, which can
         take a long time. Dispatch session setup to the sessionQueue, so
         that the main queue isn't blocked, which keeps the UI responsive.
         */
        
        let imageSize = CGSize(width: 300, height: 400)
        let color: UIColor = .black
        UIGraphicsBeginImageContextWithOptions(imageSize, true, 0)
        let context = UIGraphicsGetCurrentContext()!
        color.setFill()
        context.fill(CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        self.previewPhoto = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        
        // Start updating the users location
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestLocation()
        }
        
        self.configureCaptureSession()
        
    }
    
    //        MARK: Checks for user's permisions
    public func checkForPermissions() {
        
        self.locationManager.requestWhenInUseAuthorization()
        
      
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            break
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant
             video access. Suspend the session queue to delay session
             setup until the access request has completed.
             */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
            
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
    }
    
    //  MARK: Session Management
    public func configureCaptureSession() {
        
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        
        session.sessionPreset = .photo

        
        // Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            if let backCameraDevice = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) {
                // If a rear dual camera is not available, default to the rear wide angle camera.
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
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
        
        self.start()
    }
    
    /// - Tag: Stop capture session
    public func stop(completion: (() -> ())? = nil) {
        sessionQueue.async {
            if self.isSessionRunning {
                if self.setupResult == .success {
                    self.session.stopRunning()
                    self.isSessionRunning = self.session.isRunning
                    
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
        sessionQueue.async {
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
    
    //    MARK: Capture Photo
    
    public func startTimelapse() {
        self.isCaptureRunning = true
        self.setupCameraProperties()
    }
    
    func setupCameraProperties() {
        let device = self.videoDeviceInput.device
        do {
            try device.lockForConfiguration()
            
            //device.setFocusModeLocked(lensPosition: 0.78)



            /*
            device.setExposureModeCustom(duration: device.activeFormat.maxExposureDuration,
                                         iso: self.isoRotation[self.isoRotationIndex], // AVCaptureDevice.currentISO,
                                         completionHandler: { (val: CMTime) -> Void in
                                            print("Exposure duration: \(val.seconds)")
                                            self.capturePhoto()
                                        })

            */
            self.capturePhoto()

            /*
            device.setExposureTargetBias(CameraService.biasRotation[biasRotationIndex], completionHandler: { (val: CMTime) -> Void in
                print("Captre duration: \(val)")
                
                self.capturePhoto()
            })
            */
            device.unlockForConfiguration()
            
            isoRotationIndex = (isoRotationIndex + 1) % isoRotation.count
            biasRotationIndex = (biasRotationIndex + 1) % CameraService.biasRotation.count

        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    
    /// - Tag: CapturePhoto
    public func capturePhoto() {
        if self.setupResult != .configurationFailed {
            if self.isCaptureRunning {
                //self.isCameraButtonDisabled = true
                
                sessionQueue.async {
                    if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                        photoOutputConnection.videoOrientation = .portrait
                    }
                    
                    let query = self.photoOutput.isAppleProRAWEnabled ?
                        { AVCapturePhotoOutput.isAppleProRAWPixelFormat($0) } :
                        { AVCapturePhotoOutput.isBayerRAWPixelFormat($0) }
                    
                    guard let rawFormat =
                            self.photoOutput.availableRawPhotoPixelFormatTypes.first(where: query) else {
                        fatalError("No RAW format found.")
                    }
                    
                    let processedFormat = [AVVideoCodecKey: AVVideoCodecType.hevc]
                    
                    let photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat, processedFormat: processedFormat)
                    
                    
                    // Sets the flash option for this capture.
                    if self.videoDeviceInput.device.isFlashAvailable {
                        photoSettings.flashMode = self.flashMode
                    }
                    
                    
                    photoSettings.isHighResolutionPhotoEnabled = true
                    
                    
                    // Sets the preview thumbnail pixel format
                    if !photoSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
                        photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoSettings.__availablePreviewPhotoPixelFormatTypes.first!]
                    }
                    
                    photoSettings.photoQualityPrioritization = .quality
                    
                    let photoCaptureProcessor = PhotoCaptureProcessor(with: photoSettings, willCapturePhotoAnimation: { [weak self] in
                        // Tells the UI to flash the screen to signal that SwiftCamera took a photo.
                        DispatchQueue.main.async {
                            self?.willCapturePhoto = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            self?.willCapturePhoto = false
                        }
                        
                    }, completionHandler: { [weak self] (photoCaptureProcessor) in
                        // Update the preview
                        self?.previewPhoto =  photoCaptureProcessor.previewPhoto
                        
                        // Let the main thread knoq there's another photo
                        self?.numPicures += 1
                        
                        self?.isCameraButtonDisabled = false
                        
                        self?.sessionQueue.async {
                            self?.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
                        }
                    }, photoProcessingHandler: { [weak self] animate in
                        // Animates a spinner while photo is processing
                        if animate {
                            self?.shouldShowSpinner = true
                        } else {
                            self?.shouldShowSpinner = false
                        }
                    }, service: self, photoStack: self.photoStack )
                    
                    // The photo output holds a weak reference to the photo capture delegate and stores it in an array to maintain a strong reference.
                    self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
                    self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
                }
            }
        } else {
            print("Config failed")
            
            self.stop()
            
            self.isProcessing = true
            
            sessionQueue.async {
                self.stop()
                self.photoStack.stackPhotos({(x: Double) -> () in
                    DispatchQueue.main.async {
                        self.processingProgress = x
                    }
                })
                self.photoStack.saveStack()
            }
        }
    }
    
    public func updatePreview(photo: UIImage) {
        self.previewPhoto = photo
    }
    
}

extension CameraService : CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else {
            locationManager.requestLocation()
            return
        }
        
        self.location = locValue
        print("location = \(locValue.latitude) \(locValue.longitude)")
        
        self.photoStack.setLocation(location: locValue)
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
        locationManager.requestLocation()
    }

}

extension CameraService {
    enum LivePhotoMode {
        case on
        case off
    }
    
    enum DepthDataDeliveryMode {
        case on
        case off
    }
    
    enum PortraitEffectsMatteDeliveryMode {
        case on
        case off
    }
    
    enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    enum CaptureMode: Int {
        case photo = 0
        case movie = 1
    }
}
