//
//  DebugController.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 06.05.22.
//

import Foundation

public let DEBUG_MODE = true

public enum DebugOption : String {
    /**
     Debug options
     */
    case shortExposure = "short-exposure"

    var defaultValue: Bool {
        switch self {
        case .shortExposure:
            return false
        }
    }
}

class DebugManager {
    
    static func isDebugEnabled() -> Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }
    
    /**
     Saving
     */
    static func saveBool(option: DebugOption, state: Bool) {
        UserDefaults.standard.set(state, forKey: option.rawValue)
    }
    
    static func saveInt(option: DebugOption, state: Int) {
        UserDefaults.standard.set(state, forKey: option.rawValue)
    }
    
    /**
     Loading
     */
    static func readBool(option: DebugOption) -> Bool {
        #if DEBUG
            return UserDefaults.standard.bool(forKey: option.rawValue)
        #else
            return UserDefaults.standard.bool(forKey: option.rawValue)
        #endif
    }

    static func readInt(option: DebugOption) -> Int {
        return UserDefaults.standard.integer(forKey: option.rawValue)
    }
    
}
