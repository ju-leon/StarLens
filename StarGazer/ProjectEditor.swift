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


enum EditOption : CaseIterable {
    class Instance {
        let identifier: String
        let icon: String
        let defaultValue: Double
        
        init(identifier: String, icon: String, defaultValue: Double) {
            self.identifier = identifier
            self.icon = icon
            self.defaultValue = defaultValue
        }
    }

    
    case starPop
    case contrast
    case brightness
    
    var instance: Instance {
        switch self {
        case .starPop:
            return Instance(identifier: "STAR_POP", icon: "moon.stars.fill", defaultValue: 0.0)
        case .contrast:
            return Instance(identifier: "CONTRAST", icon: "slider.horizontal.below.square.filled.and.square", defaultValue: 0.0)
        case .brightness:
            return Instance(identifier: "BRIGHTNESS", icon: "circle.lefthalf.filled", defaultValue: 1.0)
        }
    }
}

class ProjectEditor {
    let imageEditor: ImageEditor?
    let project: Project
    var photoStack: PhotoStack?
    var updatePreview = false;
    
    @Published var editOptions: [EditOption: Any?] = [:]
    
    private var editQueue: DispatchQueue = DispatchQueue(label: "StarStacker.editQueue")
    
    init(project: Project) {
        self.project = project

        let segmentation = ImageSegementation.segementImage(image: project.getProcessedPhoto())
        
        if (project.getProcessingComplete() && segmentation != nil) {
            imageEditor = ImageEditor.init(atPath: project.getUrl().appendingPathComponent(CHECKPOINT_FILE_NAME).path,
                                           numImages: Int32(project.getNumImages()),
                                           withMask: segmentation!)
            print("Success init")
        } else {
            imageEditor = nil
        }
        
        let projectEditOptions = project.getEditOptions()
        print("Project edit options:  \(projectEditOptions)")
        for option in EditOption.allCases {
            self.editOptions[option] = projectEditOptions[option.instance.identifier]
        }
    }

    func applyFilters(resultCallback: @escaping (UIImage) -> ()) {
        editQueue.async {
            if self.imageEditor != nil {
                while (self.updatePreview) {
                    autoreleasepool {
                        self.imageEditor!.setContrast(self.editOptions[.contrast] as! Double)
                        self.imageEditor!.setStarPop(self.editOptions[.starPop] as! Double)
                        self.imageEditor!.setBrightness(self.editOptions[.brightness] as! Double)
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
                let isRaw = photoURL.hasSuffix(".dng")
                
                let captureObject = CaptureObject(url: self.project.getUrl().appendingPathComponent(photoURL), time: Date(), metadata: self.project.getMetadata()!, isRaw: isRaw)
                let _ = self.photoStack?.add(
                        captureObject: captureObject,
                        statusUpdateCallback: statusUpdateCallback,
                        previewImageCallback: previewImageCallback
                )
            }

            self.photoStack?.saveStack(finished: true, statusUpdateCallback: onDone)
        }
    }

    func saveProject(resultCallback: @escaping (UIImage) -> ()) {
        editQueue.async {
            self.project.addEditOptions(editOptions: self.editOptions)
            let coverPhoto = self.imageEditor!.getFilteredImage()
            self.project.setCoverPhoto(image: coverPhoto)
            self.project.save()
            
            resultCallback(coverPhoto)
        }
    }
    
    func exportJPEG(onSucess: (()->())?, onFailed: (()->())?) {
        editQueue.async {
            let coverPhoto = self.imageEditor!.getFilteredImage()
            coverPhoto.saveToGallery(metadata: self.project.getMetadata(),
                                     onSuccess: onSucess,
                                     onFailed: onFailed)
        }
    }

}
