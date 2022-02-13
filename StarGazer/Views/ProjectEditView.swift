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

    @Published var activeEditMode: EditMode = .starPop

    public var projectEditor: ProjectEditor?
    
    private var subscriptions = Set<AnyCancellable>()

    func setProjectEditor(project: Project?) {
        print("Init project editor")
        self.project = project
        self.projectEditor = ProjectEditor(project: project! )
        
        if (self.project!.getProcessingComplete()) {
            self.isProcessed = true;
        }
    }

    func toggleEditMode() {
        if (self.projectEditMode == .preview) {
            self.projectEditMode = .editing
        } else {
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
                        self.projectEditMode = .preview
                    }
                })
    }

    func setPreviewImage(image: UIImage) {
        self.previewImage = image
    }
}

struct EditOptionButton: View {
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


enum EditMode: String {
    case starPop = "sparkles"
    case brightness = "wand.and.stars"
    case contrast = "cloud.fog"
    case sky = "moon"
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
                        EditOptionButton(model: model, editMode: .starPop, onClick: {
                            model.activeEditMode = .starPop
                            sliderValue = model.projectEditor!.starPop
                        })

                        EditOptionButton(model: model, editMode: .brightness, onClick: {
                            model.activeEditMode = .brightness
                            sliderValue = model.projectEditor!.brightness
                        })

                        EditOptionButton(model: model, editMode: .contrast, onClick: {
                            model.activeEditMode = .contrast
                            sliderValue = model.projectEditor!.contrast
                        })

                        EditOptionButton(model: model, editMode: .sky, onClick: {
                            model.activeEditMode = .sky
                            sliderValue = 0.5
                        })
                    }
                }
                SlidingRuler(value: Binding(get: {sliderValue},
                                           set: {
                                                self.sliderValue = $0
                                                switch model.activeEditMode {
                                                   case .brightness:
                                                       model.projectEditor!.brightness = $0
                                                   case .starPop:
                                                       model.projectEditor!.starPop = $0
                                                   case .contrast:
                                                       model.projectEditor!.contrast = $0
                                                   case .sky:
                                                       print("Doing nothing lol \($0)")
                                                }})
                                            , in: sliderRange,
                                            step: 0.5,
                                            tick: .fraction) {
                                        sliding in
                                        model.updatePreview(enabled: sliding)
                                    }
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
                        secondaryButton: .destructive(Text("Delete")) {
                            navigationModel.currentProject?.deleteProject()
                            withAnimation {
                                self.navigationModel.currentView = .projects
                            }
                        }
                )
            }


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


struct ProjectEditView: View {
    @StateObject var navigationModel: StateControlModel
    @StateObject var model = ProjectEditModel()

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

                    if (model.projectEditMode == .preview) {
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
                    }

                    Spacer()
                    Image(uiImage: model.previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipped()
                    Spacer()

                    ZStack {
                        if (model.projectEditMode == .preview) {
                            ActionOptionsBar(model: model, navigationModel: navigationModel)
                        } else if (model.projectEditMode == .editing) {
                            EditOptionsBar(model: model)
                        }

                    }.transition(.slide)
                }
            }
        }.onAppear(perform: {
            model.setProjectEditor(project: navigationModel.currentProject)
            model.setPreviewImage(image: navigationModel.currentProject!.getCoverPhoto())
        })
    }

}
