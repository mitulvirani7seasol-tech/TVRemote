//
//  TR_ConnectedTVs.swift
//  TR_TV Remote
//
//  Created by iOS Developer on 25/08/2025.
//


import Foundation

class TR_ConnectedTVs {
    static let shared = TR_ConnectedTVs()
    
    private let userDefaultsKey = "KnownConnectedTVIPs"
    private var knownIPs: Set<String> = []

    init() {
        if let saved = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] {
            knownIPs = Set(saved)
        } else if let legacy = UserDefaults.standard.array(forKey: "TVIPs") as? [String] {
            knownIPs = Set(legacy)
        }
    }

    func saveIP(_ ip: String) {
        guard !ip.isEmpty else { return }
        knownIPs.insert(ip)
        UserDefaults.standard.set(Array(knownIPs), forKey: userDefaultsKey)
    }

    func isIPKnown(_ ip: String) -> Bool {
        guard !ip.isEmpty else { return false }
        return knownIPs.contains(ip)
    }

    func removeIP(_ ip: String) {
        guard !ip.isEmpty else { return }
        knownIPs.remove(ip)
        UserDefaults.standard.set(Array(knownIPs), forKey: userDefaultsKey)
    }

    func removeAll() {
        knownIPs.removeAll()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
