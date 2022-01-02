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
    
    var alertError: AlertError!
    
    var session: AVCaptureSession
    
    private var subscriptions = Set<AnyCancellable>()
    
    init() {
        self.session = service.session
        
        service.$previewPhoto.sink { [weak self] (photo) in
            guard let pic = photo else { return }
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
        
        service.$willCapturePhoto.sink { [weak self] (val) in
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
    
    
    var captureView: some View {
        VStack {
            Label(String(model.numPictures), systemImage: "sparkles.rectangle.stack").foregroundColor(.white)
            
            if !model.isRecording {
                CameraPreview(session: model.session)
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
            }
            else {
                Image(uiImage: model.photo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipped()
                    .frame(height: 600)
            }
            
            HStack {
                //capturedPhotoThumbnail
                
                Spacer()
                
                captureButton
                
                //Spacer()
                
                Spacer()
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
