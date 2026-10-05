//
//  UserDefaultsManager.swift
//  TV Remote Casting
//
//  Created by iOS Developer on 16/09/2025.
//


import Foundation

class TR_UserDefaultManager {
    static let shared = TR_UserDefaultManager()
    private init() {}
    
    private let standard = UserDefaults.standard
    private let groupId = TR_AppStrings.groupID
    
    // MARK: - Standard UserDefaults
    func saveStandard<T>(_ value: T?, forKey key: String) {
        if let value = value {
            standard.set(value, forKey: key)
        } else {
            standard.removeObject(forKey: key)
        }
    }
    
    func getStandard<T>(forKey key: String) -> T? {
        return standard.object(forKey: key) as? T
    }
    
    // MARK: - Shared App Group Defaults
    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: groupId)
    }
    
    func saveShared<T>(_ value: T?, forKey key: String) {
        if let value = value {
            sharedDefaults?.set(value, forKey: key)
            sharedDefaults?.synchronize()
        } else {
            sharedDefaults?.removeObject(forKey: key)
        }
    }
    
    func getShared<T>(forKey key: String) -> T? {
        return sharedDefaults?.object(forKey: key) as? T
    }
}
