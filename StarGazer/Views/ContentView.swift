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
import SlidingRuler

final class CameraModel: ObservableObject {
    public var service = CameraService()
    
    @Published var photo: UIImage!

    @Published var showAlertError = false

    @Published var isFlashOn = false

    @Published var willCapturePhoto = false

    @Published var captureStatus : CameraService.CaptureStatus = .ready
    @Published var numPictures = 0
    @Published var numProcessed = 0
    @Published var numFailed = 0

    @Published var processingProgress = 0.0

    @Published var zoomLevel: Float = 1.0

    @Published var mask: Bool = false
    @Published var debug: Bool = false
    
    @Published var focusDistance: Double = 1.0
    @Published var focusDetailShown: Bool = false
    
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

        service.$blackOutCamera.sink { [weak self] (val) in
                    self?.willCapturePhoto = val
                }
                .store(in: &self.subscriptions)

        service.$captureStatus.sink { [weak self] (val) in
                    self?.captureStatus = val
                }
                .store(in: &self.subscriptions)

        service.$numPicures.sink { [weak self] (val) in
                    self?.numPictures = val
                }
                .store(in: &self.subscriptions)

        service.$numProcessed.sink { [weak self] (val) in
                    self?.numProcessed = val
                }
                .store(in: &self.subscriptions)

        service.$numFailed.sink { [weak self] (val) in
                    self?.numFailed = val
                }
                .store(in: &self.subscriptions)
        
        service.$focusDistance.sink { [weak self] (val) in
                    self?.focusDistance = val
                }
                .store(in: &self.subscriptions)
       

    }

    func configure() {
        service.checkForPermissions()
        service.configure()
    }

    func startTimelapse() {
        UIApplication.shared.isIdleTimerDisabled = true
        service.blackOutCamera = true
        if captureStatus == .ready {
            service.startTimelapse()
        }

    }

    func stopTimelapse() {
        if captureStatus == .capturing {
            service.captureStatus = .processing
        }
        service.blackOutCamera = false
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

    func toggleMask() {
        self.mask = !self.mask
        service.toggleMask(enabled: self.mask)
    }
    
    func toggleDebug() {
        self.debug = !self.debug
        service.toggleDebug(enabled: self.debug)
    }

    func processLater() {
        service.processLater()
    }
    
    func focusUpdate(_ value: Bool) {
        self.focusDetailShown = value
        service.focusUpdate(value)
    }
    
    func setFocusDistance(value: Double) {
        service.focusDistance = value
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
                model.toggleMask()
            }, label: {
                if model.mask {
                    //Label("HDR", systemImage: "square.stack.3d.up.fill").foregroundColor(.white)
                    Image(systemName: "moon.stars.fill").foregroundColor(.white)
                } else {
                    //Label("HDR", systemImage: "square.stack.3d.up").foregroundColor(.white).opacity(0.5)
                    Image(systemName: "moon.stars").foregroundColor(.white).opacity(0.5)
                }
            }).animation(.easeInOut(duration: 0.2))
            
            Spacer()
            
            Button(action: {
                model.toggleDebug()
            }, label: {
                if model.debug {
                    //Label("HDR", systemImage: "square.stack.3d.up.fill").foregroundColor(.white)
                    Image(systemName: "chevron.left.forwardslash.chevron.right").foregroundColor(.white)
                } else {
                    //Label("HDR", systemImage: "square.stack.3d.up").foregroundColor(.white).opacity(0.5)
                    Image(systemName: "chevron.left.forwardslash.chevron.right").foregroundColor(.white).opacity(0.5)
                }
            }).animation(.easeInOut(duration: 0.2))
            
            

            Spacer()

            /*
            Button(action: {
                model.toggleAlign()
            }, label: {
                if model.align {
                    //Label("HDR", systemImage: "square.stack.3d.up.fill").foregroundColor(.white)
                    Image(systemName: "trapezoid.and.line.horizontal.fill").foregroundColor(.white)
                } else {
                    //Label("HDR", systemImage: "square.stack.3d.up").foregroundColor(.white).opacity(0.5)
                    Image(systemName: "perspective").foregroundColor(.white).opacity(0.5)
                }
            }).animation(.easeInOut(duration: 0.2))


            Spacer()

            Button(action: {
                model.toggleEnhance()
            }, label: {
                if model.enhance {
                    //Label("HDR", systemImage: "square.stack.3d.up.fill").foregroundColor(.white)
                    Image(systemName: "wand.and.stars").foregroundColor(.white)
                } else {
                    //Label("HDR", systemImage: "square.stack.3d.up").foregroundColor(.white).opacity(0.5)
                    Image(systemName: "wand.and.stars.inverse").foregroundColor(.white).opacity(0.5)
                }
            }).animation(.easeInOut(duration: 0.2))


            Spacer()
             */
        }
    }
}


struct CameraView: View {
    @ObservedObject var model = CameraModel()
    @StateObject var navigationModel: StateControlModel
    

    @State var currentZoomFactor: CGFloat = 1.0

    @State var currentFocus: CGFloat = 0.7
    
    var captureButton: some View {
        Button(action: {
            if model.captureStatus == .ready {
                model.startTimelapse()
            } else if model.captureStatus == .capturing {
                model.stopTimelapse()
            }
        }, label: {
            if model.captureStatus == .ready {

                Circle()
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80, alignment: .center)
                        .overlay(
                                Circle()
                                        .stroke(Color.black.opacity(0.8), lineWidth: 2)
                                        .frame(width: 65, height: 65, alignment: .center)
                        )
            } else if model.captureStatus == .capturing {
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
            } else {
                Circle()
                    .foregroundColor(.white).opacity(0.5)
                        .frame(width: 80, height: 80, alignment: .center)
                        .overlay(
                                Circle()
                                    .foregroundColor(.black)
                                    .frame(width: 65, height: 65, alignment: .center)
                                    .overlay(
                                        ProgressView().frame(width: 50, height: 50, alignment: .center)
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
            if model.captureStatus != .capturing {

                GeometryReader {
                    geometry in
                    VStack(alignment: .center) {
                        OptionsBar(model: model).padding()
                        ZStack {
                            CameraPreview(tappedCallback: { point in
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
                            VStack {
                                Spacer()
                                zoomSelector.padding()
                                //TODO: Properly align
                            }
                            
                        }
                        
                        SlidingRuler(value:
                                        Binding(get: {self.model.focusDistance},
                                                set: {self.model.service.focusDistance = $0}),
                                     in: 0...1,
                                     step: 0.5,
                                     tick: .fraction,
                                     onEditingChanged: {
                            (value) in
                            
                            model.focusUpdate(value)
                            
                        }).foregroundColor(.white).background(.black)
                        Spacer()
                        
                    }

                }
            } else {
                Spacer()
                HStack {
                    Spacer()
                    Label(String(model.numPictures), systemImage: "sparkles.rectangle.stack").foregroundColor(.white)
                    Spacer()
                    Label(String(model.numProcessed), systemImage: "checkmark.circle").foregroundColor(.white)
                    Spacer()
                    Label(String(model.numFailed), systemImage: "xmark.circle").foregroundColor(.white)
                    Spacer()
                }
                Spacer()
                
                Image(uiImage: model.photo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipped()
                Spacer()
            }

            HStack {
                //capturedPhotoThumbnail

                //Spacer().frame(maxWidth: .infinity)

                Button(action: {
                    withAnimation {
                        self.navigationModel.currentView = .projects
                    }
                }, label:{
                    ZStack {
                        //Color.white
                        Image(uiImage: self.model.service.galleryPreviewImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipped()
                        LinearGradient(colors: [.white, .gray], startPoint: .top, endPoint: .bottom).opacity(0.4)
                    }.frame(width: 50, height: 50, alignment: .center)
                     .cornerRadius(15)

                        
                })
                
                Spacer()
                
                captureButton//.frame(maxWidth: .infinity)

                Spacer()
                
                Button(action: {
                    withAnimation {
                        self.navigationModel.currentView = .settings
                    }
                }, label:{
                    Image(systemName: "gear").font(.system(size: 40)).foregroundColor(.white)
                }).frame(width: 50, height: 50, alignment: .center)

                //flipCameraButton

            }.padding(.horizontal, 20).frame(maxWidth: .infinity)
        }

    }

    var processingView: some View {
        ProcessingView(numFailed: $model.numFailed,
                numProcessed: $model.numProcessed,
                numPictures: $model.numPictures,
                photo: $model.photo,
                cancelProcessing: model.processLater)

    }
    

    var body: some View {
        GeometryReader { reader in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                if (model.captureStatus == .processing) {
                    processingView
                } else {
                    captureView
                }
            }
        }
    }
}
