//
//  UserOptions.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 27.02.22.
//

import Foundation

public let TIMER_STATES = [0, 5, 10, 30]

enum UserOption : String {
    case imageQuality = "image-quality"
    case rawOption = "raw-option"
    case completedTutorial = "tutorial-done"
    case recordLocation = "record-location"
    case timerValue = "timer-value"
    case isMaskEnabled = "mask"
    case rawEnabled = "raw-enabled"
}
