//
//  ProjectEditor.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 05.02.22.
//

import Foundation

enum ProjectEditorErrors : Error {
    case initError
}

class ProjectEditor {
    let imageEditor: ImageEditor
    let project: Project
    
    init(project: Project) throws {
        self.project = project
        let maxedPhoto = project.getMaxedPhoto()
        let averagedPhoto = project.getAveragedPhoto()
                
        if (maxedPhoto != nil && averagedPhoto != nil) {
            imageEditor = ImageEditor.init(
                stackedImage: averagedPhoto!,
                maxedPhoto!
            )
            print("Success init")
        } else {
            throw ProjectEditorErrors.initError
        }
    }
    
    func enhanceStars(factor: Double) -> UIImage {
        return imageEditor.enhanceStars(factor)
    }
    
    
}
