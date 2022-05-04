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
    
    @Published var minIso: Float = 100.0
    @Published var maxIso: Float = 100.0
    @Published var currentIso: Float = 400.0
    
    @Published var flashEnabled: Bool = false
    @Published var maskEnabled: Bool = true
    @Published var timerEnabled: Bool = false
    
    @Published var timerValue: Int = 0
    
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
        
        service.$minIso.sink { [weak self] (val) in
                    self?.minIso = val
                }
                .store(in: &self.subscriptions)
        
        service.$maxIso.sink { [weak self] (val) in
                    self?.maxIso = val
                }
                .store(in: &self.subscriptions)

        service.$activeIso.sink { [weak self] (val) in
                    self?.currentIso = val
                }
                .store(in: &self.subscriptions)

        service.$flashEnabled.sink { [weak self] (val) in
                    self?.flashEnabled = val
                }
                .store(in: &self.subscriptions)

        service.$maskEnabled.sink { [weak self] (val) in
                    self?.maskEnabled = val
                }
                .store(in: &self.subscriptions)

        service.$timerEnabled.sink { [weak self] (val) in
                    self?.timerEnabled = val
                }
                .store(in: &self.subscriptions)
        
        service.$timerValue.sink { [weak self] (val) in
                    self?.timerValue = val
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

    func setMaskEnabled(value: Bool) {
        self.service.maskEnabled = value
    }
    
    func setFlashEnabled(value: Bool) {
        self.service.flashEnabled = value
    }
    
    func setTimerEnabled(value: Bool) {
        self.service.timerEnabled = value
    }
}

struct CameraOptionsBar : View {
    @State var maskEnabled = DefaultsManager.readBool(option: .isMaskEnabled)
    
    @State var timerIndex : Int
    
    @State var flashEnabled = false
    
    init() {
        let hasTime = TIMER_STATES.contains(where: {$0 == DefaultsManager.readInt(option: .timerValue)})
        
        if hasTime {
            timerIndex = TIMER_STATES.firstIndex{ $0 == DefaultsManager.readInt(option: .timerValue) }!
        } else {
            timerIndex = 0
        }
    }
    
    var body: some View {
        HStack {
            Spacer()

            Button(action: {
                maskEnabled.toggle()
                DefaultsManager.saveBool(option: .isMaskEnabled, state: maskEnabled)
            }, label: {
                Image(maskEnabled ? "star-auto" : "star-off")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20, alignment: .center)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding()
            }).opacity(maskEnabled ? 1.0 : 0.5)
            
            Spacer()
            
            Button(action: {
                timerIndex = (timerIndex + 1) % TIMER_STATES.capacity
                DefaultsManager.saveInt(option: .timerValue, state: TIMER_STATES[timerIndex])
            }, label: {
                
                    Image(systemName: "timer")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding()
                        .overlay(
                            Spacer()
                                .frame(width: 23, height: 23, alignment: .center).overlay(
                                    Circle().fill(.black).frame(width: 12, height: 12, alignment: .center).overlay(
                                        Image(systemName: "\(TIMER_STATES[timerIndex]).circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white)
                                    ),
                                    alignment: .bottomTrailing
                                ).opacity(timerIndex == 0 ? 0 : 1)
                        )
            }).opacity(timerIndex == 0 ? 0.5 : 1.0)
            
            Spacer()
            
            Button(action: {
                flashEnabled.toggle()
            }, label: {
                Image(systemName: flashEnabled ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding()
            }).opacity(flashEnabled ? 1.0 : 0.5)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
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
                //Spacer()
                VStack {
                    CameraOptionsBar()
                    Spacer()
                    ZStack(alignment: .bottom) {
                        GeometryReader {
                            geometry in
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
                                                        Color.black.overlay(
                                                            Text(String(model.timerValue))
                                                                .font(.system(size: 100))
                                                        )
                                                    }
                                                    
                                                    if model.captureStatus == .permission {
                                                        Text("Camera permission not granted.\n\nGo to Settings>Privacy>Camera and allow StarLens to use the camera, then restart the app.")
                                                            .multilineTextAlignment(.center)
                                                            .padding()
                                                    }
                                                }
                                        )
                                        .animation(.easeInOut)
                        }
                        zoomSelector.padding()
                        
                    }
                    Spacer()
                }
                
                SegmentedPicker(focusValue: Binding(get: {self.model.focusDistance},
                                                    set: {self.model.service.focusDistance = $0}),
                                onFocusChanged: {
                                    (value) in
                                    model.focusUpdate(value)
                                },
                                isoValue: Binding(get: {self.model.currentIso},
                                                  set: {self.model.service.activeIso = $0}),
                                isoMin: Binding(get: {self.model.minIso}, set: {_ in}),
                                isoMax: Binding(get: {self.model.maxIso}, set: {_ in}),
                                maskEnabled: Binding(get: {self.model.maskEnabled}, set: self.model.setMaskEnabled),
                                timerEnabled: Binding(get: {self.model.timerEnabled}, set: self.model.setTimerEnabled),
                                flashEnabled: Binding(get: {self.model.flashEnabled}, set: self.model.setFlashEnabled)
                )
                Spacer(minLength: 20)
                
                
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
                if model.captureStatus != .capturing {
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
                            //LinearGradient(colors: [.white, .gray], startPoint: .top, endPoint: .bottom).opacity(0.4)
                        }.frame(width: 50, height: 50, alignment: .center)
                         .cornerRadius(15)

                    })
                }
                Spacer()
                
                captureButton//.frame(maxWidth: .infinity)

                Spacer()
                if model.captureStatus != .capturing {
                    ModalPresenter {
                        ModalLink(destination: {
                            dismiss in
                            SettingsView(navigationModel: navigationModel, onDone: dismiss).environment(\.colorScheme, .dark)
                        },
                        label: {
                            Image(systemName: "gear").font(.system(size: 40)).foregroundColor(.white)
                        }).frame(width: 50, height: 50, alignment: .center)
                    }
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
        }.onDisappear(perform: {
            model.service.stop()
        })
    }
}
