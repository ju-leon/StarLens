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

    func stackPhotos(statusUpdateCallback: @escaping (PhotoStackingResult) -> (),
                     previewImageCallback: ((UIImage?) -> ())?,
                     onDone: @escaping (PhotoStackingResult) -> ()) {
        print("Trying to stack photos...")

        photoStack = PhotoStack(project: project)

        for photoURL in project.getUnprocessedPhotoURLS() {
            print(photoURL)

            let captureObject = CaptureObject(url: project.getUrl().appendingPathComponent(photoURL), time: Date(), metadata: project.getMetadata()!)
            let image = photoStack?.add(
                    captureObject: captureObject,
                    statusUpdateCallback: statusUpdateCallback,
                    previewImageCallback: previewImageCallback
            )
        }

        photoStack?.saveStack(finished: true, statusUpdateCallback: onDone)
    }


}
