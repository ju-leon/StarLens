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
    private var projectEditor: ProjectEditor?
    
    @Published var previewImage: UIImage = UIImage()
    @Published var inEditMode = false;
    @Published var isProcessed = true;
    
    private var subscriptions = Set<AnyCancellable>()

    func setProjectEditor(projectEditor: ProjectEditor) {
        self.projectEditor = projectEditor
        if (self.projectEditor?.imageEditor != nil) {
            self.isProcessed = true;
        }
    }
    
    func toggleEditMode() {
        self.inEditMode = !self.inEditMode
    }
    
    func computeEnhanceStar(value: Double) {
        self.previewImage = projectEditor!.enhanceStars(factor: value)
    }
    
    func setPreviewImage(image: UIImage) {
        self.previewImage = image
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
            Slider(value: $sliderValue, in: 0...1){
                sliding in
                if (!sliding) {
                    model.computeEnhanceStar(value: sliderValue)
                }
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
            
            if (model.isProcessed) {
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
                    //model.projectEditor?.stackPhotos(callback: nil)
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
                    Image(uiImage: model.previewImage)
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
                }.background(.black).foregroundColor(.white)
        }.onAppear(perform: {
            model.setProjectEditor(projectEditor: ProjectEditor(project: navigationModel.currentProject!))
            model.setPreviewImage(image: navigationModel.currentProject!.getCoverPhoto())
        })
    }
    
}
