//
//  ProjectEditView.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 28.01.22.
//
import SwiftUI
import Combine
import AVFoundation
import UIKit

class ProjectEditModel : ObservableObject {
    
    private var subscriptions = Set<AnyCancellable>()

    var navigation: StateControlModel?
    
    init() {}
}


struct ProjectEditView : View {
    @StateObject var model = ProjectEditModel()
    
    @StateObject var navigationModel: StateControlModel
    
    private let twoColumnGrid = [GridItem(.flexible()), GridItem(.flexible())]

    
    
    var body: some View {
        GeometryReader { reader in
                VStack {
                    Spacer()
                    Image(uiImage: navigationModel.currentProject!.getCoverPhoto())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipped()
                    Spacer()
                    
                    /*
                     TODO: EXPORT; DELETE; PROCESS NOW; Maybe: SOME EDITING OPTIONS
                     */
                }
        }
    }
    
}
