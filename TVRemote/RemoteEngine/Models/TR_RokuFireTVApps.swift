//
//  RokuFireApps.swift
//  TR_TV Remote
//
//  Created by iOS Developer on 18/01/2026.
//


import Foundation

struct TR_RokuFireTVApps: Identifiable, Hashable, Codable {
    let id: UUID
    let appID: String
    let name: String
    let imageName: String
    
    init(appID: String, name: String, imageName: String) {
        self.id = UUID()
        self.appID = appID
        self.name = name
        self.imageName = imageName
    }
}
