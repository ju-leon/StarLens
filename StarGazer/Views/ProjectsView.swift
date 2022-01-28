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
        VStack {
            Image(uiImage: project.getCoverPhoto())
                .resizable()
                .background(.black)
                .cornerRadius(10)
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200)           
            Text(project.getCaptureStart().formatted()).font(.subheadline)
            Spacer()
        }
    }
}


struct ProjectsView : View {
    @StateObject var model = ProjectsModel()
    
    @StateObject var navigationModel: StateControlModel
    
    private let twoColumnGrid = [GridItem(.flexible()), GridItem(.flexible())]

    
    
    var body: some View {
        GeometryReader { reader in
            ScrollView {
                HStack {
                    
                    Text("Projects")
                        .font(.title)
                        .foregroundColor(.black)
                        .padding()
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            self.navigationModel.currentView = .camera
                        }
                    }, label:{
                        Image(systemName: "xmark.circle.fill").font(.system(size: 30)).foregroundColor(.gray).padding()
                    })
                }
                LazyVGrid(columns: twoColumnGrid) {
                    ForEach(model.projects.indices) {
                        index in
                        Button(action: {
                            self.navigationModel.currentProject = model.projects[index]
                            withAnimation {
                                self.navigationModel.currentView = .edit
                            }
                        }, label:{
                            ProjectCard(project: model.projects[index])
                        })
                    }
                }
                .padding()
                .foregroundColor(.black)
            }
            .background(.white)
        }
    }
    
}
