//
//  TR_AndroidSamsungTVApps.swift
//  TR_TV Remote
//
//  Created by iOS Developer on 18/01/2026.
//


import Foundation

struct TR_AndroidSamsungTVApps: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let imageName: String
    let url: String
    let tvApp: TR_TVApp
    
    init(name: String, imageName: String, url: String, tvApp: TR_TVApp) {
        self.id = UUID()
        self.name = name
        self.imageName = imageName
        self.url = url
        self.tvApp = tvApp
    }
}
