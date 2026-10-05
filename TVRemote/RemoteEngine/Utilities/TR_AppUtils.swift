//
//  TR_AppUtils.swift
//  TR_TV Remote
//
//  Created by iOS Developer on 26/08/2025.
//


import UIKit

class TR_AppUtils {
    
    static let instance = TR_AppUtils()
    
    var showAds : Bool = false
    var hardPaywall : Bool = false
    
    static var isHapticsEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: TR_RemoteConstants.enableHaptics)
        } set {
            UserDefaults.standard.set(newValue, forKey: TR_RemoteConstants.enableHaptics)
        }
    }
    
    func hapticFeedback() {
        if TR_AppUtils.isHapticsEnabled {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    func ConfigureUserDefaults() {
        if UserDefaults.standard.object(forKey: TR_RemoteConstants.enableHaptics) == nil {
            UserDefaults.standard.set(true, forKey: TR_RemoteConstants.enableHaptics)
        }
    }
    
    
    //MARK: - ********* USERDEFAULTS ***********
    
    //MARK: For Saving First Time Check
    func saveBool(key: String) {
        UserDefaults.standard.set(true, forKey: key)
    }

    func getBool(key: String) -> Bool {
        return UserDefaults.standard.bool(forKey: key)
    }
    
    //MARK: For Saving Firetv token Selected
    func saveString(key: String, value: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    func getString(key: String) -> String? {
        return UserDefaults.standard.string(forKey: key)
    }
    
    //MARK: - ********* FIRST LAUNCH ***********
    private let firstLaunchKey = "hasLaunchedBefore"
    
    /// Returns true only the first time the app launches
    func isFirstLaunch() -> Bool {
        let launched = UserDefaults.standard.bool(forKey: firstLaunchKey)
        if !launched {
            UserDefaults.standard.set(true, forKey: firstLaunchKey)
            return true
        }
        return false
    }
    
    
    //MARK: Links Opening
    func openLink(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

