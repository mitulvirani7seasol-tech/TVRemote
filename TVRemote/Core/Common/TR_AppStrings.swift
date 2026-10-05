//
//  TR_AppStrings.swift
//  TV Remote
//

import Foundation
import SwiftUI

struct TR_AppStrings {
    static let appName = "TV Remote"
    
    static let groupID = "group.com.screenMirroring.app1"
    static let appExtensionPackageName = "com.screenMirroring.app1.TVRemoteBroadcast"
    
    static let broadcastStartedNotification = "broadcastStartedNotification"
    
    static let deviceIPKey = "ConnectedDeviceIP"
    static let serverUrlKey = "serverURL"
    
    static let pexelWebKey = "EvP7eQQFXRRDKLyLVBv9M8DWrxhgYL7gc6V4FuE5xkfpGyVRgvQNwyns"
    
    static let channelNamespace = "urn:x-cast:com.big.screen.channel"
    static let kCustomReceiverAppID = "B6208013"
    
    static let rotateMirror = "rotateMirror"
    
    static func fetchBroadcastStatus() -> Bool {
        UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") ?? false
    }
}

struct TR_SessionKeys {
    static var language = "language"
    static var intro1 = "intro1"
    static var intro2 = "intro2"
    static var intro3 = "intro3"
    static var intro4 = "intro4"
    static let appLanguage = "appLanguage"
    static var isPro = "isPro"
    static var interAdId = "interAdId"
    static var afterClick = "afterClick"
    static let isHapticEnabled = "isHapticEnabled"
    static var isPasswordOn = "isPasswordOn"
    static var isPasswordSet = "isPasswordSet"
    static let isHomeOpened = "isHomeOpened"
}

enum TR_Products: String, CaseIterable {
    case Motion_Week = "Week_Cast"
    case Motion_Month = "Month_Cast"
    case Motion_Year = "Year_Cast"
    case Motion_LifeTime = "Life_Time_Cast"
}

class TR_AppSession {
    static let shared = TR_AppSession()
    var hasShownPremium = false
    var hasShownRate = false
}

