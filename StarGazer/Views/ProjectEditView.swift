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
    @Published var inEditMode = false;
    
    @Published var projectEditor: ProjectEditor?
    
    private var subscriptions = Set<AnyCancellable>()
    
    func loadImageEditor(currentProject: Project) {
        do {
            self.projectEditor = try ProjectEditor(project: currentProject)
        } catch {
            print("Project not finished processing")
        }
    }
    
    func toggleEditMode() {
        self.inEditMode = !self.inEditMode
    }
}

struct EditOptionButton : View {
    @State var image: String
    
    var body: some View {
        Button(action: {
            
        }) {
            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: 60, height: 60, alignment: .center)
                .overlay(
                    Image(systemName: image).font(.system(size: 20))
                )
        }.padding().foregroundColor(.white)
    }
    
}

struct EditOptionsBar : View {
    @StateObject var model: ProjectEditModel
    
    @State private var showingDeleteDialog = false

    @State private var sliderValue: Double = 0
    
    var body: some View {
        VStack{
            Slider(value: $sliderValue, in: -100...100){
                sliding in
                print(sliding)
            }
            HStack(spacing: 0) {
                //Spacer()
                EditOptionButton(image: "sparkles")

                EditOptionButton(image: "wand.and.stars")
                
                EditOptionButton(image: "cloud.fog")
                Spacer()

                EditOptionButton(image: "checkmark")
            }
        }
    }
}

struct ActionOptionsBar : View {
    @StateObject var model: ProjectEditModel
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
            
            if (model.projectEditor != nil) {
                Button(action: {
                    withAnimation {
                        model.toggleEditMode()
                    }
                }) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Edit")
                    }.padding(10.0)
                    
                }.padding().foregroundColor(.white)
            } else {
                Button(action: {
                    print("Processing clicked")
                }) {
                    HStack {
                        Image(systemName: "gearshape.2.fill")
                        Text("Stack")
                    }.padding(10.0)
                    
                }.padding().foregroundColor(.white)
            }
            
            Spacer()
            
            Button(action: {
                print("Button action")
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("Save")
                }.padding(10.0)
                
            }.padding().foregroundColor(.white)

        }
    }
}


struct ProjectEditView : View {
    @StateObject var navigationModel: StateControlModel
    @StateObject var model = ProjectEditModel()
        
    private let twoColumnGrid = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        GeometryReader { reader in
                VStack {
                    
                    HStack {
                        Button(action: {
                            withAnimation {
                                self.navigationModel.currentView = .projects
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.backward")
                                Text("Back")
                            }.padding(10.0)
                            
                        }.padding().foregroundColor(.accentColor)

                        Spacer()
                    }
                    
                    Spacer()
                    Image(uiImage: navigationModel.currentProject!.getCoverPhoto())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipped()
                    Spacer()
                    
                    ZStack {
                        if (!model.inEditMode) {
                            ActionOptionsBar(model: model, navigationModel: navigationModel)
                        } else {
                            EditOptionsBar(model: model)
                        }
                    
                    }.transition(.slide)

                    /*
                     TODO: EXPORT; DELETE; PROCESS NOW; Maybe: SOME EDITING OPTIONS
                     */
                }
        }.onAppear(perform: {
            model.loadImageEditor(currentProject: navigationModel.currentProject!)
        })
    }
    
}
