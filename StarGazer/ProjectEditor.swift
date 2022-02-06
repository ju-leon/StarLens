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

        let maxedPhoto = project.getMaxedPhoto()
        let averagedPhoto = project.getAveragedPhoto()
        let previewPhoto = project.getCoverPhoto()

        if (project.processedMatsAvailable()) {
            imageEditor = ImageEditor.init(
                //TODO: Change to averaged photo
                stackedImage: previewPhoto,
                maxedPhoto!
            )
            print("Success init")
        } else {
            imageEditor = nil
        }
    }
    
    func enhanceStars(factor: Double) -> UIImage {
        return imageEditor!.enhanceStars(factor)
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
