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
import SlidingRuler

class ProjectEditModel : ObservableObject {
    private var projectEditor: ProjectEditor?
    private var project: Project?
    
    @Published var previewImage: UIImage = UIImage()
    @Published var inEditMode = false;
    @Published var isProcessed = false;
    
    @Published var activeEditMode: EditMode = .starEnahnce
    
    private var subscriptions = Set<AnyCancellable>()

    func setProjectEditor(project: Project?) {
        print("Init project editor")
        self.project = project
        self.projectEditor = ProjectEditor(project: project!)
        
        if (self.project!.getProcessingComplete()) {
            self.isProcessed = true;
        }
    }
    
    func toggleEditMode() {
        self.inEditMode = !self.inEditMode
    }
    
    func changeEditMode() {
        self.projectEditor!.changeEditMode()
    }
    
    func computeEnhanceStar(value: Double) {
        self.previewImage = projectEditor!.enhanceStars(factor: value)
    }

    func computeChangeBrightness(value: Double) {
        self.previewImage = projectEditor!.changeBrightness(factor: value)
    }
    
    func computeChangeContrast(value: Double) {
        self.previewImage = projectEditor!.changeContrast(factor: value)
    }
    
    func computeEnhanceSky(value: Double) {
        self.previewImage = projectEditor!.enhanceSky(factor: value)
    }
    
    func setPreviewImage(image: UIImage) {
        self.previewImage = image
    }
}

struct EditOptionButton : View {
    @StateObject var model: ProjectEditModel
    @State var editMode: EditMode
    @State var onClick: () -> ()
    
    var body: some View {
        Button(action: {
            onClick()
        }) {
            Circle()
                .stroke(model.activeEditMode == editMode ? .blue : .white, lineWidth: model.activeEditMode == editMode ? 8 : 2)
                .frame(width: 60, height: 60, alignment: .center)
                .overlay(
                    Image(systemName: editMode.rawValue).font(.system(size: 20))
                )
        }.padding().foregroundColor(model.activeEditMode == editMode ? .accentColor : .white)
    }
    
}

struct EditFinishBar: View {
    var body: some View {
        HStack {
            Button(action: {
                
            }) {
                Text("Cancel")
            }.padding().foregroundColor(.red)
            
            Spacer()
            
            Button(action: {
            }) {
                Text("Done")
            }.padding().foregroundColor(.accentColor)
        }
    }
}

enum EditMode : String {
    case starEnahnce = "sparkles"
    case brightness = "wand.and.stars"
    case contrast = "cloud.fog"
    case finish = "checkmark"
    case sky = "moon"
}

struct EditOptionsBar : View {
    @StateObject var model: ProjectEditModel
    
    @State private var showingDeleteDialog = false

    @State private var sliderValue: Double = 0
    
    @State private var sliderRange = 0.0...1.0
    
    var body: some View {
        VStack{
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    //Spacer()
                    EditOptionButton(model: model, editMode: .starEnahnce, onClick: {
                        model.changeEditMode()
                        model.activeEditMode = .starEnahnce
                        sliderRange = 0...1
                        sliderValue = 0
                    })
                    
                    EditOptionButton(model: model, editMode: .brightness, onClick: {
                        model.changeEditMode()
                        model.activeEditMode = .brightness
                        sliderRange = -100...100
                        sliderValue = 0
                    })
                    
                    EditOptionButton(model: model, editMode: .contrast, onClick: {
                        model.changeEditMode()
                        model.activeEditMode = .contrast
                        sliderRange = 0.2...1.8
                        sliderValue = 1
                    })
                    
                    EditOptionButton(model: model, editMode: .sky, onClick: {
                        model.changeEditMode()
                        model.activeEditMode = .sky
                        sliderRange = 100...270
                        sliderValue = 150
                    })

                    EditOptionButton(model: model, editMode: .finish, onClick: {
                        model.activeEditMode = .finish
                    })
                }
            }
            SlidingRuler(value: $sliderValue, in: sliderRange){
                sliding in
                if (!sliding) {
                    switch model.activeEditMode {
                    case .brightness:
                        print("brightness \(sliderValue)")
                        model.computeChangeBrightness(value: sliderValue)
                    case .starEnahnce:
                        print("starenhance \(sliderValue)")
                        model.computeEnhanceStar(value: sliderValue)
                    case .contrast:
                        print("constrast \(sliderValue)")
                        model.computeChangeContrast(value: sliderValue)
                    case .finish:
                        print("Finish")
                    case .sky:
                        model.computeEnhanceSky(value: sliderValue)
                    }
                    
                }
            }
            
            EditFinishBar()
            
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
            model.setProjectEditor(project: navigationModel.currentProject)
            model.setPreviewImage(image: navigationModel.currentProject!.getCoverPhoto())
        })
    }
    
}
