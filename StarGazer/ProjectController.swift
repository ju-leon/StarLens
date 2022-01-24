//
//  ProjectController.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 16.01.22.
//

import Foundation

public class ProjectController: NSObject {
    
    @Published var projects : [Project] = []
    
    public override init() {
        super.init()
        
        let projectDirs = ProjectController.listProjects()
        self.projects = []
        for projectPath in projectDirs {
            self.projects.append(Project(url: projectPath))
        }
    }
    
    
    private static func listProjects() -> [URL] {
        let tempDir = FileManager.default.temporaryDirectory
        
        do {
            let dir = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            return dir
            print(dir)
        } catch {
            print("Failed")
            return []
        }
    }
    
    
}
