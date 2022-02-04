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


struct EditOptionsBar : View {
    @StateObject var navigationModel: StateControlModel

    @State private var showingDeleteDialog = false

    var body: some View {
        HStack(spacing: 0) {
            
            Button(action: {
                showingDeleteDialog = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete")
                }.padding(10.0)
                
            }.padding().foregroundColor(.red).alert(isPresented: $showingDeleteDialog) {
                Alert(title: Text("Delete project"),
                      message: Text("This will delete the project and all it's files. This action cannot be undone.\nAre you sure?"),
                      primaryButton: .default(Text("Cancel")),
                      secondaryButton: .destructive(Text("Delete")){
                        navigationModel.currentProject?.deleteProject()
                        withAnimation {
                            self.navigationModel.currentView = .projects
                        }
                    }
            )}
            
            
            Spacer()
            
            Button(action: {
                print("Button action")
            }) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Edit")
                }.padding(10.0)
                
            }.padding().foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                print("Button action")
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("Export")
                }.padding(10.0)
                
            }.padding().foregroundColor(.white)

        }
    }
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
                    
                    EditOptionsBar(navigationModel: navigationModel)
                    /*
                     TODO: EXPORT; DELETE; PROCESS NOW; Maybe: SOME EDITING OPTIONS
                     */
                }
        }
    }
    
}
