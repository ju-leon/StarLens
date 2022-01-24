//
//  NavigationView.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 28.12.21.
//

import SwiftUI
import Combine
import AVFoundation
import UIKit

enum Views {
    case camera
    case processing
    case projects
}

final class NavigationModel : ObservableObject {
    @Published var currentView : Views = Views.camera
    
}

struct NavigationView : View {
    @StateObject var navigationModel = NavigationModel()
    
    var body: some View {
        switch navigationModel.currentView {
            case .camera:
            CameraView(navigationModel: navigationModel)
            case .processing:
                ResultView(navigationModel: navigationModel)
            case .projects:
            ProjectsView(navigationModel: navigationModel).transition(.move(edge: .bottom))
        
        }
    }
    
}

struct NavigationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView()
    }
}
