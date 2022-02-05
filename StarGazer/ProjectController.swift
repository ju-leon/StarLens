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
            do {
                try self.projects.append(Project(url: projectPath))
            } catch {
            }
        }

        self.projects.sort { (project1, project2) -> Bool in
            return project1.getCaptureStart() > project2.getCaptureStart()
        }
    }
    
    
    private static func listProjects() -> [URL] {
        let tempDir = FileManager.default.temporaryDirectory
        
        do {
            let dir = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            return dir
        } catch {
            print("Failed")
            return []
        }
    }
    
    
}
