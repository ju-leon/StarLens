//
//  NavigationView.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 28.12.21.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation
import UIKit
import CorePermissionsSwiftUI
import PermissionsSwiftUICamera
import PermissionsSwiftUIPhoto
import PermissionsSwiftUILocation

enum Views {
    case camera
    case projects
    case tutorial
}

final class StateControlModel : ObservableObject {
    @Published var currentView : Views = UserDefaults.standard.bool(forKey: UserOption.completedTutorial.rawValue) ? .camera : .tutorial
    @Published var currentProject : Project?
    
}

struct StateControlView : View {
    @StateObject var navigationModel = StateControlModel()
    
    @State var showModal = true
    
    var body: some View {
        switch navigationModel.currentView {
        case .tutorial:
            TutorialView(navigationModel: navigationModel).JMModal(showModal: $showModal, for: [.camera, .photo, .location], autoDismiss: true, onAppear: {}, onDisappear: {
                //self.navigationModel.currentView = .camera
            })
        case .camera:
            CameraView(navigationModel: navigationModel)
                .environment(\.colorScheme, .dark)
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
