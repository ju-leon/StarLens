//
//  UserOptions.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 27.02.22.
//

import Foundation


enum UserOption : String {
    case imageQuality = "image-quality"
    case rawOption = "raw-option"
    case completedTutorial = "tutorial-done"
    case recordLocation = "record-location"
    /**
     Debug options
     */
    case isDebugEnabled = "debug"
    case isMaskEnabled = "mask"
    case shortExposure = "short-exposure"
    case rawEnabled = "raw-enabled"
}
