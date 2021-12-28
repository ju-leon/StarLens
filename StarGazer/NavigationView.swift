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
        }
    }
    
}

struct NavigationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView()
    }
}
