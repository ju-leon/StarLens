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
import AlertToast
import Photos

enum ProjectEditMode: Int {
    case preview = 0
    case stacking = 1
    case editing = 2
}

class ProjectEditModel: ObservableObject {
    private var project: Project?

    @Published var numPictures = 0
    @Published var numProcessed = 0
    @Published var numFailed = 0

    @Published var previewImage: UIImage = UIImage()
    @Published var projectEditMode = ProjectEditMode.preview;
    @Published var isProcessed = false;

    @Published var activeEditMode: EditOption = .starPop

    @Published var showSaveSucessDialog = false
    @Published var showSaveFailedDialog = false
    
    @Published var loading = true
    
    @Published var showPermissionAlert = false
    
    public var projectEditor: ProjectEditor?
    
    private var subscriptions = Set<AnyCancellable>()
    
    private var interfaceQueue: DispatchQueue = DispatchQueue(label: "StarStacker.uiQueue")

    
    func getProject() -> Project? {
        return self.project
    }

    func setProjectEditor(project: Project?) {
        print("Init project editor")
        
        interfaceQueue.async {
            self.project = project
            self.projectEditor = ProjectEditor(project: project! )
            
            if (self.project!.getProcessingComplete()) {
                DispatchQueue.main.async {
                    self.isProcessed = true;
                }
            }
            
            let image = project!.getProcessedPhoto()
            
            DispatchQueue.main.async {
                self.previewImage = image
                self.loading = false
            }
        }
    }


    func toggleEditMode() {
        if (self.projectEditMode == .preview) {
            self.projectEditMode = .editing
        } else {
            self.loading = true
            self.projectEditor?.saveProject(resultCallback: {
                image  in
                DispatchQueue.main.async {
                    self.previewImage = image
                    self.loading = false
                }
            })
            self.projectEditMode = .preview
        }
    }

    func updatePreview(enabled: Bool) {
        if projectEditor != nil {
            projectEditor!.continousPreviewUpdate(enabled: enabled, resultCallback: {
                image in
                DispatchQueue.main.async {
                    self.previewImage = image
                }
            })
        }
    }

    func stackPhotos() {
        self.projectEditMode = .stacking
        self.numPictures = self.project!.getUnprocessedPhotoURLS().count
        projectEditor?.stackPhotos(
                statusUpdateCallback: { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .SUCCESS:
                            self.numProcessed += 1
                        case .FAILED:
                            self.numFailed += 1
                        case .INIT_FAILED:
                            //TODO Give feedback to the user that stacking is not possible
                            self.projectEditMode = .preview
                        }
                    }
                },
                previewImageCallback: { image in
                    DispatchQueue.main.async {
                        if image != nil {
                            self.previewImage = image!
                        }
                    }
                },
                onDone: { result in
                    //TODO Handle init failed
                    DispatchQueue.main.async {
                        self.isProcessed = true
                        self.projectEditMode = .preview
                    }
                })
    }
    

    func setPreviewImage(image: UIImage) {
        self.previewImage = image
    }
    
    func getInitalSliderValue() -> Double {
        if let value = project?.getEditOptions()[self.activeEditMode.instance.identifier] {
            return value as! Double
        } else {
            return 0
        }
    }
    
    func saveJPEG() {
        self.projectEditor?.exportJPEG(onSuccess: {
            DispatchQueue.main.async {
                self.showSaveSucessDialog = true
            }
        }, onFailed: {
            DispatchQueue.main.async {
                self.checkAndShowPermissionMessage()
                self.showSaveFailedDialog = true
            }
        })
    }
    
    func saveRAW() {
        self.projectEditor?.exportRAW(onSuccess: {
            DispatchQueue.main.async {
                self.showSaveSucessDialog = true
            }
        }, onFailed: {
            DispatchQueue.main.async {
                self.checkAndShowPermissionMessage()
                self.showSaveFailedDialog = true
            }
        })
    }
    
    func saveTimelapse() {
        self.projectEditor?.exportTimelapse(onSuccess: {
            DispatchQueue.main.async {
                self.showSaveSucessDialog = true
            }
        }, onFailed: {
            DispatchQueue.main.async {
                self.checkAndShowPermissionMessage()
                self.showSaveFailedDialog = true
            }
        })
    }
    
    func checkAndShowPermissionMessage() {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .restricted, .denied, .limited:
            self.showPermissionAlert = true
        default:
            return
        }
    }
    
    
}

struct EditOptionButton: View {
    @StateObject var model: ProjectEditModel
    @State var editMode: EditOption
    @State var onClick: () -> ()

    var body: some View {
        Button(action: {
            onClick()
        }) {
            Circle()
                .stroke(model.activeEditMode == editMode ? .blue : .white, lineWidth: model.activeEditMode == editMode ? 8 : 2)
                    .frame(width: 60, height: 60, alignment: .center)
                    .overlay(
                        Image(systemName: editMode.instance.icon).font(.system(size: 20))
                    )
        }.padding().foregroundColor(model.activeEditMode == editMode ? .accentColor : .white)
    }

}

struct FilterPreview: View {
    @State var uiImage: UIImage
    @State var title: String

    var body: some View {
        VStack {
            Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .frame(width: 60, height: 80, alignment: .center)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(.white, lineWidth: 2))

            RoundedRectangle(cornerRadius: 10)
                    .frame(height: 20, alignment: .center)
                    .foregroundColor(.white)
                    .overlay(
                            Text(title).font(.caption2).foregroundColor(.black)
                    )

        }.padding()

    }

}


struct EditOptionsBar: View {
    @StateObject var model: ProjectEditModel

    @State private var showingDeleteDialog = false

    @State private var sliderValue: Double = 0

    @State private var sliderRange = 0.0...1.0

    @State private var filterMenu = false

    var body: some View {
        VStack {
            if (!filterMenu) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        //Spacer()
                        
                        ForEach(EditOption.allCases , id: \.self) { mode in
                            EditOptionButton(model: model, editMode: mode, onClick: {
                                model.activeEditMode = mode
                                sliderValue = model.projectEditor!.editOptions[mode] as! Double
                            })
                        }
                    }
                }
                SlidingRuler(value: Binding(get: {sliderValue},
                                            set: {
                                                    self.sliderValue = $0
                                                    model.projectEditor!.editOptions[model.activeEditMode] = $0
                                                }),
                                            in: sliderRange,
                                            step: 0.5,
                                            tick: .fraction) {
                                        sliding in
                                        model.updatePreview(enabled: sliding)
                }.onAppear(perform: {
                    self.sliderValue = self.model.getInitalSliderValue()
                })
            } else {
                HStack {
                    Spacer()
                    FilterPreview(uiImage: model.previewImage, title: "ORIGINAL")
                    FilterPreview(uiImage: model.previewImage, title: "AI ENHANCED")
                    FilterPreview(uiImage: model.previewImage, title: "TRAILS")
                    Spacer()
                }
            }

            HStack {
                Button(action: {
                    withAnimation {
                        model.toggleEditMode()
                    }
                }) {
                    Text("Cancel")
                }.padding().foregroundColor(.red)

                Spacer()

                Button(action: {
                    withAnimation {
                        filterMenu = false
                    }
                }) {
                    Image(systemName: "dial.min.fill")
                }.padding().foregroundColor(filterMenu ? .white : .accentColor)

                Button(action: {
                    withAnimation {
                        filterMenu = true
                    }
                }) {
                    Image(systemName: "camera.filters")
                }.padding().foregroundColor(filterMenu ? .accentColor : .white)

                Spacer()

                Button(action: {
                    withAnimation {
                        
                        model.toggleEditMode()
                    }
                }) {
                    Text("Done")
                }.padding().foregroundColor(.accentColor)
            }

        }
    }
}

struct ActionOptionsBar: View {
    @StateObject var model: ProjectEditModel
    @StateObject var navigationModel: StateControlModel
    
    @State private var showingSaveDialog = false
    @State private var showingDeleteDialog = false

    let onDelete: () -> ()
    
    var body: some View {
        
        HStack {

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
                        primaryButton: .cancel(Text("Cancel")),
                        secondaryButton: .destructive(Text("Delete")) {
                            onDelete()
                        }
                )
            }


            Spacer()

            if model.isProcessed {
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
                    model.stackPhotos()
                }) {
                    HStack {
                        Image(systemName: "gearshape.2.fill")
                        Text("Stack")
                    }.padding(10.0)

                }.padding().foregroundColor(.white)
            }

            Spacer()

            
            Button(action: {
                showingSaveDialog = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("Save")
                }.padding(10.0)

            }
            .disabled(!model.isProcessed)
            .opacity(model.isProcessed ? 1.0 : 0.5)
            .padding()
            .foregroundColor(.white)
            .confirmationDialog(
                "Choose a format.",
                 isPresented: $showingSaveDialog,
                 titleVisibility: .visible
            ) {
                Button("Photo") {
                    self.model.saveJPEG()
                    print("Cliecked")
                }
                
                if model.getProject() != nil && model.getProject()!.getTimelapseComplete() {
                    Button("Timelapse") {
                        self.model.saveTimelapse()
                    }
                }
                Button("RAW Photo") {
                    self.model.saveRAW()
                    print("Saving raw")
                }
            }
        
        }
    }
}


struct ProjectEditView: View {
    @EnvironmentObject var viewModel: ProjectsModel
    @Environment(\.dismiss) var dismiss
    
    @StateObject var navigationModel: StateControlModel
    @StateObject var model = ProjectEditModel()
    
    let index: Int
    @State var project: Project

    private let twoColumnGrid = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        GeometryReader { reader in
            if (model.projectEditMode == .stacking) {
                ProcessingView(
                        numFailed: $model.numFailed,
                        numProcessed: $model.numProcessed,
                        numPictures: $model.numPictures,
                        photo: $model.previewImage,
                        cancelProcessing: {
                            //TODO: Cancel stacking..
                        }
                )
            } else {
                VStack {
                    Image(uiImage: model.previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipped()
                    Spacer()

                    ZStack {
                        if (model.projectEditMode == .preview) {
                            ActionOptionsBar(model: model, navigationModel: navigationModel, onDelete: {
                                print(self.index)
                                viewModel.projects.remove(at: self.index)
                                model.getProject()?.deleteProject()
                                dismiss()
                            })
                        } else if (model.projectEditMode == .editing) {
                            EditOptionsBar(model: model)
                        }

                    }.transition(.slide)
                }
                .background(.black)
                .toast(isPresenting: $model.showSaveSucessDialog) {
                    AlertToast(displayMode: .hud, type: .regular, title: "Saved!")
                }
                .toast(isPresenting: $model.showSaveFailedDialog) {
                    AlertToast(displayMode: .hud, type: .regular, title: "Saving failed!")
                }.toast(isPresenting: $model.loading) {
                    AlertToast(type: .loading)
                }.alert(isPresented: $model.showPermissionAlert) {
                    Alert(title: Text("Permission not granted"),
                          message: Text("Go to Settings>Privacy>Photos and allow StarLens to access your photos to be able to export to your photo gallery."),
                          dismissButton: .default(Text("OK"))
                    )
                }
            }
        }.onAppear(perform: {
            model.setProjectEditor(project: project)
        })
    }

}
