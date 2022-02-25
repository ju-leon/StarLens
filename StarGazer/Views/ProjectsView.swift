//
//  ProjectsView.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 16.01.22.
//
import SwiftUI
import Combine
import AVFoundation
import UIKit

class ProjectsModel : ObservableObject {
    private let projectController = ProjectController()
    
    @Published var projects : [Project] = []
    
    private var subscriptions = Set<AnyCancellable>()

    var navigation: StateControlModel?
    
    init() {
        projectController.$projects.sink { [weak self] (val) in
                    self?.projects = val
                }
                .store(in: &self.subscriptions)
    }
}

struct ProjectCard: View {
    @State var project : Project

    var body: some View {
        ZStack {
            Image(uiImage: project.getCoverPhoto())
                .resizable()
                .background(.black)
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200)
            LinearGradient(colors: [.clear, .clear, .clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
            VStack{
                Spacer()
                HStack {
                    if (project.getProcessingComplete()) {
                        Circle().fill(.green).frame(width: 10, height: 10, alignment: .center).padding()
                    } else {
                        Circle().fill(.yellow).frame(width: 10, height: 10, alignment: .center).padding()
                    }
                    Text(project.getCaptureStart().formatted()).font(.subheadline).foregroundColor(.white)
                    Spacer()
                }

            }
        }
        .cornerRadius(10)

    }
}


struct ProjectsView : View {
    @EnvironmentObject var model: ProjectsModel
    
    @StateObject var navigationModel: StateControlModel
    
    private let twoColumnGrid = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationView{
            ScrollView {
                LazyVGrid(columns: twoColumnGrid) {
                    ForEach(Array(model.projects.enumerated()), id:\.element.id) {
                        index, item in
                        NavigationLink(destination: ProjectEditView(navigationModel: self.navigationModel, index: index, project: model.projects[index]), label: {
                            ProjectCard(project: model.projects[index])
                        })
                    }.onDelete(perform: delete)
                }
                .padding()
                .navigationTitle("Projects")
                .navigationBarItems(trailing:
                    Button(action: {
                        withAnimation {
                            self.navigationModel.currentView = .camera
                        }
                    }, label:{
                        Text("Done")
//                        Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundColor(.gray).padding()
                    }).padding()
                )
            }
        }
    }
    
    func delete(at offsets: IndexSet) {
        print("WWas here")
    }
    
}
