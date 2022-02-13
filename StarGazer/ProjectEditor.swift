//
//  ProjectEditor.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 05.02.22.
//

import Foundation
import CoreLocation
import UIKit

enum ProjectEditorErrors: Error {
    case initError
}

class ProjectEditor {
    let imageEditor: ImageEditor?
    let project: Project
    var photoStack: PhotoStack?

    init(project: Project) {
        self.project = project

        if (project.getProcessingComplete()) {
            imageEditor = ImageEditor.init(atPath: project.getUrl().appendingPathComponent(CHECKPOINT_FILE_NAME).path, numImages: Int32(project.getNumImages()))
            print("Success init")
        } else {
            imageEditor = nil
        }
    }

    func applyFilters(starPop: Double, contrast: Double, brightness: Double, resultCallback: @escaping (UIImage) -> ()) {
        if imageEditor != nil {
            imageEditor!.setContrast(contrast)
            imageEditor!.setStarPop(0)
            imageEditor!.setBrightness(brightness)
            DispatchQueue.main.async {
                resultCallback(self.imageEditor!.getFilteredImagePreview())
            }
        }
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
            }, previewImageCallback: callback)
        }
    }


}
