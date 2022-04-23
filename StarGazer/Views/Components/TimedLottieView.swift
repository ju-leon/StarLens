//
//  TimedLottieView.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 22.04.22.
//

import Foundation
import SwiftUI
import Lottie

struct TimedLottieView: UIViewRepresentable {
    
    var name: String
    var loopMode: LottieLoopMode = .playOnce
    var page = 0
    
    @Binding var currentPage: Int
    
    var animationView = AnimationView()
    
    func makeUIView(context: UIViewRepresentableContext<TimedLottieView>) -> UIView {
        let view = UIView(frame: .zero)
        
        animationView.animation = Animation.named(name)
        animationView.contentMode = .scaleAspectFit
        
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<TimedLottieView>) {
        if (currentPage > 0) {
            animationView.play(fromFrame: AnimationFrameTime(currentPage * 60), toFrame: AnimationFrameTime((currentPage + 1) * 60), loopMode: .none)
            print("Playing at page \(currentPage)")
        }
        
    }
    
    func playSegment(from: Int, to: Int, loopMode: LottieLoopMode, onCompletion: ((Bool) -> ())?) {
        animationView.play(fromFrame: AnimationFrameTime(from), toFrame: AnimationFrameTime(to), loopMode: loopMode, completion: onCompletion)
    }
}
