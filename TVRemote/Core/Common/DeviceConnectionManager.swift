//
//  DeviceConnectionManager.swift
//  TV Remote
//

import Foundation
import SwiftUI
import Combine
import AVKit
import ConnectSDK

// MARK: - TR_TV TR_Device Item Model
struct TVDeviceItem: Identifiable, Equatable {
    let id: String
    var name: String
    var ipAddress: String?
    var model: String
    var isAirPlay: Bool
    var isConnected: Bool
    var isConnecting: Bool
    var connectableDevice: ConnectableDevice?
    
    static func == (lhs: TVDeviceItem, rhs: TVDeviceItem) -> Bool {
        lhs.id == rhs.id && lhs.isConnected == rhs.isConnected && lhs.isConnecting == rhs.isConnecting
    }
}

// MARK: - Strict Smart TR_TV Validation (ScreenNova 100% Parity)
func isStrictlySmartTV(name: String, model: String? = nil, manufacturer: String? = nil) -> Bool {
    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else { return false }
    
    let lower = clean.lowercased().folding(options: .diacriticInsensitive, locale: .current)
    let lowerModel = (model ?? "").lowercased()
    let lowerMfr = (manufacturer ?? "").lowercased()
    
    // 1. FORBIDDEN: Raw UUID hashes / model hashes
    if lower.contains("amzn.dmgr:") || lower.contains("_pm-") || lower.contains("_dm-") {
        return false
    }
    if let regex = try? NSRegularExpression(pattern: "-[0-9a-f]{8,}", options: .caseInsensitive) {
        let matches = regex.matches(in: clean, options: [], range: NSRange(location: 0, length: clean.utf16.count))
        if !matches.isEmpty { return false }
    }
    
    // 2. FORBIDDEN: Computers, phones, tablets, office devices, network hardware, CCTV/NVR
    let forbiddenKeywords = [
        "macbook", "mac mini", "mac studio", "mac pro", "imac",
        "iphone", "ipad", "ipod", "apple watch", "airpods", "homepod",
        "laptop", "desktop", "computer", "windows pc", "printer",
        // Network switches, routers, modems, APs
        "switch", "router", "gateway", "modem", "access point", "gs724", "gs728", "gs752", "gs108", "gs110", "gs308", "gs316", "prosafe", "netgear", "tp-link", "d-link", "cisco", "ubiquiti", "mikrotik",
        // CCTV, NVR, DVR, Cameras
        "nvr", "dvr", "camera", "cctv", "hikvision", "dahua", "ds-7", "ds-8", "ds-9", "ds-2", "ipcam", "surveillance",
        // NAS / Storage servers
        "synology", "qnap", "truenas", "freenas", "storage"
    ]
    for forbidden in forbiddenKeywords {
        if lower.contains(forbidden) || lowerModel.contains(forbidden) || lowerMfr.contains(forbidden) {
            return false
        }
    }
    
    // Check prefix patterns for switches/NVRs
    if lower.hasPrefix("gs7") || lower.hasPrefix("gs1") || lower.hasPrefix("gs3") || lower.hasPrefix("gs5") || lower.hasPrefix("ds-") || lower.hasPrefix("dvr-") || lower.hasPrefix("nvr-") {
        return false
    }
    if lowerModel.hasPrefix("gs7") || lowerModel.hasPrefix("gs1") || lowerModel.hasPrefix("ds-") {
        return false
    }
    
    if lower.contains("'s mac") || lower.contains("’s mac") || lower.contains(" mac ") || lower.hasSuffix(" mac") {
        return false
    }
    
    // 3. ALLOW all other TVs (including custom names like "7seasol", "Living Room TR_TV", etc.)
    return true
}

// MARK: - DeviceConnectionManager (ScreenNova Exclusive ConnectSDK Engine)
@MainActor
final class DeviceConnectionManager: NSObject, ObservableObject, ConnectableDeviceDelegate {
    static let shared = DeviceConnectionManager()
    
    @Published var availableDevices: [TVDeviceItem] = []
    @Published var isAirPlayConnected: Bool = false
    @Published var isMirroringActive: Bool = false
    @Published var isScanning: Bool = false
    @Published var connectedDevice: TVDeviceItem? {
        didSet {
            if connectedDevice != nil {
                isAirPlayConnected = false
                TR_AirPlayManager.shared.isAirPlayConnected = false
            }
        }
    }
    
    var isActuallyConnected: Bool {
        // 1. AirPlay
        if isAirPlayConnected || TR_AirPlayManager.shared.isAirPlayConnected {
            return true
        }
        if let type = TR_RemoteViewModel.shared.connectedTVType, type == .AIRPLAY, TR_RemoteViewModel.shared.isConnectedSuccessfully {
            return true
        }
        
        // 2. Smart TR_TV
        if let type = TR_RemoteViewModel.shared.connectedTVType, type != .NONETV, type != .AIRPLAY, TR_RemoteViewModel.shared.isConnectedSuccessfully {
            return true
        }
        if let dev = connectedDevice, !dev.isAirPlay, dev.isConnected, dev.connectableDevice?.connected == true, TR_RemoteViewModel.shared.connectedTVType != nil, TR_RemoteViewModel.shared.connectedTVType != .NONETV {
            return true
        }
        
        return false
    }
    
    var isDeviceConnected: Bool {
        return isActuallyConnected
    }
    
    override init() {
        super.init()
        setupAirPlayRouteObserver()
        setupMirroringObserver()
        startScanning()
    }
    
    private func setupMirroringObserver() {
        checkMirroringStatus()
        NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkMirroringStatus()
            }
        }
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkMirroringStatus()
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkMirroringStatus()
            }
        }
    }
    
    func checkMirroringStatus() {
        let isCaptured = UIScreen.main.isCaptured
        var isBroadcasting = false
        if let defaults = UserDefaults(suiteName: TR_AppStrings.groupID) {
            let isBroadcastingRaw = defaults.bool(forKey: "isBroadcasting")
            let mode = defaults.string(forKey: "broadcastMode") ?? ""
            isBroadcasting = isBroadcastingRaw && (mode == "mirroring" || mode.isEmpty)
        }
        let isMirrorActive = isCaptured || isBroadcasting
        if !isMirrorActive {
            TR_MirroringServerManager.shared.isMirroringActive = false
        }
        self.isMirroringActive = isMirrorActive
    }
    
    private func setupAirPlayRouteObserver() {
        checkAirPlayStatus()
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkAirPlayStatus()
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkAirPlayStatus()
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkAirPlayStatus()
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkAirPlayStatus()
            }
        }
    }
    
    func checkAirPlayStatus() {
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        let hasAirPlayOutput = currentRoute.outputs.contains(where: { $0.portType == .airPlay })
        let hasMirroredScreen = UIScreen.screens.contains(where: { $0 != UIScreen.main && $0.mirrored != nil })
        let isAirPlay = hasAirPlayOutput || hasMirroredScreen
        
        self.isAirPlayConnected = isAirPlay
        TR_AirPlayManager.shared.isAirPlayConnected = isAirPlay
        if let airplayOutput = currentRoute.outputs.first(where: { $0.portType == .airPlay }) {
            TR_AirPlayManager.shared.connectedDeviceName = airplayOutput.portName
        } else if hasMirroredScreen {
            TR_AirPlayManager.shared.connectedDeviceName = "AirPlay Display"
        } else {
            TR_AirPlayManager.shared.connectedDeviceName = ""
        }
        
        if isAirPlay {
            self.connectedDevice = nil
        }
    }
    
    func startScanning() {
        isScanning = true
        TR_RemoteViewModel.shared.configureDiscoveryIfNeeded()
        TR_RemoteViewModel.shared.startDiscovery()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.isScanning = false
        }
    }
    
    func scanDevices() {
        isScanning = true
        TR_RemoteViewModel.shared.configureDiscoveryIfNeeded()
        TR_RemoteViewModel.shared.startDiscovery()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isScanning = false
        }
    }
    
    // MARK: - Sync Discovered Devices from TR_RemoteViewModel (ConnectSDK Clean XML Names)
    func syncDevice(from device: ConnectableDevice) {
        let cleanName = (device.friendlyName ?? device.modelName ?? "Smart TR_TV").trimmingCharacters(in: .whitespacesAndNewlines)
        let model = device.modelName ?? "Smart TR_TV"
        let mfr = device.serviceDescription?.manufacturer ?? ""
        
        guard isStrictlySmartTV(name: cleanName, model: model, manufacturer: mfr) else { return }
        let ip = device.address
        
        if let idx = availableDevices.firstIndex(where: { ($0.ipAddress != nil && $0.ipAddress == ip) || $0.name.lowercased() == cleanName.lowercased() }) {
            availableDevices[idx].name = cleanName
            availableDevices[idx].connectableDevice = device
            availableDevices[idx].model = model
            if let ip = ip { availableDevices[idx].ipAddress = ip }
        } else {
            let id = "\(ip ?? cleanName)_\(availableDevices.count)"
            let item = TVDeviceItem(
                id: id,
                name: cleanName,
                ipAddress: ip,
                model: model,
                isAirPlay: false,
                isConnected: false,
                isConnecting: false,
                connectableDevice: device
            )
            availableDevices.append(item)
            print("✨ DeviceConnectionManager Synced Clean TR_TV: \(cleanName) (\(ip ?? ""))")
        }
    }
    
    func removeDevice(address: String?) {
        guard let ip = address else { return }
        availableDevices.removeAll(where: { $0.ipAddress == ip })
        if connectedDevice?.ipAddress == ip {
            connectedDevice = nil
        }
    }
    
    // MARK: - Connect & Disconnect
    func connect(to device: TVDeviceItem) {
        guard let index = availableDevices.firstIndex(where: { $0.id == device.id }) else { return }
        
        if availableDevices[index].isConnected {
            disconnect(device: device)
            return
        }
        
        for i in availableDevices.indices {
            availableDevices[i].isConnecting = false
            availableDevices[i].isConnected = false
        }
        availableDevices[index].isConnecting = true
        isAirPlayConnected = false
        
        if let connectable = device.connectableDevice {
            TR_RemoteViewModel.shared.connect(to: connectable)
        } else {
            if let match = TR_RemoteViewModel.shared.discoveredDevices.first(where: { $0.address == device.ipAddress || $0.friendlyName?.lowercased() == device.name.lowercased() }) {
                TR_RemoteViewModel.shared.connect(to: match)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if let targetIdx = self.availableDevices.firstIndex(where: { $0.id == device.id }) {
                        self.availableDevices[targetIdx].isConnecting = false
                    }
                }
            }
        }
    }
    
    func disconnect(device: TVDeviceItem) {
        if let connectable = device.connectableDevice {
            connectable.disconnect()
        }
        TR_RemoteViewModel.shared.disconnectTV()
        if let idx = availableDevices.firstIndex(where: { $0.id == device.id }) {
            availableDevices[idx].isConnected = false
            availableDevices[idx].isConnecting = false
        }
        if connectedDevice?.id == device.id {
            connectedDevice = nil
        }
    }
    
    nonisolated func setConnectedDeviceManually(address: String?, name: String, type: TR_TelevisionType) {
        Task { @MainActor in
            if let idx = self.availableDevices.firstIndex(where: { ($0.ipAddress != nil && $0.ipAddress == address) || $0.name.lowercased() == name.lowercased() }) {
                for i in self.availableDevices.indices {
                    self.availableDevices[i].isConnected = false
                    self.availableDevices[i].isConnecting = false
                }
                self.availableDevices[idx].isConnected = true
                self.connectedDevice = self.availableDevices[idx]
            } else {
                let item = TVDeviceItem(
                    id: "\(address ?? name)_\(self.availableDevices.count)",
                    name: name,
                    ipAddress: address,
                    model: type.rawValue,
                    isAirPlay: false,
                    isConnected: true,
                    isConnecting: false,
                    connectableDevice: nil
                )
                self.availableDevices.append(item)
                self.connectedDevice = item
            }
        }
    }

    func toggleAirPlay() {
        if isAirPlayConnected {
            isAirPlayConnected = false
        } else {
            for i in availableDevices.indices {
                availableDevices[i].isConnected = false
                availableDevices[i].isConnecting = false
            }
            isAirPlayConnected = true
            connectedDevice = nil
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    // MARK: - ConnectableDeviceDelegate
    nonisolated func connectableDeviceReady(_ device: ConnectableDevice!) {
        guard let device = device else { return }
        Task { @MainActor in
            guard TR_RemoteViewModel.shared.connectedTVType != nil && TR_RemoteViewModel.shared.isConnectedSuccessfully && !TR_RemoteViewModel.shared.showPinDialog else {
                print("DeviceConnectionManager ignoring connectableDeviceReady until pairing is confirmed")
                return
            }
            
            let name = device.friendlyName ?? device.modelName ?? ""
            let address = device.address
            if let idx = self.availableDevices.firstIndex(where: { $0.ipAddress == address || $0.name.lowercased() == name.lowercased() }) {
                self.availableDevices[idx].isConnecting = false
                self.availableDevices[idx].isConnected = true
                self.connectedDevice = self.availableDevices[idx]
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            
            // Sync with TR_DeviceConnectivityViewModel
            TR_DeviceConnectivityViewModel.shared.connectSDKDiscoveryModel.selectedLGDevice = device
            TR_DeviceConnectivityViewModel.shared.isDeviceConnected = true
            if let type = TR_RemoteViewModel.shared.connectedTVType ?? TR_RemoteViewModel.shared.identifyTVType(from: device) {
                TR_DeviceConnectivityViewModel.shared.setConnectedTv(tvType: type)
            } else {
                TR_DeviceConnectivityViewModel.shared.setConnectedTv(tvType: .ANDROID)
            }
        }
    }
    
    nonisolated func connectableDeviceDisconnected(_ device: ConnectableDevice!, withError error: (any Error)!) {
        guard let device = device else { return }
        Task { @MainActor in
            let name = device.friendlyName ?? device.modelName ?? ""
            let address = device.address
            if let idx = self.availableDevices.firstIndex(where: { $0.ipAddress == address || $0.name.lowercased() == name.lowercased() }) {
                self.availableDevices[idx].isConnecting = false
                self.availableDevices[idx].isConnected = false
            }
            if self.connectedDevice?.ipAddress == address || self.connectedDevice?.name.lowercased() == name.lowercased() {
                self.connectedDevice = nil
                TR_DeviceConnectivityViewModel.shared.isDeviceConnected = false
                TR_DeviceConnectivityViewModel.shared.connectedTvType = nil
            }
        }
    }
    
    nonisolated func connectableDevice(_ device: ConnectableDevice!, service: DeviceService!, pairingRequiredOfType pairingType: Int32, withData pairingData: Any!) {
        Task { @MainActor in
            print("DeviceConnectionManager ConnectSDK pairingRequiredOfType: \(pairingType)")
            if pairingType == 2 /* DeviceServicePairingTypePinCode */ {
                let name = (device?.friendlyName ?? device?.modelName ?? "").lowercased()
                let isSamsung = name.contains("samsung") || TR_RemoteViewModel.shared.selectedTVType == .SAMSUNG || TR_RemoteViewModel.shared.connectedTVType == .SAMSUNG
                if !isSamsung {
                    TR_RemoteViewModel.shared.showProgress = false
                    TR_RemoteViewModel.shared.showPinDialog = true
                } else {
                    TR_RemoteViewModel.shared.showPinDialog = false
                }
            } else {
                print("ℹ️ FirstScreen/Confirmation pairing required on TR_TV screen")
            }
        }
    }
}
