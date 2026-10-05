//
//  TR_DeviceType.swift
//  TV Remote Casting
//
//  Created by Ronik Hirpara on 11/10/25.
//

import Foundation
import SwiftUI
import ConnectSDK
import GoogleCast


enum TR_TelevisionType: String, CaseIterable, Codable {
    case ANDROID
    case LG
    case AIRPLAY
    case NONETV
    case ROKU
    case SAMSUNG
    case FIRE
}

var selectedTvType : TR_TelevisionType = .NONETV

enum TR_DeviceType:Hashable {
    case lg(ConnectableDevice)
    case cast(GCKDevice)
    
    var name: String {
        switch self {
        case .lg(let device): return device.friendlyName ?? "Unknown LG TR_TV"
        case .cast(let device): return device.friendlyName ?? "Unknown Android TR_TV"
        }
    }
    
    var id: String {
        switch self {
        case .lg(let device): return device.address ?? UUID().uuidString
        case .cast(let device): return device.deviceID
        }
    }
}

extension TR_DeviceType: Equatable {
    static func == (lhs: TR_DeviceType, rhs: TR_DeviceType) -> Bool {
        switch (lhs, rhs) {
        case (.lg(let d1), .lg(let d2)):
            return d1.address == d2.address

        case (.cast(let d1), .cast(let d2)):
            return d1.deviceID == d2.deviceID

        default:
            return false
        }
    }
}
