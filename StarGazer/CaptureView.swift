//
//  CaptureView.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 19.12.21.
//

import Foundation
import SwiftUI
import AVFoundation

struct CaptureView: UIViewRepresentable {
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
             AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.cornerRadius = 0
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.connection?.videoOrientation = .portrait

        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        
    }
}

struct CaptureViewPreview: PreviewProvider {
    static var previews: some View {
        CaptureView(session: AVCaptureSession())
            .frame(height: 300)
    }
}
