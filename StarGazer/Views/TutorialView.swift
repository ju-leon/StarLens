//
//  TutorialVieww.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 21.04.22.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation
import UIKit
import Lottie

struct TutorialPage: View {
    
    @State var image: String
    @State var title: String
    @State var describtion: String
    
    var body: some View {
        VStack {
            Image(image).resizable().scaledToFit().padding()
            Text(title).font(.title).padding()
            Text(describtion).font(.body).multilineTextAlignment(.center)
        }.padding()
    }
    
}

struct TutorialView : View {
    @StateObject var navigationModel: StateControlModel
    
    @State private var selectedPage = 0
    
    var body: some View {
        VStack {
            TabView(selection: $selectedPage) {
                TutorialPage(image: "Stars",
                             title: "Wait for clear skies",
                             describtion: "Stars like dark, clear nights. Make sure to be as far away from other light sources such as cities or highways as possible. Ideally wait for a clear night with a new moon.").tag(0)
                TutorialPage(image: "Tripod",
                             title: "Use a tripod",
                             describtion: "Make sure your phone doesn't move during shooting. Place it on a hard, steady surface or use a tripod.").tag(1)
                TutorialPage(image: "Patience",
                             title: "Be patient",
                             describtion: "StarLens allows you to take exposures of several minutes. The longer you allow you camera to collect light, the more details it can capture.").tag(2)
                TutorialPage(image: "auto-mask",
                             title: "Let the AI help you",
                             describtion: "SmartMask automatically recognizes the stars in your image, seperates foreground and background, and merges everything together. Only the movement of the stars is corrected, while the foreground stays rock solid.").tag(3)
            }
            //.disabled(true)
            .tabViewStyle(PageTabViewStyle())
            Button(selectedPage < 3 ? "Next" : "Done", action: {
                withAnimation{
                    if self.selectedPage < 3 {
                        selectedPage += 1
                    } else {
                        // Set default options for params on first use
                        DefaultsManager.setDefaultParameters()
                        
                        navigationModel.currentView = .camera
                        UserDefaults.standard.set(true, forKey: UserOption.completedTutorial.rawValue)
                    }
                }
                //navigationModel.currentView = .camera
            })
            .padding()
            .background(.white)
            .foregroundColor(.black)
            .clipShape(Capsule())
        }
        .background(.black)
        .foregroundColor(.white)
        
    }
    
    
}
