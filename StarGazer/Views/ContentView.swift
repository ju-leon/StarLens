//
//  ContentView.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 16.12.21.
//

import SwiftUI
import Combine
import AVFoundation
import UIKit

final class CameraModel: ObservableObject {
    private let service = CameraService()

    @Published var photo: UIImage!

    @Published var showAlertError = false

    @Published var isFlashOn = false

    @Published var willCapturePhoto = false

    @Published var isRecording = false
    @Published var numPictures = 0

    @Published var isProcessing = false
    @Published var processingProgress = 0.0

    @Published var zoomLevel: Float = 1.0
    
    @Published var hdr: Bool = true
    
    var alertError: AlertError!

    var session: AVCaptureSession

    private var subscriptions = Set<AnyCancellable>()

    init() {
        self.session = service.session

        service.$previewPhoto.sink { [weak self] (photo) in
                    guard let pic = photo else {
                        return
                    }
                    self?.photo = pic
                }
                .store(in: &self.subscriptions)

        service.$shouldShowAlertView.sink { [weak self] (val) in
                    self?.alertError = self?.service.alertError
                    self?.showAlertError = val
                }
                .store(in: &self.subscriptions)

        service.$flashMode.sink { [weak self] (mode) in
                    self?.isFlashOn = mode == .on
                }
                .store(in: &self.subscriptions)

        service.$blackOutCamera.sink { [weak self] (val) in
                    self?.willCapturePhoto = val
                }
                .store(in: &self.subscriptions)

        service.$isCaptureRunning.sink { [weak self] (val) in
                    self?.isRecording = val
                }
                .store(in: &self.subscriptions)

        service.$numPicures.sink { [weak self] (val) in
                    self?.numPictures = val
                }
                .store(in: &self.subscriptions)

        service.$isProcessing.sink { [weak self] (val) in
                    self?.isProcessing = val
                }
                .store(in: &self.subscriptions)

        service.$processingProgress.sink { [weak self] (val) in
                    self?.processingProgress = val
                }
                .store(in: &self.subscriptions)

    }

    func configure() {
        service.checkForPermissions()
        service.configure()
    }

    func startTimelapse() {
        UIApplication.shared.isIdleTimerDisabled = true
        //service.blackOutCamera = true
        service.isCaptureRunning = true
        service.startTimelapse()
    }

    func stopTimelapse() {
        service.isCaptureRunning = false
        //UIApplication.shared.isIdleTimerDisabled = false
    }

    func switchFlash() {
        service.flashMode = service.flashMode == .on ? .off : .on
    }
    
    func switchCamera(level: Float) {
        if (level == self.zoomLevel) {
            return
        }
        
        var backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        if (level < 1.0) {
            backCameraDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
        } else if (level > 1.0) {
            backCameraDevice = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
        }
        
        if (backCameraDevice == nil) {
            print("Illegal camera config")
            return
        }
        self.zoomLevel = level

        service.changeCamera(backCameraDevice!)
    }

    func tapToFocus(_ point: CGPoint, _ size: CGSize) {
        let x = point.y / size.height
        let y = 1.0 - point.x / size.width
        let focusPoint = CGPoint(x: x, y: y)
        
        self.service.focus(focusPoint)
    }
    
    func toogleHdr() {
        self.hdr = !self.hdr
        service.toogleHdr(enabled: self.hdr)
    }

}

struct ZoomButton: View {
    @StateObject var model = CameraModel()
    @State var zoom: Float = 1.0
    
    var body: some View {
        Button(action: {
            model.switchCamera(level: zoom)
        }, label: {
            Circle()
                    .foregroundColor(zoom == model.zoomLevel ? .white.opacity(0.4) : .white.opacity(0.1))
                    .frame(width: zoom == model.zoomLevel ? 40 : 30, height: zoom == model.zoomLevel ? 40 : 30, alignment: .center)
                    .overlay(Text(String(zoom)).foregroundColor(
                        .yellow
                    ).font(.system(size: 10).bold()))
                    .animation(.easeInOut)
        })
    }
}


struct OptionsBar: View {
    @StateObject var model = CameraModel()
    
    var body: some View {
        HStack {
            
            Spacer()
            
            Button(action: {
                model.toogleHdr()
            }, label: {
                if model.hdr {
                    //Label("HDR", systemImage: "square.stack.3d.up.fill").foregroundColor(.white)
                    Image(systemName: "square.stack.3d.up.fill").foregroundColor(.white)
                } else {
                    //Label("HDR", systemImage: "square.stack.3d.up").foregroundColor(.white).opacity(0.5)
                    Image(systemName: "square.stack.3d.up.slash").foregroundColor(.white).opacity(0.5)
                }
            }).animation(.easeInOut(duration: 0.2))
            
            Spacer()
            
            Button(action: {
                print("Flash")
            }, label: {
                if true {
                    //Label("HDR", systemImage: "square.stack.3d.up.fill").foregroundColor(.white)
                    Image(systemName: "bolt.fill").foregroundColor(.white)
                } else {
                    //Label("HDR", systemImage: "square.stack.3d.up").foregroundColor(.white).opacity(0.5)
                    Image(systemName: "bolt.slash").foregroundColor(.white).opacity(0.5)
                }
            }).animation(.easeInOut(duration: 0.2))
            
            
            Spacer()
        }
    }
}

struct CameraView: View {
    @StateObject var model = CameraModel()
    @StateObject var navigationModel: NavigationModel

    @State var currentZoomFactor: CGFloat = 1.0

    var captureButton: some View {
        Button(action: {
            if !model.isRecording {
                model.startTimelapse()
            } else {
                model.stopTimelapse()
            }
        }, label: {
            if !model.isRecording {

                Circle()
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80, alignment: .center)
                        .overlay(
                                Circle()
                                        .stroke(Color.black.opacity(0.8), lineWidth: 2)
                                        .frame(width: 65, height: 65, alignment: .center)
                        )
            } else {
                Circle()
                        .foregroundColor(.red)
                        .frame(width: 80, height: 80, alignment: .center)
                        .overlay(
                                Circle()
                                        .foregroundColor(.black)
                                        .frame(width: 65, height: 65, alignment: .center)
                                        .overlay(
                                                RoundedRectangle(cornerRadius: 5)
                                                        .foregroundColor(.red)
                                                        .frame(width: 30, height: 30, alignment: .center)
                                        )
                        )
            }

        })
    }



    var zoomSelector: some View {
        ZStack {
            Rectangle()
                    .foregroundColor(.white.opacity(0.1))
                    .cornerRadius(25)
                    .frame(width: 130, height: 50, alignment: .center)

            HStack {
                ZoomButton(model: model, zoom: 0.5)
                ZoomButton(model: model, zoom: 1.0)
                ZoomButton(model: model, zoom: 3.0)
            }
        }
    }


    var captureView: some View {
        VStack {
            if !model.isRecording {

                GeometryReader {
                    geometry in
                    VStack(alignment: .center) {
                        OptionsBar(model: model).padding()
                        CameraPreview(tappedCallback: {point in
                                model.tapToFocus(point, geometry.size)
                            }, session: model.session)
                                    .onAppear {
                                        model.configure()
                                    }
                                    .alert(isPresented: $model.showAlertError, content: {
                                        Alert(title: Text(model.alertError.title), message: Text(model.alertError.message), dismissButton: .default(Text(model.alertError.primaryButtonTitle), action: {
                                            model.alertError.primaryAction?()
                                        }))
                                    })
                                    
                                    .overlay(
                                            Group {
                                                if model.willCapturePhoto {
                                                    Color.black
                                                }
                                            }
                                    )
                                    .animation(.easeInOut)
                        zoomSelector.padding()
                    }
                    
                }
            } else {
                Label(String(model.numPictures), systemImage: "sparkles.rectangle.stack").foregroundColor(.white)
                Image(uiImage: model.photo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipped()
                        .frame(height: 600)
            }

            HStack {
                //capturedPhotoThumbnail

                Spacer().frame(maxWidth: .infinity)
                
                

                captureButton.frame(maxWidth: .infinity)
                
                Image(systemName: "dial.max").font(.system(size: 40)).frame(maxWidth: .infinity)
                
                //flipCameraButton

            }
                    .padding(.horizontal, 20)
        }

    }

    var processingView: some View {
        ZStack {
            Image(uiImage: model.photo)
                    .resizable()
                    .clipped()

            Color.black.edgesIgnoringSafeArea(.all).opacity(0.5)

            VStack {
                ProgressView("Processing…", value: model.processingProgress, total: 1)
                        .foregroundColor(.white)
                        .padding(.all)
                        .animation(.easeInOut)
            }
        }
    }

    var body: some View {
        GeometryReader { reader in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                if (!model.isProcessing) {
                    captureView
                } else {
                    processingView
                }
            }
        }
    }
}
