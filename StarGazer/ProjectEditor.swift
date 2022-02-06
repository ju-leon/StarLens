//
//  ProjectEditor.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 05.02.22.
//

import Foundation
import CoreLocation

enum ProjectEditorErrors : Error {
    case initError
}

class ProjectEditor {
    let imageEditor: ImageEditor?
    let project: Project
    var photoStack: PhotoStack?
    
    init(project: Project) {
        self.project = project

        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: project.getUrl(), includingPropertiesForKeys: nil)
            print(directoryContents)
        } catch {
            print("Couldnt list")
        }
        
        if (project.getProcessingComplete()) {
            imageEditor = ImageEditor.init(project.getUrl().path, Int32(project.getNumImages()))
            print("Success init")
        } else {
            imageEditor = nil
        }
    }
    
    func changeEditMode() {
        imageEditor?.finishSingleEdit()
    }
    
    func enhanceStars(factor: Double) -> UIImage {
        return imageEditor!.enhanceStars(factor)
    }
    
    func changeBrightness(factor: Double) -> UIImage {
        return imageEditor!.changeBrightness(factor)
    }

    func changeContrast(factor: Double) -> UIImage {
        return imageEditor!.changeContrast(factor)
    }
    
    func stackPhotos(callback: ((UIImage?) -> ())?) {
        //TODO: Use mask if available
        //TODO: Save location in project
        print("Trying to stack photos...")
        
        photoStack = PhotoStack(mask: false, align: true, enhance: false, location: CLLocationCoordinate2D(latitude: 0, longitude: 0))
        
        for photoURL in project.getUnprocessedPhotoURLS() {
            print(photoURL)
            //TODO: REMOVE!!!
            let tempPhotoUrl = URL(fileURLWithPath: photoURL).lastPathComponent
            
            let captureObject = CaptureObject(url: project.getUrl().appendingPathComponent(tempPhotoUrl), time: Date(), metadata: project.getMetadata()!)
            let image = photoStack?.add(captureObject: captureObject, statusUpdateCallback: {
            _ in
                print("Done with one photo")
            })
            callback?(image)
        }
    }
    
    
}
