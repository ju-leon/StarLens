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
import Lottie
import ModalView

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
    
    @Published var mask: Bool = false
    @Published var debug: Bool = false
    
    @Published var focusDistance: Double = 1.0
    @Published var focusDetailShown: Bool = false
    
    @Published var availableZoomLevels: [CameraZoomLevel] = []
    @Published var activeZoomLevel: CameraZoomLevel
    
    
    var alertError: AlertError!

    var session: AVCaptureSession

    private var subscriptions = Set<AnyCancellable>()

    init() {
        self.session = service.session
        
        self.availableZoomLevels = self.service.availableZoomLevels
        self.activeZoomLevel = service.activeZoomLevel
        
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
    
    func switchCamera(level: CameraZoomLevel) {
        if (level.id == self.activeZoomLevel.id) {
            return
        }
        
        self.activeZoomLevel = level
        service.changeCamera(level.device)
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
        }
    }
}


struct CameraOptionsBar : View {
    var body: some View {
    
        HStack {
            Spacer()
            
            Button(action: {
                
            }, label: {
                Image(systemName: "gyroscope")
                    .font(.system(size: 25))
                    .foregroundColor(.white)
                    .padding()
            }).animation(.easeInOut(duration: 0.2))
            
            Spacer()
            
            Button(action: {
                
            }, label: {
                
                Image(systemName: "circle.dashed.inset.filled")
                    .font(.system(size: 25))
                    .foregroundColor(.white)
                    .padding()
            }).animation(.easeInOut(duration: 0.2))
            
            Spacer()
            
            Button(action: {
                
            }, label: {
                Image(systemName: "circle.righthalf.filled")
                    .font(.system(size: 25))
                    .foregroundColor(.white)
                    .padding()
            }).animation(.easeInOut(duration: 0.2))
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color.init(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.1))
        .cornerRadius(30)
        .padding()
        
    }
}

struct ZoomButton: View {
    @StateObject var model = CameraModel()
    @State var zoomLevel: CameraZoomLevel

    var body: some View {
        Button(action: {
            model.switchCamera(level: zoomLevel)
        }, label: {
            Circle()
                .foregroundColor(zoomLevel.id == model.activeZoomLevel.id ? .white.opacity(0.4) : .white.opacity(0.1))
                .frame(width: zoomLevel.id == model.activeZoomLevel.id ? 40 : 30,
                       height: zoomLevel.id == model.activeZoomLevel.id ? 40 : 30, alignment: .center)
                    .overlay(Text(String(zoomLevel.zoomLevel)).foregroundColor(
                            .yellow
                    ).font(.system(size: 10).bold()))
                    .animation(.easeInOut)
        })
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
                LottieView(name: "shutterstill", loopMode: .playOnce).frame(width: 80, height: 80)
                
                /*
                Circle()
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80, alignment: .center)
                        .overlay(
                                Circle()
                                        .stroke(Color.black.opacity(0.8), lineWidth: 2)
                                        .frame(width: 65, height: 65, alignment: .center)
                        )
                 
             */
            } else if model.captureStatus == .capturing {
                LottieView(name: "shutter", loopMode: .loop).frame(width: 80, height: 80)
                
            } else {
                LottieView(name: "shutterprep", loopMode: .loop).frame(width: 80, height: 80)
            }

        }).disabled(!(model.captureStatus == .ready || model.captureStatus == .capturing))
    }


    var zoomSelector: some View {
        ZStack {
            HStack {
                ForEach(model.availableZoomLevels) {zoomLevel in
                    ZoomButton(model: model, zoomLevel: zoomLevel)
                }
            }.padding([.leading, .trailing], 8).padding([.top, .bottom], 5)
        }
        .background(.white.opacity(0.3))
        .cornerRadius(25)
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
                        
                        /*
                        CameraOptionsBar()
                        */
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
                
                ModalPresenter {
                    ModalLink(destination: {
                        dismiss in
                        SettingsView(navigationModel: navigationModel, onDone: dismiss).environment(\.colorScheme, .dark)
                    },
                    label: {
                        Image(systemName: "gear").font(.system(size: 40)).foregroundColor(.white)
                    }).frame(width: 50, height: 50, alignment: .center)
                }
                
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
