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
    var updatePreview = false;
    
    @Published var starPop: Double = 0.0
    @Published var contrast: Double = 1.0
    @Published var brightness: Double = 0.0
    
    private var editQueue: DispatchQueue = DispatchQueue(label: "StarStacker.editQueue")
    
    init(project: Project) {
        self.project = project

        if (project.getProcessingComplete()) {
            imageEditor = ImageEditor.init(atPath: project.getUrl().appendingPathComponent(CHECKPOINT_FILE_NAME).path, numImages: Int32(project.getNumImages()))
            print("Success init")
        } else {
            imageEditor = nil
        }
    }

    func applyFilters(resultCallback: @escaping (UIImage) -> ()) {
        editQueue.async {
            if self.imageEditor != nil {
                while (self.updatePreview) {
                    autoreleasepool {
                        self.imageEditor!.setContrast(self.contrast)
                        self.imageEditor!.setStarPop(self.starPop)
                        self.imageEditor!.setBrightness(self.brightness)
                        resultCallback(self.imageEditor!.getFilteredImagePreview())
                    }
                }
            }
        }
    }
    
    func continousPreviewUpdate(enabled: Bool, resultCallback: @escaping (UIImage) -> ()) {
        self.updatePreview = enabled
        
        print(enabled)
        
        if (enabled) {
            applyFilters(resultCallback: resultCallback)
        }
    }

    func stackPhotos(statusUpdateCallback: @escaping (PhotoStackingResult) -> (),
                     previewImageCallback: ((UIImage?) -> ())?,
                     onDone: @escaping (PhotoStackingResult) -> ()) {
        print("Trying to stack photos...")
        editQueue.async {
            self.photoStack = PhotoStack(project: self.project)

            for photoURL in self.project.getUnprocessedPhotoURLS() {
                let captureObject = CaptureObject(url: self.project.getUrl().appendingPathComponent(photoURL), time: Date(), metadata: self.project.getMetadata()!)
                let _ = self.photoStack?.add(
                        captureObject: captureObject,
                        statusUpdateCallback: statusUpdateCallback,
                        previewImageCallback: previewImageCallback
                )
            }

            self.photoStack?.saveStack(finished: true, statusUpdateCallback: onDone)
        }
    }


}
