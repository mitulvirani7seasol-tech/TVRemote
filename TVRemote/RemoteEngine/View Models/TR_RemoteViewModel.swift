//
//  TVRemoteViewModel.swift
//  TR_TV Remote
//
//  Created by iOS Developer on 26/08/2025.
//

import Foundation
import ConnectSDK
import Combine
import Network
import GoogleCast

class TR_RemoteViewModel: NSObject, ObservableObject {
    static let shared = TR_RemoteViewModel()
    // MARK: - Published Properties
    @Published var connectedTVType: TR_TelevisionType?
    @Published var selectedTVType: TR_TelevisionType?
    @Published var deviceName: String?
    @Published var showSearchingSheet = false
    @Published var showDisconnectPopup = false
    @Published var showSearchBar = false
    @Published var showPinDialog = false
    @Published var showProgress = false
    @Published var showCountdownAlert = false
    @Published var discoveredDevices: [ConnectableDevice] = []
    @Published var pinCode = ""
    @Published var showAirPlayAlert = false
    @Published var connectingDeviceAddress: String?
    @Published var isLoadingApps: Bool = false
    
    private var isDiscoveryConfigured = false
    @Published var isSwitchingDevice = false
    private var pendingDevice: ConnectableDevice?
    var commonViewModel: TR_DeviceConnectivityViewModel? {
        TR_DeviceConnectivityViewModel.shared
    }
    // MARK: - Managers
    var currentTVManager: AnyObject?
    private var discoveryManager: DiscoveryManager
    private var cancellables: Set<AnyCancellable> = []
    var lgPorts: [AppInfo] {
        guard let lgManager = currentTVManager as? TR_LGControlManager else { return [] }
        return lgManager.availableApps
    }
    let lgTVApps: [TR_LGTVApps] = [
        .lgChannels,
        .netflix,
        .prime,
        .disney,
        .appleTV,
        .zeeFive,
        .youtube,
        .lgGamingPortal,
        .apps,
        .homeOffice,
        .music,
        .homeHub,
        .learning,
        .webBrowser,
        .mediaPlayer
    ]
    
    var samsungTVApps: [TR_TVApp] {
        guard let samsungManager = currentTVManager as? TR_SamsungControlManager else {
            return []
        }
        return samsungManager.installedApps
    }
    
    var samsungPorts: [TR_TVApp] {
        guard let samsungManager = currentTVManager as? TR_SamsungControlManager else { return [] }
        return samsungManager.availablePorts
    }
    
    
    @Published var incorrectPinTrigger: UUID = UUID()
    @Published var isConnectedSuccessfully: Bool = false {
        didSet {
            if isConnectedSuccessfully {
                DispatchQueue.main.async {
                    TR_AirPlayManager.shared.isAirPlayConnected = false
                    DeviceConnectionManager.shared.isAirPlayConnected = false
                }
            }
        }
    }
    @Published var showAllowInTVSettingsAlert: Bool = false
    
    // MARK: - Port Mappings
    private let tvPorts: [TR_TelevisionType: [Int]] = [
        .SAMSUNG: [8001, 8002],
        .LG: [3000, 3001],
        .ROKU: [8060],
        .FIRE: [8009, 8080],
        .ANDROID: [6467, 6466]
    ]
    
    override init() {
        discoveryManager = DiscoveryManager.shared()
        super.init()
        configureDiscoveryIfNeeded()
        startDiscovery()
    }
    
    // MARK: - Discovery Setup (Smart TVs Only: Excludes Mac computers)
    func configureDiscoveryIfNeeded() {
        
        guard !isDiscoveryConfigured else { return }
        
        print("📡 Configuring DiscoveryManager (Smart TVs Only)")
        
        discoveryManager.stopDiscovery()
        discoveryManager.delegate = self
        discoveryManager.pairingLevel = DeviceServicePairingLevelOn
        
//        discoveryManager.registerDeviceService(RokuService.self, withDiscovery: SSDPDiscoveryProvider.self)
//        discoveryManager.registerDeviceService(WebOSTVService.self, withDiscovery: SSDPDiscoveryProvider.self)
//        discoveryManager.registerDeviceService(DLNAService.self, withDiscovery: SSDPDiscoveryProvider.self)
//        discoveryManager.registerDeviceService(DIALService.self, withDiscovery: SSDPDiscoveryProvider.self)
//        discoveryManager.registerDeviceService(NetcastTVService.self, withDiscovery: SSDPDiscoveryProvider.self)
        
        discoveryManager.registerDeviceService(RokuService.self, withDiscovery: SSDPDiscoveryProvider.self)
        discoveryManager.registerDeviceService(WebOSTVService.self, withDiscovery: SSDPDiscoveryProvider.self)
        discoveryManager.registerDeviceService(DLNAService.self, withDiscovery: SSDPDiscoveryProvider.self)
        discoveryManager.registerDeviceService(DIALService.self, withDiscovery: SSDPDiscoveryProvider.self)
        
        isDiscoveryConfigured = true
    }
    
    func startDiscovery() {
        print("📡 Starting Multi-Protocol Discovery (SSDP + Bonjour + GoogleCast)")
        configureDiscoveryIfNeeded()
        discoveryManager.startDiscovery()
        DispatchQueue.main.async {
            SmartTVDiscoveryScanner.shared.startDiscovery()
            TR_TVStreamingViewModel.shared.startDiscovery()
        }
    }
    
    func rescanNow() {
        print("⚡ Forcing immediate Active Multi-Protocol Rescan")
        configureDiscoveryIfNeeded()
        discoveryManager.startDiscovery()
        DispatchQueue.main.async {
            SmartTVDiscoveryScanner.shared.startDiscovery()
            TR_TVStreamingViewModel.shared.startDiscovery()
            DeviceConnectionManager.shared.startScanning()
        }
    }
    
    func stopDiscovery() {
        print("🛑 Stopping Discovery")
        discoveryManager.stopDiscovery()
        isDiscoveryConfigured = false
        DispatchQueue.main.async {
            SmartTVDiscoveryScanner.shared.stopDiscovery()
        }
    }
    
    @MainActor
    func handleDeviceAction(
        onAirPlay: () -> Void,
        onTV: () -> Void,
        onNoDevice: () -> Void
    ) {
        let isAirPlayConnected = AVAudioSession.sharedInstance()
            .currentRoute.outputs
            .contains { $0.portType == .airPlay }
            || TR_AirPlayManager.shared.isAirPlayConnected
            || DeviceConnectionManager.shared.isAirPlayConnected
        
        if isAirPlayConnected {
            onAirPlay()
            return
        }
        
        if let type = connectedTVType, type != .NONETV, isConnectedSuccessfully {
            if type == .AIRPLAY {
                onAirPlay()
            } else {
                onTV()
            }
            return
        }
        
        if let dev = DeviceConnectionManager.shared.connectedDevice {
            if dev.isAirPlay {
                onAirPlay()
            } else {
                onTV()
            }
            return
        }
        
        if let type = TR_DeviceConnectivityViewModel.shared.getConnectedTvType(), type != .NONETV && type != .AIRPLAY, (TR_DeviceConnectivityViewModel.shared.isDeviceConnected || isConnectedSuccessfully) {
            onTV()
            return
        }
        
        if TR_DeviceConnectivityViewModel.shared.isDeviceConnected || (commonViewModel?.isDeviceConnected ?? false) {
            onTV()
            return
        }
        
        onNoDevice()
    }
    
    // MARK: - TR_TV Connection Management
    func selectDevice(_ device: ConnectableDevice) {
        showProgress = true
        isConnectedSuccessfully = false
        connectedTVType = nil
        showPinDialog = false
        pinCode = ""
        deviceName = device.friendlyName
        connectingDeviceAddress = device.address
        
        let targetAddress = device.address
        DispatchQueue.main.asyncAfter(deadline: .now() + 25.0) { [weak self] in
            guard let self = self else { return }
            if self.showProgress && self.connectingDeviceAddress == targetAddress && !self.isConnectedSuccessfully {
                print("⏳ Connection timed out for \(targetAddress) (TR_TV may be powered off)")
                self.showProgress = false
                self.showPinDialog = false
                self.connectingDeviceAddress = nil
            }
        }
        
        if let tvType = identifyTVType(from: device) {
            print("Identified TR_TV: \(tvType) for device: \(device.friendlyName ?? "")")
            connectToTV(type: tvType, device: device)
            return
        }
        
        print("Could not identify by name/services, starting port scan...")
        let orderedTypes: [TR_TelevisionType] = [.SAMSUNG, .LG, .ROKU, .FIRE, .ANDROID]
        for type in orderedTypes {
            if let ports = tvPorts[type] {
                for port in ports {
                    isPortOpen(host: device.address, port: port) { [weak self] isOpen in
                        if isOpen {
                            DispatchQueue.main.async {
                                guard let self = self, self.connectedTVType == nil, self.connectingDeviceAddress == device.address else { return }
                                print("Port \(port) open -> Identified as \(type)")
                                self.connectToTV(type: type, device: device)
                            }
                            return
                        }
                    }
                }
            }
        }
    }
    
    @MainActor func connect(to device: ConnectableDevice) {
        
        // Prevent multiple taps while switching
        guard !isSwitchingDevice else {
            print("⚠️ Already switching device")
            return
        }
        
        // ✅ SAME DEVICE TAPPED → Disconnect
        if let connectedAddress = connectingDeviceAddress,
           connectedTVType != nil,
           connectedAddress == device.address {
            
            print("🔌 Tapped connected device → Disconnecting")
            
            isSwitchingDevice = true
            
            disconnectTV()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isSwitchingDevice = false
            }
            
            return
        }
        
        // ✅ DIFFERENT DEVICE TAPPED → Switch
        if connectedTVType != nil {
            
            print("🔄 Switching TR_TV connection from \(deviceName ?? "") to \(device.friendlyName ?? "")")
            
            isSwitchingDevice = true
            pendingDevice = device
            
            disconnectTV()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                
                guard let self = self,
                      let newDevice = self.pendingDevice else { return }
                
                self.pendingDevice = nil
                self.isSwitchingDevice = false
                
                print("🔌 Connecting to new device: \(newDevice.friendlyName ?? "")")
                
                self.selectDevice(newDevice)
            }
            
            return
        }
        
        // ✅ Fresh connection
        print("🔌 Connecting to device: \(device.friendlyName ?? "")")
        selectDevice(device)
    }
    
    private func connectToTV(type: TR_TelevisionType, device: ConnectableDevice) {
        selectedTVType = type
        initializeTVManager(for: type, ipAddress: device.address)
        setupConnectionMonitoring(for: type)
        commonViewModel?.setConnectedTv(tvType: type)
        commonViewModel?.isDeviceConnected = true
        
        // Start connection process
        switch type {
        case .ANDROID:
            print("android connecting to \(device.address)")
            (currentTVManager as? TR_AndroidControlManager)?.establishConnection(with: device.address)
            selectedTvType = .ANDROID
            if let castDevice = gcastDevice.first(where: { $0.ipAddress == device.address }) {
                print("✅ Found matching GCKDevice")
                commonViewModel?.castViewModel.selectedDevice = castDevice
                commonViewModel?.castViewModel.isConnected = true
            }
            if !device.connected {
                device.setPairingType(DeviceServicePairingTypePinCode)
                DispatchQueue.global(qos: .userInitiated).async {
                    device.connect()
                }
            }
            commonViewModel?.connectSDKDiscoveryModel.selectedLGDevice = device
            setSelectedTV(name: "Android-\(device.friendlyName ?? "AndroidTV")")
            
        case .SAMSUNG:
            print("samsung connecting to \(device.address)")
            showPinDialog = false
            if let manager = currentTVManager as? TR_SamsungControlManager {
                manager.deviceIP = device.address
                manager.UserTappedConnect(ip: device.address)
            }
            selectedTvType = .SAMSUNG
            setSelectedTV(name: "Samsung-\(device.friendlyName ?? "SamsungTV")")
            if let castDevice = gcastDevice.first(where: { $0.ipAddress == device.address }) {
                print("✅ Found matching GCKDevice")
                commonViewModel?.castViewModel.selectedDevice = castDevice
                commonViewModel?.castViewModel.isConnected = true
            }
            if !device.connected {
                device.setPairingType(DeviceServicePairingTypeFirstScreen)
                DispatchQueue.global(qos: .userInitiated).async {
                    device.connect()
                }
            }
            commonViewModel?.connectSDKDiscoveryModel.selectedLGDevice = device
            
        case .FIRE:
            print("fire connecting to \(device.address)")
            (currentTVManager as? TR_FireControlManager)?.deviceIP = device.address
            (currentTVManager as? TR_FireControlManager)?.verifyInitialConnection { [weak self] showPin in
                DispatchQueue.main.async {
                    self?.showProgress = false
                    self?.showPinDialog = showPin
                }
            }
            if !device.connected {
                device.setPairingType(DeviceServicePairingTypePinCode)
                DispatchQueue.global(qos: .userInitiated).async {
                    device.connect()
                }
            }
            commonViewModel?.connectSDKDiscoveryModel.selectedLGDevice = device
            selectedTvType = .FIRE
            setSelectedTV(name: "Fire-\(device.friendlyName ?? "FireTV")")
            
        case .ROKU:
            print("roku connecting to \(device.address)")
            (currentTVManager as? TR_RokuControlManager)?.SelectRoku(device.address)
            if !device.connected {
                device.setPairingType(DeviceServicePairingTypePinCode)
                DispatchQueue.global(qos: .userInitiated).async {
                    device.connect()
                }
            }
            commonViewModel?.connectSDKDiscoveryModel.selectedLGDevice = device
            selectedTvType = .ROKU
            setSelectedTV(name: "Roku-\(device.friendlyName ?? "RokuTV")")
            
        case .LG:
            print("lg connecting to \(device.address)")
            (currentTVManager as? TR_LGControlManager)?.connectLG(device: device)
            commonViewModel?.connectSDKDiscoveryModel.selectedLGDevice = device
            selectedTvType = .LG
            setSelectedTV(name: "LG-\(device.friendlyName ?? "LGTV")")
            
        case .AIRPLAY:
            selectedTvType = .AIRPLAY
            break
        case .NONETV:
            selectedTvType = .NONETV
            setSelectedTV(name: "")
            break
        }
    }
    
    private func initializeTVManager(for type: TR_TelevisionType, ipAddress: String = "") {
        switch type {
        case .ANDROID:
            currentTVManager = TR_AndroidControlManager()
        case .SAMSUNG:
            currentTVManager = TR_SamsungControlManager()
        case .FIRE:
            currentTVManager = TR_FireControlManager(ipAddress: ipAddress)
        case .ROKU:
            currentTVManager = TR_RokuControlManager()
        case .LG:
            let lgManager = TR_LGControlManager()
            
            lgManager.onDisconnectOrFailure = { [weak self] in
                DispatchQueue.main.async {
                    print("🧹 Resetting pairing layouts via TVViewModel")
                    let wasEnteringPin = (self?.showProgress == true || self?.showPinDialog == true) && self?.isConnectedSuccessfully == false
                    self?.connectingDeviceAddress = nil
                    self?.showProgress = false
                    self?.showPinDialog = false
                    self?.isConnectedSuccessfully = false
                    if wasEnteringPin {
                        self?.pinCode = ""
                        self?.incorrectPinTrigger = UUID()
                    }
                }
            }
            
            lgManager.onPairingRequired = { [weak self] pairingType in
                DispatchQueue.main.async {
                    print("🔐 Showing LG Pairing UI for type: \(pairingType)")
                    if pairingType == DeviceServicePairingTypePinCode {
                        self?.showProgress = false
                        self?.showPinDialog = true
                    } else {
                        self?.showProgress = true
                        self?.showPinDialog = false
                    }
                }
            }
            
            lgManager.onPairingSuccess = { [weak self] in
                DispatchQueue.main.async {
                    self?.showProgress = false
                    self?.showPinDialog = false
                    self?.connectedTVType = .LG
                    self?.isConnectedSuccessfully = true
                    self?.commonViewModel?.setConnectedTv(tvType: .LG)
                    if let dev = lgManager.selectedDevice {
                        self?.commonViewModel?.connectSDKDiscoveryModel.selectedLGDevice = dev
                        self?.commonViewModel?.connectSDKDiscoveryModel.isConnectedToLG = true
                        if self?.connectingDeviceAddress == nil {
                            self?.connectingDeviceAddress = dev.address
                        }
                    }
                    DeviceConnectionManager.shared.setConnectedDeviceManually(address: self?.connectingDeviceAddress ?? lgManager.selectedDevice?.address, name: self?.deviceName ?? lgManager.selectedDevice?.friendlyName ?? "LG TR_TV", type: .LG)
                }
            }
            
            currentTVManager = lgManager
        case .AIRPLAY:
            break
        case .NONETV:
            break
        }
    }
    
    private func setupConnectionMonitoring(for type: TR_TelevisionType) {
        switch type {
        case .ANDROID:
            monitorAndroidConnection()
        case .SAMSUNG:
            monitorSamsungConnection()
        case .FIRE:
            monitorFireConnection()
        case .ROKU:
            monitorRokuConnection()
        case .LG:
            monitorLGConnection()
        case .AIRPLAY:
            break
        case .NONETV:
            break
        }
    }
    
    @MainActor func disconnectTV() {
        connectingDeviceAddress = nil
        showProgress = false
        deviceName = nil
        isConnectedSuccessfully = false
        showDisconnectPopup = false
        connectedTVType = nil
        selectedTVType = nil
        
        print("🛑 Disconnecting current TR_TV")
        
        let activeManager = currentTVManager
        currentTVManager = nil
        
        (activeManager as? TR_AndroidControlManager)?.terminateConnection()
        (activeManager as? TR_SamsungControlManager)?.UserTappedDisconnect()
        (activeManager as? TR_FireControlManager)?.Disconnect()
        (activeManager as? TR_RokuControlManager)?.Disconnect()
        (activeManager as? TR_LGControlManager)?.disconnectFromTV()
        
        commonViewModel?.isDeviceConnected = false
        commonViewModel?.setConnectedTv(tvType: .NONETV)
        selectedTvType = .NONETV
        setSelectedTV(name: "")
        
        // Synchronize DeviceConnectionManager and TR_DeviceConnectivityViewModel
        TR_AirPlayManager.shared.isAirPlayConnected = false
        TR_AirPlayManager.shared.connectedDeviceName = ""
        DeviceConnectionManager.shared.isAirPlayConnected = false
        DeviceConnectionManager.shared.isMirroringActive = false
        DeviceConnectionManager.shared.connectedDevice = nil
        for i in DeviceConnectionManager.shared.availableDevices.indices {
            DeviceConnectionManager.shared.availableDevices[i].isConnected = false
            DeviceConnectionManager.shared.availableDevices[i].isConnecting = false
        }
        TR_DeviceConnectivityViewModel.shared.disconnectTv()
        
        // Stop Mirroring, Casting, and Player Displays
        TR_ImageCastAirPlayManager.shared.stopPlayback()
        TR_CastVideoPlayerManager.shared.stopPlayback()
        AudioPlaybackController.dismissGlobalExternalDisplay()
        
        if let defaults = UserDefaults(suiteName: TR_AppStrings.groupID) {
            defaults.set(false, forKey: "isBroadcasting")
            defaults.set(true, forKey: "shouldStopBroadcast")
            defaults.synchronize()
        }
        TR_MirroringServerManager.shared.stopServer()
        TR_SilentAudioManager.shared.forceStop()
        DeviceConnectionManager.shared.checkMirroringStatus()
        
        TR_AppUtils.instance.hapticFeedback()
    }
    
    private func linkCastAfterAndroidConnected(retry: Int = 6) {
        guard retry > 0 else {
            print("❌ Cast device not found")
            return
        }
        
        let castDevices = gcastDevice
        
        print("📡 Available Cast Devices:", castDevices.map { $0.friendlyName ?? "" })
        
        // ✅ Try match by IP FIRST
        if let currentIP = (currentTVManager as? TR_AndroidControlManager)?.deviceIP,
           let match = castDevices.first(where: {
               $0.ipAddress == currentIP
           }) {
            
            print("✅ Cast device linked via IP")
            
            TR_TVStreamingViewModel.shared.selectedDevice = match
            TR_TVStreamingViewModel.shared.isConnected = true
            commonViewModel?.castViewModel.selectedDevice = match
            commonViewModel?.castViewModel.isConnected = true
            return
        }
        
        // ✅ fallback name match
        if let tvName = deviceName,
           let match = castDevices.first(where: {
               ($0.friendlyName ?? "").lowercased().contains(tvName.lowercased())
           }) {
            
            print("✅ Cast device linked via NAME")
            
            TR_TVStreamingViewModel.shared.selectedDevice = match
            TR_TVStreamingViewModel.shared.isConnected = true
            commonViewModel?.castViewModel.selectedDevice = match
            commonViewModel?.castViewModel.isConnected = true
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.linkCastAfterAndroidConnected(retry: retry - 1)
        }
    }
    
//    func submitPinCode() {
//        let cleanPin = pinCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
//        print("PIN Submitted: \(cleanPin), selectedTVType = \(selectedTVType as Any)")
//        guard let type = selectedTVType else { return }
//        
//        switch type {
//        case .ANDROID:
//            (currentTVManager as? TR_AndroidControlManager)?.submitCode(cleanPin)
//        case .FIRE:
//            (currentTVManager as? TR_FireControlManager)?.verifyPin(pinCode: cleanPin) { [weak self] status in
//                if (self?.currentTVManager as? TR_FireControlManager)?.connectionStatus == true {
//                    self?.connectedTVType = .FIRE
//                    self?.showPinDialog = false
//                    self?.isConnectedSuccessfully = true
//                    self?.commonViewModel?.setConnectedTv(tvType: .FIRE)
//                    self?.commonViewModel?.isDeviceConnected = true
//                } else {
//                    DispatchQueue.main.async {
//                        self?.showProgress = false
//                        self?.showPinDialog = true
//                        self?.pinCode = ""
//                        self?.incorrectPinTrigger = UUID()
//                    }
//                }
//            }
//        case .LG:
//            if !cleanPin.isEmpty {
//                (currentTVManager as? TR_LGControlManager)?.sendPairingKey(cleanPin)
//            }
//        default:
//            break
//        }
//    }
    func submitPinCode() {
        let cleanPin = pinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        print("PIN Submitted: \(cleanPin)")
        print("selectedTVType =", selectedTVType as Any)
        guard let type = selectedTVType else { return }
        
        switch type {
        case .ANDROID:
            showProgress = true
            (currentTVManager as? TR_AndroidControlManager)?.submitCode(cleanPin)
        case .FIRE:
            showProgress = true
            (currentTVManager as? TR_FireControlManager)?.verifyPin(pinCode: cleanPin) { [weak self] status in
                if (self?.currentTVManager as? TR_FireControlManager)?.connectionStatus == true {
                    self?.showProgress = false
                    self?.connectedTVType = .FIRE
                    self?.showPinDialog = false
                    self?.isConnectedSuccessfully = true
                    self?.commonViewModel?.setConnectedTv(tvType: .FIRE)
                    self?.commonViewModel?.isDeviceConnected = true
                } else {
                    DispatchQueue.main.async {
                        self?.showProgress = false
                        self?.showPinDialog = false
                        self?.pinCode = ""
                        self?.incorrectPinTrigger = UUID()
                    }
                }
            }
        case .LG:
            showProgress = true
            (currentTVManager as? TR_LGControlManager)?.sendPairingKey(cleanPin)
            
            let targetAddress = connectingDeviceAddress
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
                guard let self = self else { return }
                if self.showProgress && self.connectingDeviceAddress == targetAddress && !self.isConnectedSuccessfully {
                    print("⏳ LG PIN submission timed out (invalid code)")
                    self.showProgress = false
                    self.showPinDialog = false
                    self.pinCode = ""
                    self.incorrectPinTrigger = UUID()
                }
            }
        default:
            break
        }
    }
    
    private var isMirroringActive: Bool {
        let isBroadcasting = UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") ?? false
        let mode = UserDefaults(suiteName: TR_AppStrings.groupID)?.string(forKey: "broadcastMode") ?? ""
        let isCaptured = Thread.isMainThread ? UIScreen.main.isCaptured : false
        return isCaptured && isBroadcasting && (mode == "mirroring")
    }
    
    // MARK: - Remote Control Commands
    @MainActor func sendCommand(_ key: TR_RemoteKey) {
        if isMirroringActive {
            print("⚠️ Remote command ignored because TV Remote is active.")
            return
        }
        var resolvedType = connectedTVType ?? TR_DeviceConnectivityViewModel.shared.connectedTvType
        if resolvedType == nil, let dev = DeviceConnectionManager.shared.connectedDevice?.connectableDevice {
            resolvedType = identifyTVType(from: dev)
        }
        guard let type = resolvedType else {
            showSearchingSheet = true
            return
        }
        
        switch type {
        case .ANDROID:
            if let action = mapAndroidKey(key) {
                (currentTVManager as? TR_AndroidControlManager)?.SendCommand(action: action)
            }
        case .SAMSUNG:
            if let code = mapSamsungKey(key) {
                (currentTVManager as? TR_SamsungControlManager)?.TR_KeyPress(keyCode: code)
            }
        case .FIRE:
            if let fireKey = mapFireTVKey(key) {
                (currentTVManager as? TR_FireControlManager)?.PerformKeyPress(keyAction: fireKey)
            }
        case .ROKU:
            if let rokuKey = mapRokuKey(key) {
                (currentTVManager as? TR_RokuControlManager)?.TR_KeyPress(key: rokuKey)
            }
        case .LG:
            if let lgCommand = mapLGKey(key) {
                (currentTVManager as? TR_LGControlManager)?.sendCommand(lgCommand)
            }
        case .AIRPLAY:
            break
        case .NONETV:
            break
        }
        
        TR_AppUtils.instance.hapticFeedback()
    }
    
    @MainActor func sendNumber(_ key: String) {
        print("TR_Key pressed: \(key)")
        guard !key.isEmpty else { return }
        
        if key.count == 1 {
            sendSingleDigit(key)
        } else {
            // Send each digit sequentially with a small delay
            for (index, char) in key.enumerated() {
                let digit = String(char)
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) { [weak self] in
                    self?.sendSingleDigit(digit)
                }
            }
        }
    }
    
    @MainActor func sendSingleDigit(_ key: String) {
        guard let type = connectedTVType else {
            showSearchingSheet = true
            return
        }
        
        switch type {
        case .ANDROID:
            let mapping: [String: TR_Key] = [
                "0": .KEYCODE_0,
                "1": .KEYCODE_1,
                "2": .KEYCODE_2,
                "3": .KEYCODE_3,
                "4": .KEYCODE_4,
                "5": .KEYCODE_5,
                "6": .KEYCODE_6,
                "7": .KEYCODE_7,
                "8": .KEYCODE_8,
                "9": .KEYCODE_9
            ]
            if let keyCode = mapping[key] {
                (currentTVManager as? TR_AndroidControlManager)?.SendCommand(action: keyCode)
            }
            
        case .SAMSUNG:
            let mapping: [String: TR_TVRemoteCommand.TR_Params.TR_ControlKey] = [
                "0": .number0,
                "1": .number1,
                "2": .number2,
                "3": .number3,
                "4": .number4,
                "5": .number5,
                "6": .number6,
                "7": .number7,
                "8": .number8,
                "9": .number9
            ]
            if let keyCode = mapping[key] {
                (currentTVManager as? TR_SamsungControlManager)?.TR_KeyPress(keyCode: keyCode)
            }
            
        case .LG:
            (currentTVManager as? TR_LGControlManager)?.sendNumber(key)
            
        case .ROKU:
            (currentTVManager as? TR_RokuControlManager)?.sendKeyboardInput(key)
            
        case .FIRE:
            (currentTVManager as? TR_FireControlManager)?.sendSearchTextInput(action: key) { _ in }
            
        case .AIRPLAY, .NONETV:
            break
        }
        
        TR_AppUtils.instance.hapticFeedback()
    }
                                                                                                             
    @MainActor func sendBackspace() {
        guard let type = connectedTVType else { return }
        switch type {
        case .ANDROID:
            (currentTVManager as? TR_AndroidControlManager)?.delete()
        case .SAMSUNG:
            (currentTVManager as? TR_SamsungControlManager)?.TR_KeyPress(keyCode: .backspace)
        case .LG:
            (currentTVManager as? TR_LGControlManager)?.sendDelete()
        case .ROKU:
            (currentTVManager as? TR_RokuControlManager)?.sendKeyboardInput("")
        case .FIRE:
            (currentTVManager as? TR_FireControlManager)?.PerformKeyPress(keyAction: .KEYCODE_BACKSPACE)
        default:
            break
        }
        TR_AppUtils.instance.hapticFeedback()
    }
    
    @MainActor func sendEnter() {
        guard let type = connectedTVType else { return }
        switch type {
        case .ANDROID:
            (currentTVManager as? TR_AndroidControlManager)?.SendCommand(action: .KEYCODE_ENTER)
        case .SAMSUNG:
            (currentTVManager as? TR_SamsungControlManager)?.TR_KeyPress(keyCode: .enter)
        case .LG:
            (currentTVManager as? TR_LGControlManager)?.sendEnter()
        case .ROKU:
            (currentTVManager as? TR_RokuControlManager)?.TR_KeyPress(key: .KEYCODE_OK)
        case .FIRE:
            (currentTVManager as? TR_FireControlManager)?.PerformKeyPress(keyAction: .KEYCODE_OK)
        default:
            sendCommand(.OK)
        }
        TR_AppUtils.instance.hapticFeedback()
    }
    
    func showSearchBar(isPro: Bool) {
        guard connectedTVType != nil else {
            showSearchingSheet = true
            return
        }
        
        if connectedTVType == .LG {
            (currentTVManager as? TR_LGControlManager)?.launchSearch()
        }
        
        showSearchBar = true
        TR_AppUtils.instance.hapticFeedback()
    }
    
    // MARK: - App Launching
    @MainActor func launchApp(_ app: TR_TVApps) {
        guard let type = connectedTVType else {
            showSearchingSheet = true
            return
        }
        
        switch type {
        case .ANDROID:
            (currentTVManager as? TR_AndroidControlManager)?.launchMediaOnRemoteScreen(url: app.deepLinkURL)
        case .SAMSUNG:
            (currentTVManager as? TR_SamsungControlManager)?.UserTappedLaunchApp(tvapp: app.toSamsungApp())
        case .FIRE:
            (currentTVManager as? TR_FireControlManager)?.launchAppOnRemote(appId: app.fireTVAppId) { _ in }
        case .ROKU:
            (currentTVManager as? TR_RokuControlManager)?.launchApp(app.rokuAppId)
        case .LG:
            switch app {
            case .youtube:
                (currentTVManager as? TR_LGControlManager)?.LaunchApp(url: "youtube.leanback.v4")
            case .netflix:
                (currentTVManager as? TR_LGControlManager)?.LauchNetfliz()
            case .prime:
                (currentTVManager as? TR_LGControlManager)?.LauchPrime()
            case .spotify:
                (currentTVManager as? TR_LGControlManager)?.LaunchApp(url: "spotify-beehive")
            case .disney:
                (currentTVManager as? TR_LGControlManager)?.LaunchApp(url: "com.disney.disneyplus-prod")
            case .paramount:
                (currentTVManager as? TR_LGControlManager)?.LaunchApp(url: "com.cbs.app")
            case .eSPN:
                (currentTVManager as? TR_LGControlManager)?.LaunchApp(url: "com.espn.app")
            case .hulu:
                (currentTVManager as? TR_LGControlManager)?.LaunchApp(url: "hulu")
            case .peacock:
                (currentTVManager as? TR_LGControlManager)?.LaunchApp(url: "com.peacocktv.peacock")
            }
        case .AIRPLAY:
            break
        case .NONETV:
            break
        }
        
        TR_AppUtils.instance.hapticFeedback()
    }
    
    
    // MARK: - Helper Methods
    //    private func identifyTVType(from deviceName: String) -> TVType? {
    //        let lowercasedName = deviceName.lowercased()
    //
    //        if lowercasedName.contains("lg") { return .LG }
    //        if lowercasedName.contains("android") { return .ANDROID }
    //        if lowercasedName.contains("fire") { return .FIRE }
    //        if lowercasedName.contains("samsung") { return .SAMSUNG }
    //        if lowercasedName.contains("roku") { return .ROKU }
    //
    //        return nil
    //    }
    
    func identifyTVType(from deviceName: ConnectableDevice) -> TR_TelevisionType? {
        let model = (deviceName.modelName ?? "").lowercased()
        let manufacturer = (deviceName.serviceDescription?.manufacturer ?? "").lowercased()
        let friendly = (deviceName.friendlyName ?? "").lowercased()
        
        print("modelName :- \(model) , manufacturer :- \(manufacturer), friendlyName :- \(friendly)")
        
        // 1. Direct Brand Match on Manufacturer / Model / Friendly Name
        if manufacturer.contains("samsung") || model.contains("samsung") || friendly.contains("samsung") || friendly.contains("tizen") || friendly.contains("sec_") || model.contains("tizen") || model.hasPrefix("un") || model.hasPrefix("qn") || model.hasPrefix("qa") || model.hasPrefix("ue") || model.hasPrefix("qe") || model.hasPrefix("ua") {
            return .SAMSUNG
        } else if manufacturer.contains("lg") || model.contains("lg") || model.contains("webos") || friendly.contains("lg") || friendly.contains("webos") || friendly.contains("netcast") {
            return .LG
        } else if manufacturer.contains("roku") || model.contains("roku") || friendly.contains("roku") {
            return .ROKU
        } else if manufacturer.contains("amazon") || model.contains("fire") || model.contains("aft") || friendly.contains("fire tv") || friendly.contains("firetv") || friendly.contains("aft") {
            return .FIRE
        } else if manufacturer.contains("xiaomi") || model.contains("xiaomi") || model.contains("mitv") || model.contains("mi tv") {
            return .ANDROID
        }
        
        // 2. Specific Service Identification
        if let services = deviceName.services {
            for service in services {
                guard let service = service as? DeviceService else {
                    continue
                }
                let serviceClass = NSStringFromClass(type(of: service).self)
                print("Service found: \(serviceClass)")
                
                if let cls = NSClassFromString("WebOSTVService"), service.isKind(of: cls) {
                    return .LG
                } else if let cls = NSClassFromString("NetcastTVService"), service.isKind(of: cls) {
                    return .LG
                } else if let rokuCls = NSClassFromString("RokuService"), service.isKind(of: rokuCls) {
                    return .ROKU
                } else if let cls = NSClassFromString("FireTVService"), service.isKind(of: cls) {
                    return .FIRE
                } else if let cls = NSClassFromString("CastService"), service.isKind(of: cls) {
                    return .ANDROID
                }
            }
        }
        
        // 3. Specific Android TR_TV Brands (Excluding generic keywords like "tv")
        let specificAndroidBrands = [
            "xiaomi", "mitv", "mi tv", "redmi", "sony", "bravia", "tcl", "hisense",
            "philips", "oneplus", "realme", "google", "chromecast", "android tv", "androidtv",
            "haier", "vu", "lloyd", "nokia", "insignia", "bpl", "sharp", "toshiba",
            "panasonic", "motorola", "kodak", "iffalcon", "thomson", "sansui", "akai",
            "skyworth", "sanyo", "kogan", "shield", "mibox"
        ]
        for kw in specificAndroidBrands {
            if manufacturer.contains(kw) || model.contains(kw) || friendly.contains(kw) {
                return .ANDROID
            }
        }
        
        // 4. DLNA Service Fallback Check
        if let services = deviceName.services {
            for service in services {
                guard let service = service as? DeviceService else { continue }
                if let cls = NSClassFromString("DLNAService"), service.isKind(of: cls) {
                    if friendly.contains("webos") || friendly.contains("lg") || model.contains("webos") || model.contains("lg") {
                        return .LG
                    } else if friendly.contains("samsung") || model.contains("samsung") {
                        return .SAMSUNG
                    } else if friendly.contains("roku") || model.contains("roku") {
                        return .ROKU
                    }
                }
            }
        }
        
        return nil
    }
    
    func isPortOpen(host: String, port: Int, completion: @escaping (Bool) -> Void) {
        let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port("\(port)")!, using: .tcp)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                completion(true)
                connection.cancel()
            case .failed(_), .cancelled:
                completion(false)
            default:
                break
            }
        }
        connection.start(queue: .global())
    }
    
    // MARK: - Connection Monitoring
    private func monitorAndroidConnection() {
        print("monitoring android")
        (currentTVManager as? TR_AndroidControlManager)?.connectionStateUpdated = { [weak self] state in
            DispatchQueue.main.async {
                print("[TR_TV Remote View Model] Android Connection State: \(state)")
                let lower = state.lowercased()
                if lower.contains("waiting") || lower.contains("code") {
                    print("[TR_TV Remote View Model] Triggering PIN Dialog for Android TR_TV (state: \(state))")
                    self?.showProgress = false
                    self?.showPinDialog = true
                } else if lower.contains("prepairing") || lower.contains("preparing") || lower.contains("extract tls") || lower.contains("connection set up") || lower.contains("request sent") || lower.contains("secret has been sent") || lower.contains("secretsent") {
                    self?.showProgress = true
                } else if lower.contains("success paired") || lower.contains("paired!") {
                    self?.showProgress = false
                    self?.showPinDialog = false
                    self?.connectedTVType = .ANDROID
                    self?.isConnectedSuccessfully = true
                    self?.commonViewModel?.setConnectedTv(tvType: .ANDROID)
                    DeviceConnectionManager.shared.setConnectedDeviceManually(address: self?.connectingDeviceAddress, name: self?.deviceName ?? "Android TR_TV", type: .ANDROID)
                } else if lower.contains("error") || lower.contains("failed") || lower.contains("canceled") || lower.contains("not success") {
                    print("⚠️ Android TR_TV pairing error: \(state)")
                    let wasWaitingForPin = self?.showPinDialog == true
                    self?.showProgress = false
                    self?.showPinDialog = false
                    self?.pinCode = ""
                    self?.connectingDeviceAddress = nil
                    if wasWaitingForPin {
                        self?.incorrectPinTrigger = UUID()
                    }
                }
            }
        }
        
        (currentTVManager as? TR_AndroidControlManager)?.deviceStateUpdated = { [weak self] state in
            DispatchQueue.main.async {
                print("[TR_TV Remote View Model] Android TR_Device State: \(state)")
                let lower = state.lowercased()
                if lower.contains("paired") {
                    self?.connectedTVType = .ANDROID
                    self?.showPinDialog = false
                    self?.showProgress = false
                    self?.isConnectedSuccessfully = true
                    self?.commonViewModel?.setConnectedTv(tvType: .ANDROID)
                    DeviceConnectionManager.shared.setConnectedDeviceManually(address: self?.connectingDeviceAddress, name: self?.deviceName ?? "Android TR_TV", type: .ANDROID)
                    print("✅ Android TR_TV fully paired and connected")
                    
                    self?.linkCastAfterAndroidConnected()
                }
            }
        }
    }
    
    private func monitorSamsungConnection() {
        guard let samsungManager = currentTVManager as? TR_SamsungControlManager else { return }
        
        samsungManager.$authStatus
            .sink { [weak self] authStatus in
                print("🔐 Auth TR_Status:", authStatus)
                if authStatus == .denied {
                    DispatchQueue.main.async {
                        self?.showProgress = false
                        self?.showPinDialog = false
                        self?.showAllowInTVSettingsAlert = true
                    }
                }
            }
            .store(in: &cancellables)
        
        samsungManager.$isConnected
            .combineLatest(samsungManager.$authStatus)
            .map { isConnected, authStatus in isConnected && authStatus == .allowed }
            .sink { [weak self] areBothConnected in
                if areBothConnected {
                    self?.showProgress = false
                    self?.showPinDialog = false
                    self?.connectedTVType = .SAMSUNG
                    self?.showCountdownAlert = false
                    self?.isConnectedSuccessfully = true
                    self?.commonViewModel?.setConnectedTv(tvType: .SAMSUNG)
                    self?.commonViewModel?.isDeviceConnected = true
                    self?.commonViewModel?.castViewModel.startCastSession()
                }
            }
            .store(in: &cancellables)
        
        // 🔥 NEW: Monitor the live app collection pipeline and trigger UI updates
        samsungManager.$installedApps
            .receive(on: RunLoop.main)
            .sink { [weak self] apps in
                print("📱 Dynamic Samsung Apps layout changed: \(apps.count) elements found. Redrawing view ecosystem...")
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        samsungManager.$isLoadingApps
            .receive(on: RunLoop.main)
            .sink { [weak self] loading in
                self?.isLoadingApps = loading
            }
            .store(in: &cancellables)
        
        // 🟢 Observe dynamic input ports changes
        samsungManager.$availablePorts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        
    }
    
    
    func launchSamsungInstalledApp(_ app: TR_TVApp) {
        if isMirroringActive { return }
        guard let samsungManager = currentTVManager as? TR_SamsungControlManager else { return }
        samsungManager.UserTappedLaunchApp(tvapp: app)
        TR_AppUtils.instance.hapticFeedback()
    }
    
    func switchToSamsungPort(_ port: TR_TVApp) {
        if isMirroringActive { return }
        guard let samsungManager = currentTVManager as? TR_SamsungControlManager else { return }
        samsungManager.switchToPort(port)
        TR_AppUtils.instance.hapticFeedback()
    }
    
    
    private func monitorFireConnection() {
        (currentTVManager as? TR_FireControlManager)?.$connectionStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] isConnected in
                if isConnected {
                    self?.showProgress = false
                    self?.showPinDialog = false
                    self?.connectedTVType = .FIRE
                    self?.isConnectedSuccessfully = true
                    self?.commonViewModel?.setConnectedTv(tvType: .FIRE)
                    DeviceConnectionManager.shared.setConnectedDeviceManually(address: self?.connectingDeviceAddress, name: self?.deviceName ?? "Fire TR_TV", type: .FIRE)
                }
            }
            .store(in: &cancellables)
    }
    
    private func monitorRokuConnection() {
        (currentTVManager as? TR_RokuControlManager)?.$connectionStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] isConnected in
                if isConnected {
                    self?.showProgress = false
                    self?.showPinDialog = false
                    self?.connectedTVType = .ROKU
                    self?.isConnectedSuccessfully = true
                    self?.commonViewModel?.setConnectedTv(tvType: .ROKU)
                    DeviceConnectionManager.shared.setConnectedDeviceManually(address: self?.connectingDeviceAddress, name: self?.deviceName ?? "Roku TR_TV", type: .ROKU)
                }
            }
            .store(in: &cancellables)
    }
    
    private func monitorLGConnection() {
        
        guard let lgManager = currentTVManager as? TR_LGControlManager else {
            return
        }
        
        lgManager.$connectionStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] isConnected in
                if isConnected {
                    self?.showProgress = false
                    self?.showPinDialog = false
                    self?.connectedTVType = .LG
                    self?.isConnectedSuccessfully = true
                    self?.commonViewModel?.setConnectedTv(tvType: .LG)
                    if let dev = lgManager.selectedDevice {
                        self?.commonViewModel?.connectSDKDiscoveryModel.selectedLGDevice = dev
                        self?.commonViewModel?.connectSDKDiscoveryModel.isConnectedToLG = true
                        if self?.connectingDeviceAddress == nil {
                            self?.connectingDeviceAddress = dev.address
                        }
                    }
                    DeviceConnectionManager.shared.setConnectedDeviceManually(address: self?.connectingDeviceAddress ?? lgManager.selectedDevice?.address, name: self?.deviceName ?? lgManager.selectedDevice?.friendlyName ?? "LG TR_TV", type: .LG)
                }
            }
            .store(in: &cancellables)
        
        lgManager.$availableApps
            .receive(on: RunLoop.main)
            .sink { [weak self] apps in
                print("📱 LG Apps Count:", apps.count)
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
//        lgManager.$isLoadingApps
//            .receive(on: RunLoop.main)
//            .sink { [weak self] loading in
//                self?.isLoadingApps = loading
//            }
//            .store(in: &cancellables)
    }
    
    func launchLGInstalledApp(_ app: TR_LGTVApps) {
        if isMirroringActive { return }
        guard let lgManager = currentTVManager as? TR_LGControlManager else {
            print("⚠️ Operations targeting LG manager failed: Incompatible type.")
            return
        }
        
        guard let launcher = lgManager.selectedDevice?.launcher() else {
            print("⚠️ App launcher reference missing on connectable hardware layout context.")
            return
        }
        
        let targetID = app.launchID
        print("🚀 Attempting network handoff for WebOS package: \(targetID)")
        
        launcher.launchApp(targetID, success: { _ in
            print("✅ Clean launch processed successfully for layout item ID: \(targetID)")
        }, failure: { error in
            print("❌ WebOS hardware interaction layout dropped: \(error?.localizedDescription ?? "Unknown Service Error")")
        })
        
        TR_AppUtils.instance.hapticFeedback()
    }
    
    // MARK: - Input Port Operations
    func switchToLGPort(_ port: AppInfo) {
        if isMirroringActive { return }
        guard let lgManager = currentTVManager as? TR_LGControlManager else {
            print("⚠️ Operations targeting LG manager failed: Incompatible manager type.")
            return
        }
        
        guard let launcher = lgManager.selectedDevice?.launcher() else {
            print("⚠️ App launcher reference missing on hardware context.")
            return
        }
        
        guard let portID = port.id else { return }
        print("🔌 Requesting port handoff to hardware node: \(portID)")
        
        launcher.launchApp(portID, success: { _ in
            print("✅ Clean hardware switch executed successfully for: \(port.name ?? "Input")")
        }, failure: { error in
            print("❌ WebOS rejected hardware port switch framework handoff: \(error?.localizedDescription ?? "Unknown Error")")
        })
        
        TR_AppUtils.instance.hapticFeedback()
    }
    
    func switchToAndroidPort(_ source: TVInputSource) {
        if isMirroringActive { return }
        guard let androidManager = currentTVManager as? TR_AndroidControlManager else {
            print("⚠️ TR_AndroidControlManager is nil when attempting to switch port")
            return
        }
        
        let key: TR_Key
        switch source {
        case .hdmi1:
            key = .KEYCODE_TV_INPUT_HDMI_1
        case .hdmi2:
            key = .KEYCODE_TV_INPUT_HDMI_2
        case .hdmi3:
            key = .KEYCODE_TV_INPUT_HDMI_3
        case .av1:
            key = .KEYCODE_TV_INPUT_COMPOSITE_1
        case .av2:
            key = .KEYCODE_TV_INPUT_COMPOSITE_2
        case .av3:
            key = .KEYCODE_TV_INPUT_COMPONENT_1
        }
        
        print("🔌 Switching Android TR_TV port to \(source.rawValue) (TR_Key: \(key))")
        androidManager.SendCommand(action: key)
        TR_AppUtils.instance.hapticFeedback()
    }
    
    func showAndroidInputMenu() {
        if isMirroringActive { return }
        guard let androidManager = currentTVManager as? TR_AndroidControlManager else { return }
        androidManager.SendCommand(action: .KEYCODE_TV_INPUT)
        TR_AppUtils.instance.hapticFeedback()
    }
    
    
    
    // MARK: - TR_Key Mapping (Keep your existing mapping functions)
    private func mapAndroidKey(_ key: TR_RemoteKey) -> TR_Key? {
        switch key {
        case .POWER: return .KEYCODE_POWER
        case .VOLUMEUP: return .KEYCODE_VOLUME_UP
        case .VOLUMEDOWN: return .KEYCODE_VOLUME_DOWN
        case .CHANNELUP: return .KEYCODE_CHANNEL_UP
        case .CHANNELDOWN: return .KEYCODE_CHANNEL_DOWN
        case .HOME: return .KEYCODE_HOME
        case .BACK: return .KEYCODE_BACK
        case .OK: return .KEYCODE_ENTER
        case .EXIT: return .KEYCODE_HOME
        case .MUTE: return .KEYCODE_MUTE
        case .DPAD_UP: return .KEYCODE_DPAD_UP
        case .DPAD_DOWN: return .KEYCODE_DPAD_DOWN
        case .DPAD_LEFT: return .KEYCODE_DPAD_LEFT
        case .DPAD_RIGHT: return .KEYCODE_DPAD_RIGHT
        case .PAUSE_PLAY: return .KEYCODE_MEDIA_PLAY_PAUSE
            
        case .MENU: return .KEYCODE_MENU
        case .SETTINGS: return .KEYCODE_SETTINGS
        case .PAUSE: return .KEYCODE_MEDIA_PAUSE
        case .PLAY: return .KEYCODE_MEDIA_PLAY
        case .INPUT_SOURCE: return .KEYCODE_TV_INPUT
        default: return nil
        }
    }
    
    private func mapRokuKey(_ key: TR_RemoteKey) -> TR_RokuRemoteKeys? {
        switch key {
        case .POWER: return .KEYCODE_POWER
        case .VOLUMEUP: return .KEYCODE_VOLUME_UP
        case .VOLUMEDOWN: return .KEYCODE_VOLUME_DOWN
        case .CHANNELUP: return .KEYCODE_DPAD_UP
        case .CHANNELDOWN: return .KEYCODE_DPAD_DOWN
        case .HOME: return .KEYCODE_HOME
        case .BACK: return .KEYCODE_BACK
        case .OK: return .KEYCODE_OK
        case .EXIT: return .KEYCODE_HOME
        case .MUTE: return .KEYCODE_MUTE
        case .DPAD_UP: return .KEYCODE_DPAD_UP
        case .DPAD_DOWN: return .KEYCODE_DPAD_DOWN
        case .DPAD_LEFT: return .KEYCODE_DPAD_LEFT
        case .DPAD_RIGHT: return .KEYCODE_DPAD_RIGHT
        case .PAUSE_PLAY: return .KEYCODE_OK
            
        case .STAR: return .KEYCODE_STAR
        case .RESTART: return .KEYCODE_REPLAY
        case .PLAY: return .KEYCODE_OK
        case .PAUSE: return .KEYCODE_OK
        default: return nil
        }
    }
    
    private func mapSamsungKey(_ key: TR_RemoteKey) ->  TR_TVRemoteCommand.TR_Params.TR_ControlKey?{
        switch key {
        case .POWER: return .powerToggle
        case .VOLUMEUP: return .volumeUp
        case .VOLUMEDOWN: return .volumeDown
        case .CHANNELUP: return .channelUp
        case .CHANNELDOWN: return .channelDown
        case .HOME: return .home
        case .BACK: return .returnKey
        case .OK: return .enter
        case .EXIT: return .exit
        case .MUTE: return .mute
        case .DPAD_UP: return .up
        case .DPAD_DOWN: return .down
        case .DPAD_LEFT: return .left
        case .DPAD_RIGHT: return .right
        case .PAUSE_PLAY: return .enter
            
        case .MENU: return .menu
        case .SETTINGS: return .menu
        case .PAUSE: return .pause
        case .PLAY: return .play
        default: return nil
        }
    }
    
    private func mapLGKey(_ key: TR_RemoteKey) -> TR_LGRemoteKeys? {
        switch key {
        case .POWER: return .KEYCODE_POWER
        case .VOLUMEUP: return .KEYCODE_VOLUME_UP
        case .VOLUMEDOWN: return .KEYCODE_VOLUME_DOWN
        case .CHANNELUP: return .KEYCODE_CHANNEL_UP
        case .CHANNELDOWN: return .KEYCODE_CHANNEL_DOWN
        case .HOME: return .KEYCODE_HOME
        case .BACK: return .KEYCODE_BACK
        case .OK: return .KEYCODE_OK
        case .EXIT: return .KEYCODE_HOME
        case .MUTE: return .KEYCODE_MUTE
        case .DPAD_UP: return .KEYCODE_DPAD_UP
        case .DPAD_DOWN: return .KEYCODE_DPAD_DOWN
        case .DPAD_LEFT: return .KEYCODE_DPAD_LEFT
        case .DPAD_RIGHT: return .KEYCODE_DPAD_RIGHT
        case .PAUSE_PLAY: return .KEYCODE_OK
            
            
        case .MENU: return .KEYCODE_MENU
        case .SETTINGS: return .KEYCODE_MENU
        case .PAUSE: return .KEYCODE_PAUSE
        case .PLAY: return .KEYCODE_PLAY
        case .SEARCH: return .KEYCODE_SEARCH
        default: return nil
        }
    }
    
    private func mapFireTVKey(_ key: TR_RemoteKey) -> TR_FireTVKeys? {
        switch key {
        case .POWER: return .KEYCODE_POWER
        case .VOLUMEUP: return .KEYCODE_VOLUME_UP
        case .VOLUMEDOWN: return .KEYCODE_VOLUME_DOWN
        case .CHANNELUP: return .KEYCODE_DPAD_UP
        case .CHANNELDOWN: return .KEYCODE_DPAD_DOWN
        case .HOME: return .KEYCODE_HOME
        case .BACK: return .KEYCODE_BACK
        case .OK: return .KEYCODE_OK
        case .EXIT: return .KEYCODE_EXIT
        case .MUTE: return .KEYCODE_MUTE
        case .DPAD_UP: return .KEYCODE_DPAD_UP
        case .DPAD_DOWN: return .KEYCODE_DPAD_DOWN
        case .DPAD_LEFT: return .KEYCODE_DPAD_LEFT
        case .DPAD_RIGHT: return .KEYCODE_DPAD_RIGHT
        case .PAUSE_PLAY: return .KEYCODE_OK
            
        case .PLAY: return .KEYCODE_PLAY
        case .PAUSE: return .KEYCODE_PAUSE
        case .SETTINGS: return .KEYCODE_MENU
        case .MENU: return .KEYCODE_MENU
        default: return nil
        }
    }
    
    private func mapHisenseKey(_ key: TR_RemoteKey) -> TR_HisenseRemoteKeys? {
        switch key {
        case .POWER: return .power
        case .VOLUMEUP: return .volumeUp
        case .VOLUMEDOWN: return .volumeDown
        case .CHANNELUP: return .channelUp
        case .CHANNELDOWN: return .channelDown
        case .HOME: return .home
        case .BACK: return .back
        case .OK: return .select
        case .EXIT: return .exit
        case .MUTE: return .mute
        case .DPAD_UP: return .up
        case .DPAD_DOWN: return .down
        case .DPAD_LEFT: return .left
        case .DPAD_RIGHT: return .right
        case .PAUSE_PLAY: return .play
            
        case .MENU: return .menu
        case .SETTINGS: return .menu
        case .PAUSE: return .pause
        case .PLAY: return .play
        default: return nil
        }
    }
    
    @MainActor func moveCursor(dx: Float, dy: Float) {
        if isMirroringActive { return }
        guard let type = connectedTVType else {
            showSearchingSheet = true
            return
        }
        
        switch type {
            
        case .LG:
            (currentTVManager as? TR_LGControlManager)?.movePointer(dx: dx, dy: dy)
            
        case .SAMSUNG:
            (currentTVManager as? TR_SamsungControlManager)?.mouseMove(dx: dx, dy: dy)
            
        default:
            // Optional fallback (you can ignore or use DPAD)
            break
        }
    }
    
    @MainActor func clickCursor() {
        if isMirroringActive { return }
        guard let type = connectedTVType else {
            showSearchingSheet = true
            return
        }
        
        switch type {
            
        case .LG:
            (currentTVManager as? TR_LGControlManager)?.clickPointer()
            
        case .SAMSUNG:
            (currentTVManager as? TR_SamsungControlManager)?.mouseClick()
            
        default:
            sendCommand(.OK)
        }
    }
}

// MARK: - DiscoveryManagerDelegate (ScreenNova 100% Exact Parity)
extension TR_RemoteViewModel: DiscoveryManagerDelegate {
    func discoveryManager(_ manager: DiscoveryManager!, didFind device: ConnectableDevice!) {
        guard let device = device else { return }
        print("⚡ ConnectSDK Discovered TR_Device:", device.friendlyName ?? device.modelName ?? "Pending XML", device.address ?? "")
        
        DispatchQueue.main.async {
            if let index = self.discoveredDevices.firstIndex(where: { $0.address == device.address }) {
                self.discoveredDevices[index] = device
            } else {
                self.discoveredDevices.append(device)
            }
            DeviceConnectionManager.shared.syncDevice(from: device)
            print("⚡ Discovered TR_Device Count:", self.discoveredDevices.count)
        }
    }
    
    func discoveryManager(_ manager: DiscoveryManager!, didLose device: ConnectableDevice!) {
        guard let device = device else { return }
        DispatchQueue.main.async {
            self.discoveredDevices.removeAll { $0.address == device.address }
            DeviceConnectionManager.shared.removeDevice(address: device.address)
        }
    }
    
    func discoveryManager(_ manager: DiscoveryManager!, didUpdate device: ConnectableDevice!) {
        guard let device = device else { return }
        print("⚡ ConnectSDK Updated TR_Device FriendlyName:", device.friendlyName ?? device.modelName ?? "", device.address ?? "")
        DispatchQueue.main.async {
            if let index = self.discoveredDevices.firstIndex(where: { $0.address == device.address }) {
                self.discoveredDevices[index] = device
            } else {
                self.discoveredDevices.append(device)
            }
            DeviceConnectionManager.shared.syncDevice(from: device)
        }
    }
}

extension TR_RemoteViewModel {
    
    @MainActor func handleVoiceCommands(_ rawText: String) {
        
        let text = normalize(rawText)
        print("🎤 Normalized: \(text)")
        
        // =========================
        // 🔍 1. CONTENT SEARCH & STREAMING APPS (YouTube, Netflix, Prime, Spotify)
        // =========================
        
        if containsAny(text, ["youtube", "you tube", "utube"]) {
            let query = extractSearchQuery(from: text, app: "youtube")
            if !query.isEmpty {
                print("🔍 YouTube Search Query: '\(query)'")
                searchYouTube(query: query)
            } else {
                launchApp(.youtube)
            }
            return
        }
        
        if containsAny(text, ["netflix", "net flix"]) {
            let query = extractSearchQuery(from: text, app: "netflix")
            if !query.isEmpty {
                if connectedTVType == .ANDROID {
                    if let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                        let searchURL = "https://www.netflix.com/search?q=\(encoded)"
                        (currentTVManager as? TR_AndroidControlManager)?.launchMediaOnRemoteScreen(url: searchURL)
                    } else {
                        launchApp(.netflix)
                    }
                } else {
                    launchApp(.netflix)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        self.typeTextOnTV(query)
                    }
                }
            } else {
                launchApp(.netflix)
            }
            return
        }
        
        if containsAny(text, ["prime video", "prime", "amazon prime", "amazon"]) {
            let query = extractSearchQuery(from: text, app: "prime video")
            launchApp(.prime)
            if !query.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    self.typeTextOnTV(query)
                }
            }
            return
        }
        
        if containsAny(text, ["spotify"]) {
            launchApp(.spotify)
            return
        }
        
        // General search query (e.g. "search comedies", "play tarak mehta", "find funny videos")
        let searchVerbs = ["search for", "search", "find", "look for", "look up", "play", "watch", "start playing"]
        if containsAny(text, searchVerbs) {
            let generalQuery = extractGeneralSearchQuery(from: text)
            if !generalQuery.isEmpty {
                print("🔍 General Video Search Query -> YouTube: '\(generalQuery)'")
                searchYouTube(query: generalQuery)
                return
            }
        }
        
        // =========================
        // 📺 3. TR_TV-SPECIFIC NATIVE APPS
        // =========================
        
        if connectedTVType == .SAMSUNG {
            
            if containsAny(text, ["browser", "internet browser", "explorer", "internet explorer", "web browser", "open browser", "launch browser", "open internet"]) {
                launchSamsungInstalledApp(TR_TVApp(id: "org.tizen.browser", name: "Browser"))
                return
            }
            
            if containsAny(text, ["apple tv", "open apple tv", "launch apple tv", "apple tv app"]) {
                launchSamsungInstalledApp(TR_TVApp(id: "3201807016597", name: "Apple TR_TV"))
                return
            }
            
            if containsAny(text, ["samsung tv plus", "tv plus", "live tv", "channel guide", "tv channels", "open tv plus", "samsung channels"]) {
                (currentTVManager as? TR_SamsungControlManager)?.TR_KeyPress(keyCode: .channelList)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    (self.currentTVManager as? TR_SamsungControlManager)?.TR_KeyPress(keyCode: .returnKey)
                }
                return
            }
            
        } else if connectedTVType == .LG {
            
            if containsAny(text, ["lg channels", "channels", "channel guide", "live channels", "open channels"]) {
                launchLGInstalledApp(.lgChannels)
                return
            }
            
            if containsAny(text, ["disney", "disney plus", "hotstar", "disney plus hotstar", "jio hotstar", "open disney plus"]) {
                launchLGInstalledApp(.disney)
                return
            }
            
            if containsAny(text, ["apple tv", "open apple tv", "launch apple tv", "apple tv app"]) {
                launchLGInstalledApp(.appleTV)
                return
            }
            
            if containsAny(text, ["zee5", "zee", "zee five", "open zee5", "zeefive"]) {
                launchLGInstalledApp(.zeeFive)
                return
            }
            
            if containsAny(text, ["lg gaming portal", "gaming portal", "game portal", "games", "open gaming portal", "lggamingportal"]) {
                launchLGInstalledApp(.lgGamingPortal)
                return
            }
            
            if containsAny(text, ["apps menu", "open apps", "show all apps", "app store", "all apps", "apps list"]) {
                launchLGInstalledApp(.apps)
                return
            }
            
            if containsAny(text, ["home office", "office mode", "open home office", "office app"]) {
                launchLGInstalledApp(.homeOffice)
                return
            }
            
            if containsAny(text, ["lg music", "music app", "open lg music", "music"]) {
                launchLGInstalledApp(.music)
                return
            }
            
            if containsAny(text, ["home hub", "smart hub", "open home hub"]) {
                launchLGInstalledApp(.homeHub)
                return
            }
            
            if containsAny(text, ["learning", "education", "learn", "learning app", "open learning"]) {
                launchLGInstalledApp(.learning)
                return
            }
            
            if containsAny(text, ["browser", "internet browser", "explorer", "internet explorer", "web browser", "open browser"]) {
                launchLGInstalledApp(.webBrowser)
                return
            }
            
            if containsAny(text, ["media player", "media", "player", "open media player", "local media"]) {
                launchLGInstalledApp(.mediaPlayer)
                return
            }
        }
        
        // =========================
        // 🎮 4. REMOTE / NAVIGATION COMMANDS
        // =========================
        
        if containsAny(text, [
            "volume up", "increase volume", "louder", "raise volume",
            "turn up the volume", "turn it up", "volume plus", "make it louder",
            "sound up", "increase the volume", "boost volume", "raise the volume",
            "turn volume up", "up the volume", "more volume", "higher volume"
        ]) {
            TVVolumeManager.shared.sendVolumeUp()
            return
        }
        
        if containsAny(text, [
            "volume down", "decrease volume", "lower volume", "quieter",
            "turn down the volume", "turn it down", "volume minus", "make it quieter",
            "sound down", "decrease the volume", "reduce volume", "lower the volume",
            "turn volume down", "down the volume", "less volume", "softer", "turn it low"
        ]) {
            TVVolumeManager.shared.sendVolumeDown()
            return
        }
        
        if containsAny(text, [
            "mute", "silence", "mute it", "turn off sound", "turn off the volume",
            "no sound", "silence it", "stop the sound", "volume off",
            "mute the tv", "quiet please", "shut off the sound"
        ]) {
            TVVolumeManager.shared.toggleMute()
            return
        }
        
        if containsAny(text, [
            "home", "go home", "exit", "home screen", "go to home",
            "main menu", "take me home", "go to main menu", "home button", "return home"
        ]) {
            sendCommand(.HOME)
            return
        }
        
        if containsAny(text, [
            "back", "go back", "previous", "go to previous",
            "take me back", "return", "undo", "previous screen", "step back"
        ]) {
            sendCommand(.BACK)
            return
        }
        
        if containsAny(text, ["up", "move up", "go up", "scroll up", "navigate up", "up arrow"]) {
            sendCommand(.DPAD_UP)
            return
        }
        
        if containsAny(text, ["down", "move down", "go down", "scroll down", "navigate down", "down arrow"]) {
            sendCommand(.DPAD_DOWN)
            return
        }
        
        if containsAny(text, ["left", "move left", "go left", "navigate left", "left arrow"]) {
            sendCommand(.DPAD_LEFT)
            return
        }
        
        if containsAny(text, ["right", "move right", "go right", "navigate right", "right arrow"]) {
            sendCommand(.DPAD_RIGHT)
            return
        }
        
        if containsAny(text, [
            "ok", "select", "confirm", "enter", "choose", "click", "tap",
            "press ok", "go ahead", "pick this", "select it"
        ]) {
            sendCommand(.OK)
            return
        }
        
        if containsAny(text, [
            "play", "resume", "start playing", "continue playing",
            "unpause", "let it play", "start the video", "play it", "continue"
        ]) {
            sendCommand(.PLAY)
            return
        }
        
        if containsAny(text, [
            "pause", "stop", "hold on", "pause it", "stop it",
            "freeze", "wait", "pause the video", "stop playing"
        ]) {
            sendCommand(.PAUSE)
            return
        }
        
        // =========================
        // ⚙️ SETTINGS
        // =========================
        if containsAny(text, [
            "settings", "setting", "open settings", "go to settings",
            "show settings", "menu settings", "tv settings", "options",
            "preferences", "configuration", "setup menu", "open menu settings"
        ]) {
            sendCommand(.SETTINGS)
            return
        }

        // =========================
        // ⏻ POWER
        // =========================
        if containsAny(text, [
            "power", "power off", "power on", "turn off", "turn on",
            "shut down", "switch off", "switch on", "turn off the tv",
            "turn on the tv", "power button", "restart tv", "power the tv",
            "kill the tv", "shut the tv off"
        ]) {
            sendCommand(.POWER)
            return
        }

        // =========================
        // 📺 CHANNEL UP
        // =========================
        if containsAny(text, [
            "channel up", "next channel", "channel plus", "go to next channel",
            "increase channel", "channel forward", "flip channel up",
            "change channel up", "up channel", "skip channel"
        ]) {
            sendCommand(.CHANNELUP)
            return
        }

        // =========================
        // 📺 CHANNEL DOWN
        // =========================
        if containsAny(text, [
            "channel down", "previous channel", "channel minus", "go to previous channel",
            "decrease channel", "channel backward", "flip channel down",
            "change channel down", "down channel", "back channel"
        ]) {
            sendCommand(.CHANNELDOWN)
            return
        }
        
        print("⚠️ Unknown command: \(text)")
    }
    
    // MARK: - Helper: Word-boundary safe matching (fixes substring false-positives)
    
    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        for keyword in keywords {
            if matchesWholeWord(text, keyword) {
                return true
            }
        }
        return false
    }
    
    private func matchesWholeWord(_ text: String, _ phrase: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        let pattern = "\\b\(escaped)\\b"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text.contains(phrase)
        }
        
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
    
    private func normalize(_ text: String) -> String {
        return text
            .lowercased()
            .replacingOccurrences(of: "please", with: "")
            .replacingOccurrences(of: "can you", with: "")
            .replacingOccurrences(of: "could you", with: "")
            .replacingOccurrences(of: "i want to", with: "")
            .replacingOccurrences(of: "let me", with: "")
            .replacingOccurrences(of: "show me", with: "")
            .replacingOccurrences(of: "open up", with: "open")
            .replacingOccurrences(of: "start up", with: "start")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - YouTube Voice Search
    @MainActor func searchYouTube(query: String) {
        guard let type = connectedTVType else {
            showSearchingSheet = true
            return
        }
        
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            launchApp(.youtube)
            return
        }
        let searchURL = "https://www.youtube.com/results?search_query=\(encoded)"
        
        switch type {
        case .ANDROID:
            (currentTVManager as? TR_AndroidControlManager)?.launchMediaOnRemoteScreen(url: searchURL)
            
        case .LG:
            if let lgManager = currentTVManager as? TR_LGControlManager {
                lgManager.launchYouTubeWithQuery(query)
            } else {
                launchApp(.youtube)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.typeTextOnTV(query)
                }
            }
            
        case .ROKU:
            if let rokuManager = currentTVManager as? TR_RokuControlManager {
//                rokuManager.launchYouTubeWithQuery(query)
            } else {
                launchApp(.youtube)
            }
            
        case .FIRE:
            (currentTVManager as? TR_FireControlManager)?.launchAppOnRemote(appId: TR_TVApps.youtube.fireTVAppId) { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    self?.typeTextOnTV(query)
                }
            }
            
        case .SAMSUNG:
            launchApp(.youtube)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self.typeTextOnTV(query)
            }
            
        case .AIRPLAY:
            break
        case .NONETV:
            showSearchingSheet = true
        }
        
        TR_AppUtils.instance.hapticFeedback()
    }
    
    private func extractSearchQuery(from text: String, app: String) -> String {
        var cleaned = text.lowercased()
        
        let appVariations: [String]
        if app == "youtube" {
            appVariations = ["youtube", "you tube", "utube"]
        } else if app == "netflix" {
            appVariations = ["netflix", "net flix"]
        } else if app.contains("prime") {
            appVariations = ["amazon prime video", "amazon prime", "prime video", "prime", "amazon"]
        } else {
            appVariations = [app]
        }
        
        // Remove app names with preceding prepositions like "in youtube", "on youtube", "from youtube", etc.
        for variation in appVariations {
            let phrases = [
                "and search for", "and search", "and play", "and look for", "and watch",
                "on \(variation)", "in \(variation)", "from \(variation)", "at \(variation)",
                "with \(variation)", "into \(variation)", "to \(variation)",
                "search on \(variation)", "search in \(variation)", "search \(variation)",
                "play on \(variation)", "play in \(variation)", "play \(variation)",
                "open on \(variation)", "open in \(variation)", "open \(variation)",
                "watch on \(variation)", "watch in \(variation)", "watch \(variation)",
                variation
            ]
            for phrase in phrases {
                if cleaned.contains(phrase) {
                    cleaned = cleaned.replacingOccurrences(of: phrase, with: " ")
                }
            }
        }
        
        // Remove command verbs
        let actionWords = [
            "search for", "search", "find", "look for", "look up",
            "start playing", "resume playing", "play", "watch",
            "open up", "open", "launch", "start", "show me", "show", "go to"
        ]
        for word in actionWords {
            cleaned = cleaned.replacingOccurrences(of: "\\b\(word)\\b", with: " ", options: .regularExpression)
        }
        
        let parts = cleaned.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractGeneralSearchQuery(from text: String) -> String {
        var cleaned = text.lowercased()
        let searchTriggers = [
            "search for", "search", "find", "look for", "look up",
            "start playing", "resume playing", "play", "watch",
            "open up", "open", "launch", "start", "show me", "show", "go to"
        ]
        for trigger in searchTriggers {
            cleaned = cleaned.replacingOccurrences(of: "\\b\(trigger)\\b", with: " ", options: .regularExpression)
        }
        let parts = cleaned.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func typeTextOnTV(_ text: String) {
        if isMirroringActive { return }
        guard let type = connectedTVType else { return }
        
        switch type {
        case .ANDROID:
            (currentTVManager as? TR_AndroidControlManager)?.sendText(text: text)
        case .FIRE:
            (currentTVManager as? TR_FireControlManager)?.sendSearchTextInput(action: text) { _ in }
        case .ROKU:
            (currentTVManager as? TR_RokuControlManager)?.sendKeyboardInput(text)
        case .LG:
            (currentTVManager as? TR_LGControlManager)?.keyboard(input: text)
        case .SAMSUNG:
            (currentTVManager as? TR_SamsungControlManager)?.sendText(text)
        default:
            break
        }
    }
}
