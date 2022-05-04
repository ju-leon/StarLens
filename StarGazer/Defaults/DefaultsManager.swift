//
//  DefaultsManager.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 04.05.22.
//

import Foundation

class DefaultsManager {
    /**
     Saving
     */
    static func saveBool(option: UserOption, state: Bool) {
        UserDefaults.standard.set(state, forKey: option.rawValue)
    }
    
    static func saveInt(option: UserOption, state: Int) {
        UserDefaults.standard.set(state, forKey: option.rawValue)
    }
    
    /**
     Loading
     */
    static func readBool(option: UserOption) -> Bool {
        return UserDefaults.standard.bool(forKey: option.rawValue)
    }

    static func readInt(option: UserOption) -> Int {
        return UserDefaults.standard.integer(forKey: option.rawValue)
    }

}
