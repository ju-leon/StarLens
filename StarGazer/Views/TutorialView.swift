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

struct TutorialView : View {
    @StateObject var navigationModel: StateControlModel
    
    @State private var selectedPage = 0
    
    var body: some View {
        TimedLottieView(name: "StarLensWelcome",  loopMode: .autoReverse, currentPage: $selectedPage)
        .onChange(of: selectedPage, perform: {
            value in
            print("...")
        })
        TabView(selection: $selectedPage) {
            Text("Wait for clear skys").tag(0)
            Text("Use a tripod").tag(1)
            Text("Hit the shutter button").tag(2)
        }
        .disabled(true)
        .tabViewStyle(PageTabViewStyle())
        Button(selectedPage < 2 ? "Next" : "Done", action: {
            withAnimation{
                if self.selectedPage < 2 {
                    selectedPage += 1
                    print("Page now \(selectedPage)")
                } else {
                    navigationModel.currentView = .camera
                    UserDefaults.standard.set(true, forKey: UserOption.completedTutorial.rawValue)
                }
            }
            //navigationModel.currentView = .camera
        })
        
    }
    
    
}
