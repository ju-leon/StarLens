//
//  ProjectController.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 16.01.22.
//

import Foundation

let PROJECTS_PREVIEW_IMAGE = "preview.jpg"

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
    
    static var documentsUrl: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    public static func storePreviewImage(image: UIImage) {
        let fileURL = documentsUrl.appendingPathComponent(PREVIEW_FILE_NAME)
        if let imageData = image.jpegData(compressionQuality: 1.0) {
           try? imageData.write(to: fileURL, options: .atomic)
        }
    }
    
    public static func loadPreviewImage() -> UIImage? {
        let fileURL = documentsUrl.appendingPathComponent(PREVIEW_FILE_NAME)
        do {
            let imageData = try Data(contentsOf: fileURL)
            return UIImage(data: imageData)
        } catch {
            print("Error loading image : \(error)")
        }
        return nil
    }
    
}
