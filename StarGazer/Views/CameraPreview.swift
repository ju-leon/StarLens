//
//  CameraPreview.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 19.12.21.
//


import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    var tappedCallback: ((CGPoint) -> Void)
    
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
             AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    class Coordinator:NSObject {
        var tappedCallback: ((CGPoint) -> Void)
        init(tappedCallback: @escaping ((CGPoint) -> Void)) {
            self.tappedCallback = tappedCallback
        }
        @objc func tapped(gesture:UITapGestureRecognizer) {
            let point = gesture.location(in: gesture.view)
            self.tappedCallback(point)
        }
    }
    
    func makeCoordinator() -> CameraPreview.Coordinator {
        return Coordinator(tappedCallback:self.tappedCallback)
    }
    
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.cornerRadius = 0
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.connection?.videoOrientation = .portrait

        let gesture = UITapGestureRecognizer(target: context.coordinator,
                                                     action: #selector(Coordinator.tapped))
        view.addGestureRecognizer(gesture)
        
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        
    }
}

struct CameraPreview_Previews: PreviewProvider {
    static var previews: some View {
        CameraPreview(tappedCallback: {_ in}, session: AVCaptureSession() )
            .frame(height: 300)
    }
}
