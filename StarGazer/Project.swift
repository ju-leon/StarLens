//
//  Project.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 16.01.22.
//

import Foundation

let PLIST_FILE_NAME = "data.xml"
let PREVIEW_FILE_NAME = "preview.png"
let PROCESSED_FILE_NAME = "processed.png"

let MAXED_FILE_NAME = "imageMaxed.png"
let AVERAGED_FILE_NAME = "imageAveraged.png"
let CHECKPOINT_FILE_NAME = "checkpoint.stargazer"

enum ProjectKeys: String {
    case captureStart = "captureStart"
    case captureEnd = "captureEnd"
    case images = "images"
    case metadata = "metadata"
    case unprocessedPhotoURLs = "photos"
    case processingComplete = "processingComplete"
    case numImages = "numImages"
}

enum ProjectError: Error {
    case invalidProject
}

class Project: NSObject {
    private var url: URL

    private var metadata: [String: Any]?
    private var captureStart: Date
    private var captureEnd: Date?

    private var numImages: Int = 0

    private var unprocessedPhotoURLs: [String] = []

    private var processingComplete = false

    private var coverPhoto: UIImage?

    init(url: URL, captureStart: Date) {
        self.url = url
        self.captureStart = captureStart

    }

    init(url: URL) throws {
        self.url = url

        let plist = Dictionary<String, Any>.loadFromPath(url: url.appendingPathComponent(PLIST_FILE_NAME))

        if plist == nil {
            throw ProjectError.invalidProject
        }

        self.captureStart = plist![ProjectKeys.captureStart.rawValue] as! Date
        self.captureEnd = plist![ProjectKeys.captureEnd.rawValue] as? Date

        self.metadata = plist![ProjectKeys.metadata.rawValue] as? [String: Any]

        self.unprocessedPhotoURLs = plist![ProjectKeys.unprocessedPhotoURLs.rawValue] as! [String]

        self.processingComplete = plist![ProjectKeys.processingComplete.rawValue] as! Bool

        self.numImages = plist![ProjectKeys.numImages.rawValue] as! Int

        if FileManager.default.fileExists(atPath: url.appendingPathComponent(PREVIEW_FILE_NAME).path) {
            self.coverPhoto = UIImage(contentsOfFile: url.appendingPathComponent(PREVIEW_FILE_NAME).path)
        }

    }

    deinit {
        //TODO: SAVE
    }

    public func processedMatsAvailable() -> Bool {
        if !FileManager.default.fileExists(atPath: url.appendingPathComponent("combined.xml").path) {
            return false
        }

        if !FileManager.default.fileExists(atPath: url.appendingPathComponent("maxed.xml").path) {
            return false
        }

        if !FileManager.default.fileExists(atPath: url.appendingPathComponent("stacked.xml").path) {
            return false
        }

        return true
    }

    public func getAveragedPhoto() -> UIImage? {
        if FileManager.default.fileExists(atPath: url.appendingPathComponent(AVERAGED_FILE_NAME).path) {
            return UIImage(contentsOfFile: url.appendingPathComponent(AVERAGED_FILE_NAME).path)
        } else {
            return nil
        }
    }

    public func getMaxedPhoto() -> UIImage? {
        if FileManager.default.fileExists(atPath: url.appendingPathComponent(MAXED_FILE_NAME).path) {
            return UIImage(contentsOfFile: url.appendingPathComponent(MAXED_FILE_NAME).path)
        } else {
            return nil
        }
    }

    public func getCoverPhoto() -> UIImage {
        if (self.coverPhoto != nil) {
            return self.coverPhoto!
        } else {
            return UIImage()
        }
    }

    public func setCoverPhoto(image: UIImage) {
        self.coverPhoto = image
    }

    public func getUnprocessedPhotoURLS() -> [String] {
        return self.unprocessedPhotoURLs
    }

    public func setCaptureEnd(date: Date) {
        self.captureEnd = date
    }

    public func setMetadata(data: [String: Any]?) {
        if self.metadata == nil {
            self.metadata = data
        }
    }

    public func getCaptureStart() -> Date {
        return self.captureStart
    }

    public func getCaptureEnd() -> Date? {
        return self.captureEnd
    }

    public func getMetadata() -> [String: Any]? {
        return self.metadata
    }

    public func doneProcessing() {
        self.processingComplete = true
    }

    public func addUnprocessedPhotoURL(url: URL) {
        self.unprocessedPhotoURLs.append(url.lastPathComponent)
    }

    public func removeUnprocessedPhotoURL(url: URL) {
        if (self.unprocessedPhotoURLs.contains(where: { $0 == url.lastPathComponent })) {
            self.unprocessedPhotoURLs.remove(at: self.unprocessedPhotoURLs.firstIndex(where: { $0 == url.lastPathComponent })!)
        }
    }

    public func getUrl() -> URL {
        return self.url
    }

    public func getProcessingComplete() -> Bool {
        if FileManager.default.fileExists(atPath: self.url.appendingPathComponent(CHECKPOINT_FILE_NAME).path) {
            return self.processingComplete
        }
        return false
    }

    public func setNumImages(_ num: Int) {
        self.numImages = num
    }

    public func getNumImages() -> Int {
        return self.numImages
    }

    public func save() {
        if self.coverPhoto != nil {
            let resized = ImageResizer.resize(image: self.coverPhoto!, targetWidth: 100.0)
            resized.saveImageToPNG(url: self.url.appendingPathComponent(PREVIEW_FILE_NAME))
        }

        var plist: [String: Any] = [:]

        plist[ProjectKeys.captureStart.rawValue] = self.captureStart
        plist[ProjectKeys.captureEnd.rawValue] = self.captureEnd
        plist[ProjectKeys.unprocessedPhotoURLs.rawValue] = self.unprocessedPhotoURLs
        plist[ProjectKeys.metadata.rawValue] = self.metadata
        plist[ProjectKeys.processingComplete.rawValue] = self.processingComplete
        plist[ProjectKeys.numImages.rawValue] = self.numImages

        Project.savePlist(url: self.url.appendingPathComponent(PLIST_FILE_NAME), projectData: plist)
    }

    private static func savePlist(url: URL, projectData: [String: Any]) {
        projectData.writeToPath(url)
        print("SAVED!")
    }

    private static func loadPlist(url: URL) -> [String: Any]? {
        do {
            let data = try Data(contentsOf: url)
            guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
                return nil
            }
            return plist as [String: Any]
        } catch {
            return nil
        }
    }

    public func deleteProject() {
        do {
            print(url.path)
            try FileManager.default.removeItem(atPath: url.path)
        } catch {
            print("Delete failed")
        }
    }
}

extension Dictionary {
    func writeToPath(_ url: URL) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: self,
                    requiringSecureCoding: true)
            do {
                try data.write(to: url)
            } catch {
                print("Failed to write dictionary data to disk.")
            }
        } catch {
            print("Failed to archive dictionary.")
        }
    }

    static func loadFromPath(url: URL) -> [String: Any?]? {
        do {
            let data = try Data(contentsOf: url)//6
            let object = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data)
            return object as? [String: Any?]
        } catch {
            return nil
        }
    }
}
