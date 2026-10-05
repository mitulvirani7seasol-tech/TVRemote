//
//  SmartTVDiscoveryScanner.swift
//  TV Remote
//

import Foundation
import Network
import Combine
import ConnectSDK

/// Discovered TR_TV info model
public struct DiscoveredSmartTV: Identifiable, Equatable {
    public let id: String
    public var name: String
    public var ipAddress: String?
    public var model: String?
    public var isAirPlay: Bool = false
    public var protocolType: String
    
    public static func == (lhs: DiscoveredSmartTV, rhs: DiscoveredSmartTV) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}

/// Ultra-Fast Multi-Protocol Smart TR_TV Scanner for Real iOS Devices
@MainActor
final class SmartTVDiscoveryScanner: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    static let shared = SmartTVDiscoveryScanner()
    
    @Published var discoveredTVs: [DiscoveredSmartTV] = []
    @Published var isSearching: Bool = false
    
    private var netServiceBrowsers: [NetServiceBrowser] = []
    private var resolvingServices: [NetService] = []
    private var nwBrowsers: [NWBrowser] = []
    private var searchTimer: Timer?
    
    // Core Bonjour services for Smart TVs
    private let screenMirroringBonjourTypes = [
        "_googlecast._tcp",          // Chromecast, Android TR_TV, Google TR_TV, MiTV
        "_webos._tcp",               // LG WebOS TVs
        "_webostv._tcp",             // LG WebOS TVs
        "_webos-second-screen._tcp", // LG WebOS TVs
        "_dial._tcp",                // Samsung, Sony, Philips DIAL
        "_amzn-wplay._tcp",          // Fire TR_TV
        "_roku-rcp._tcp"             // Roku TVs
    ]
    
    override init() {
        super.init()
        startDiscovery()
    }
    
    func startDiscovery() {
        stopDiscovery()
        isSearching = true
        
        // 1. Start NetService Browsers for Smart TR_TV services
        for type in screenMirroringBonjourTypes {
            let browser = NetServiceBrowser()
            browser.delegate = self
            browser.searchForServices(ofType: type, inDomain: "local.")
            netServiceBrowsers.append(browser)
        }
        
        // 2. Start NWBrowser in parallel
        for serviceType in screenMirroringBonjourTypes {
            let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: nil)
            let params = NWParameters()
            params.includePeerToPeer = true
            
            let browser = NWBrowser(for: descriptor, using: params)
            browser.browseResultsChangedHandler = { [weak self] results, changes in
                Task { @MainActor in
                    self?.handleNWBrowserResults(results, serviceType: serviceType)
                }
            }
            browser.start(queue: .main)
            nwBrowsers.append(browser)
        }
        
        searchTimer?.invalidate()
        searchTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.isSearching = false
            }
        }
    }
    
    func stopDiscovery() {
        for browser in netServiceBrowsers {
            browser.stop()
        }
        netServiceBrowsers.removeAll()
        
        for service in resolvingServices {
            service.stop()
        }
        resolvingServices.removeAll()
        
        for browser in nwBrowsers {
            browser.cancel()
        }
        nwBrowsers.removeAll()
        
        searchTimer?.invalidate()
        searchTimer = nil
        isSearching = false
    }
    
    // MARK: - NetServiceBrowserDelegate
    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        Task { @MainActor in
            service.delegate = self
            resolvingServices.append(service)
            service.resolve(withTimeout: 4.0)
        }
    }
    
    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        Task { @MainActor in
            let name = service.name
            self.discoveredTVs.removeAll(where: { $0.name == name })
        }
    }
    
    // MARK: - NetServiceDelegate
    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        Task { @MainActor in
            self.handleResolvedService(sender)
        }
    }
    
    private func handleResolvedService(_ service: NetService) {
        let rawName = service.name
        let ip = getIPAddress(from: service.addresses)
        let protocolType = service.type
        
        // Extract Google Cast friendly name from TXT record if present
        var friendlyName: String? = nil
        if let txtData = service.txtRecordData() {
            let dict = NetService.dictionary(fromTXTRecord: txtData)
            if let fnData = dict["fn"], let fnStr = String(data: fnData, encoding: .utf8), !fnStr.isEmpty {
                friendlyName = fnStr
            }
        }
        
        if let fn = friendlyName, isStrictlySmartTV(name: fn) {
            registerDiscoveredTV(name: fn, ip: ip, protocolType: protocolType)
            return
        }
        
        if isStrictlySmartTV(name: rawName) {
            registerDiscoveredTV(name: cleanTVName(rawName), ip: ip, protocolType: protocolType)
        }
    }
    
    private func registerDiscoveredTV(name: String, ip: String?, protocolType: String) {
        let clean = cleanTVName(name)
        guard !clean.isEmpty, isStrictlySmartTV(name: clean) else { return }
        
        let tv = DiscoveredSmartTV(
            id: "\(clean)_\(protocolType)",
            name: clean,
            ipAddress: ip,
            model: "Smart TR_TV",
            isAirPlay: false,
            protocolType: protocolType
        )
        
        if !discoveredTVs.contains(where: { $0.name == tv.name }) {
            discoveredTVs.append(tv)
        }
        
        // Instant Bridge: Add to TR_RemoteViewModel.shared.discoveredDevices and DeviceConnectionManager
        if let ipAddress = ip, !ipAddress.isEmpty {
            if let desc = ServiceDescription(address: ipAddress, uuid: "bonjour-\(clean)-\(ipAddress)") {
                desc.friendlyName = clean
                desc.modelName = "Smart TR_TV"
                desc.serviceId = "DIALService"
                if let connectable = ConnectableDevice(description: desc) {
                    if !TR_RemoteViewModel.shared.discoveredDevices.contains(where: { $0.address == ipAddress || $0.friendlyName == clean }) {
                        TR_RemoteViewModel.shared.discoveredDevices.append(connectable)
                        DeviceConnectionManager.shared.syncDevice(from: connectable)
                        print("⚡ Instantly added Bonjour TR_TV to TR_RemoteViewModel: \(clean) (\(ipAddress))")
                    }
                }
            }
        }
    }
    
    private func handleNWBrowserResults(_ results: Set<NWBrowser.Result>, serviceType: String) {
        for result in results {
            switch result.endpoint {
            case .service(let name, _, _, _):
                guard isStrictlySmartTV(name: name) else { continue }
                let cleanedName = cleanTVName(name)
                registerDiscoveredTV(name: cleanedName, ip: nil, protocolType: serviceType)
            default:
                break
            }
        }
    }
    
    private func cleanTVName(_ name: String) -> String {
        var clean = name
        if let regex = try? NSRegularExpression(pattern: "\\s*\\([0-9]+\\)$", options: []) {
            clean = regex.stringByReplacingMatches(in: clean, options: [], range: NSRange(location: 0, length: clean.utf16.count), withTemplate: "")
        }
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getIPAddress(from dataAddresses: [Data]?) -> String? {
        guard let addresses = dataAddresses else { return nil }
        for data in addresses {
            var storage = sockaddr_storage()
            data.withUnsafeBytes { rawBuffer in
                if rawBuffer.count >= MemoryLayout<sockaddr_storage>.size {
                    memcpy(&storage, rawBuffer.baseAddress, MemoryLayout<sockaddr_storage>.size)
                }
            }
            if storage.ss_family == sa_family_t(AF_INET) {
                var addr = sockaddr_in()
                data.withUnsafeBytes { rawBuffer in
                    if rawBuffer.count >= MemoryLayout<sockaddr_in>.size {
                        memcpy(&addr, rawBuffer.baseAddress, MemoryLayout<sockaddr_in>.size)
                    }
                }
                if let ipStr = inet_ntoa(addr.sin_addr) {
                    return String(cString: ipStr)
                }
            }
        }
        return nil
    }
}
