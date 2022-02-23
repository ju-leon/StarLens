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
    case projects
}

final class StateControlModel : ObservableObject {
    @Published var currentView : Views = Views.camera
    
    @Published var currentProject : Project?
    
}

struct StateControlView : View {
    @StateObject var navigationModel = StateControlModel()
    
    var body: some View {
        switch navigationModel.currentView {
        case .camera:
            CameraView(navigationModel: navigationModel).environment(\.colorScheme, .dark)
        case .projects:
            ProjectsView(navigationModel: navigationModel)
                .environmentObject(ProjectsModel())
                .transition(.move(edge: .bottom))
                .environment(\.colorScheme, .dark)
        }
    }
    
}

struct StateControlView_Previews: PreviewProvider {
    static var previews: some View {
        StateControlView()
    }
}
