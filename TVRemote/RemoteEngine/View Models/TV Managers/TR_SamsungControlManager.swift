//
//  SamsungTVManager.swift
//  TR_TV Remote
//
//  Created by Parthiv Akbari on 09/09/2025.
//

import Foundation
import Combine

public struct TR_TVInstalledApp: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let type: Int?
    public let version: String?
    
    // Maps cleanly to your existing UI-facing TR_TVApp model
    public var toTVApp: TR_TVApp {
        return TR_TVApp(id: id, name: name)
    }
}

struct TR_TVInstalledAppsResponse: Codable {
    let installedApp: [TR_TVInstalledApp]
}

class TR_SamsungControlManager: TR_TVCommanderDelegate, ObservableObject {
    var deviceIP = ""
    var authToken: TR_TVAuthToken?
    var tvWakeOnLANDevice = TR_TVWakeOnLANDevice(mac: "")
    var remoteCommandKey = TR_TVRemoteCommand.TR_Params.TR_ControlKey.mute
    var tvApp: TR_TVApp = .netflix()
    var appStatus: TR_TVAppStatus?
    private(set) var isConnecting = false
    @Published var isConnected = false
    @Published var authStatus = TR_TVAuthStatus.none
    private(set) var isDisconnecting = false
    private(set) var tvIsWakingOnLAN = false
    private(set) var tvError: Error?
    private var commander: TR_TVCommander?
    private let appManager: TR_TVAppManaging
    
    @Published var installedApps: [TR_TVApp] = []
    @Published var isLoadingApps: Bool = false
    @Published var availablePorts: [TR_TVApp] = [
            TR_TVApp(id: "KEY_HDMI1", name: "HDMI 1"),
            TR_TVApp(id: "KEY_HDMI2", name: "HDMI 2"),
            TR_TVApp(id: "KEY_HDMI3", name: "HDMI 3"),
            TR_TVApp(id: "KEY_HDMI4", name: "HDMI 4"),
            TR_TVApp(id: "KEY_SOURCE", name: "Switch Source")
        ]
    
    private var webSocket: URLSessionWebSocketTask?
    private var webSocketSession: URLSession?
    private var isSocketConnected = false
    private let unsafeDelegate = TR_UnsafeWebSocketDelegate()
    
    init() {
        appManager = TR_TVAppManager()
    }
    
    var ControlsEnabled: Bool { isConnected && authStatus == .allowed }
    var DisconnectEnabled: Bool { isConnected }
    var WakeOnLANEnabled: Bool { !tvIsWakingOnLAN }
    var TvApps: [TR_TVApp] {
        installedApps.isEmpty ? TR_TVApp.allApps() : installedApps
    }
    var ConnectEnabled: Bool { !isConnecting && !isConnected }
    var AuthTokenEntryDisabled: Bool { commander != nil || isConnecting || isConnected || isDisconnecting }
    
    var RemoteCommandKeys: [TR_TVRemoteCommand.TR_Params.TR_ControlKey] {
        [ .powerOff, .up, .down, .left, .right, .enter, .returnKey, .channelList, .menu, .home, .play, .previous, .next,
          .pause, .exit, .source, .guide, .tools, .info, .colorRed, .colorGreen, .colorYellow, .colorBlue, .key3D,
          .volumeUp, .volumeDown, .mute, .number0, .number1, .number2, .number3, .number4, .number5, .number6,
          .number7, .number8, .number9, .sourceHDMI, .contents,
        ]
    }
    
    func UserTappedConnect(ip: String) {
        self.deviceIP = ip
        fetchAndSaveMacFromREST(ip: ip)
        if commander != nil {
            RemoveTVCommander()
        }
        SetupTVCommander(ip: ip)
        guard let commander else { return }
        isConnecting = true
        commander.connectToTV()
    }
    
    func fetchAndSaveMacFromREST(ip: String) {
        guard let url = URL(string: "http://\(ip):8001/api/v2/") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.5
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data = data, let text = String(data: data, encoding: .utf8) else { return }
            self?.extractMac(from: text)
        }.resume()
    }
    
    func UserTappedDismissError() { tvError = nil }
    
    func TR_KeyPress(keyCode: TR_TVRemoteCommand.TR_Params.TR_ControlKey) {
        commander?.sendRemoteCommand(key: keyCode)
    }
    
    func sendText(_ text: String) {
        commander?.sendInputString(text)
    }
    
    // Persisted token store: saves across app restarts in UserDefaults
    private static let tokenDefaultsKey = "samsung_tv_auth_tokens"
    
    static func getSavedToken(for ip: String) -> String? {
        if let tokens = UserDefaults.standard.dictionary(forKey: tokenDefaultsKey) as? [String: String],
           let token = tokens[ip], !token.isEmpty {
            return token
        }
        return UserDefaults.standard.string(forKey: "samsung_tv_token_\(ip)")
    }
    
    static func saveToken(_ token: String, for ip: String) {
        guard !ip.isEmpty, !token.isEmpty else { return }
        var tokens = (UserDefaults.standard.dictionary(forKey: tokenDefaultsKey) as? [String: String]) ?? [:]
        tokens[ip] = token
        UserDefaults.standard.set(tokens, forKey: tokenDefaultsKey)
        UserDefaults.standard.set(token, forKey: "samsung_tv_token_\(ip)")
    }
    
    static func removeToken(for ip: String) {
        guard !ip.isEmpty else { return }
        var tokens = (UserDefaults.standard.dictionary(forKey: tokenDefaultsKey) as? [String: String]) ?? [:]
        tokens.removeValue(forKey: ip)
        UserDefaults.standard.set(tokens, forKey: tokenDefaultsKey)
        UserDefaults.standard.removeObject(forKey: "samsung_tv_token_\(ip)")
    }
    
    func UserTappedSend() { commander?.sendRemoteCommand(key: remoteCommandKey) }
    
    func UserTappedDisconnect() {
        isDisconnecting = true
        commander?.delegate = nil
        commander?.disconnectFromTV()
        
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        webSocketSession?.invalidateAndCancel()
        webSocketSession = nil
        
        RemoveTVCommander()
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.isConnecting = false
            self.isDisconnecting = false
            self.installedApps = []
        }
    }
    
    func getBroadcastAddress(from ip: String) -> String {
        var components = ip.split(separator: ".").map { String($0) }
        guard components.count == 4 else { return "255.255.255.255" }
        components[3] = "255"
        return components.joined(separator: ".")
    }
    
    private func storedMac(for ip: String) -> String? {
        UserDefaults.standard.string(forKey: "tv_mac_\(ip)") ?? UserDefaults.standard.string(forKey: "tv_last_samsung_mac")
    }

    private func saveMac(_ mac: String, for ip: String) {
        UserDefaults.standard.set(mac, forKey: "tv_mac_\(ip)")
        UserDefaults.standard.set(mac, forKey: "tv_last_samsung_mac")
    }
    
    private func receiveMessages() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                
                if case let .string(text) = message {
                    print("📩 Samsung WS:", text)
                    
                    // ✅ Detect socket connected
                    if text.contains("ms.channel.connect") {
                        self?.isSocketConnected = true
                        print("✅ WebSocket AUTH SUCCESS")
                    }
                    
                    // 🔥 NEW: Extract MAC dynamically
                    self?.extractMac(from: text)
                }
                
                self?.receiveMessages()
                
            case .failure(let error):
                print("❌ WS Error:", error)
            }
        }
    }
    
    private func extractMac(from text: String) {
        
        guard let data = text.data(using: .utf8) else { return }
        
        // 🔍 Try raw string fallback (IMPORTANT)
        if let mac = extractMacFromRawString(text) {
            print("✅ MAC FOUND (raw):", mac)
            saveMac(mac, for: deviceIP)
            return
        }
        
        // 🔍 Try JSON parsing
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        // Case 1: data.device.wifiMac
        if let dataObj = json["data"] as? [String: Any],
           let device = dataObj["device"] as? [String: Any],
           let mac = device["wifiMac"] as? String {
            
            print("✅ MAC FOUND (device.wifiMac):", mac)
            saveMac(mac, for: deviceIP)
            return
        }
        
        // Case 2: data.clients[].attributes.mac
        if let dataObj = json["data"] as? [String: Any],
           let clients = dataObj["clients"] as? [[String: Any]],
           let attributes = clients.first?["attributes"] as? [String: Any],
           let mac = attributes["mac"] as? String {
            
            print("✅ MAC FOUND (clients):", mac)
            saveMac(mac, for: deviceIP)
            return
        }
    }
    
    private func extractMacFromRawString(_ text: String) -> String? {
        
        let pattern = "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}"
        
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            
            return String(text[range])
        }
        
        return nil
    }
    
    func UserTappedWakeOnLAN() {
        guard !deviceIP.isEmpty else {
            print("❌ Missing IP")
            return
        }
        
        let mac = storedMac(for: deviceIP) ?? UserDefaults.standard.string(forKey: "tv_last_samsung_mac") ?? ""
        guard !mac.isEmpty else {
            print("❌ MAC not available. Connect to TR_TV once first.")
            tvError = NSError(domain: "WOL", code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "Connect to TR_TV once to fetch MAC address"])
            return
        }
        
        let broadcast = getBroadcastAddress(from: deviceIP)
        
        let device = TR_TVWakeOnLANDevice(
            mac: mac,
            broadcast: broadcast,
            port: 9
        )
        
        print("🚀 WOL → MAC: \(mac), IP: \(deviceIP), Broadcast: \(broadcast)")
        
        tvIsWakingOnLAN = true
        
        // Send multiple magic packets across standard ports
        for i in 0..<5 {
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(i) * 0.25) {
                TR_TVCommander.wakeOnLANSamsung(device: device, queue: .global()) { [weak self] error in
                    DispatchQueue.main.async {
                        self?.tvIsWakingOnLAN = false
                        if let error = error {
                            self?.tvError = error
                        }
                    }
                }
            }
        }
    }
    
    func UserTappedAppStatus() {
        Task {
            await FetchAppStatus()
        }
    }
    
    func UserTappedLaunchApp(tvapp: TR_TVApp)  {
        guard isConnected else { return }
        
        switch tvapp.id {
        // 🎙️ Native System Bixby Core Trigger
        case "com.samsung.bixby.tv":
            break
            
        // 🏠 Native Core SmartThings Application Frame
        case "3201710015016", "111299000752", "3201910019378":
            Task {
                await LaunchApplication(app: tvapp)
            }
        // 📺 Native Core Live TR_TV / Samsung TR_TV Plus Layer
        case "com.samsung.dtv.tvplus", "3201501000919":
            TR_KeyPress(keyCode: .channelList)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.TR_KeyPress(keyCode: .returnKey)
            }
        default:
            // Third-party streaming applications (Netflix, Prime, Hotstar, Sony LIV, Browser)
            // will continue using your standard working HTTP endpoint.
            Task {
                await LaunchApplication(app: tvapp)
            }
        }
    }
    
    func UserTappedCustomApp(tvapp: TR_TVApp) {
        Task {
            await LaunchApplication(app: tvapp)
        }
    }
    
    private func SetupTVCommander(ip: String) {
        guard commander == nil else { return }
        
        // ✅ LOAD PERSISTED TOKEN (persists across app restarts)
        let savedToken = TR_SamsungControlManager.getSavedToken(for: ip)
        print("🔑 SetupTVCommander for IP: \(ip), saved token: \(savedToken ?? "nil")")
        
        do {
            commander = try TR_TVCommander(
                tvIPAddress: ip,
                appName: TR_AppStrings.appName,
                authToken: savedToken // ✅ PASS PERSISTED TOKEN HERE
            )
            commander?.delegate = self
        } catch {
            tvError = error
        }
    }
    
    private func RemoveTVCommander() {
        commander = nil
    }
    
    private func FetchAppStatus() async {
        do {
            appStatus = try await appManager.fetchStatus(for: tvApp, tvIPAddress: deviceIP)
        } catch {
            tvError = error
        }
    }
    
    private func LaunchApplication(app: TR_TVApp) async {
        do {
            try await appManager.launch(tvApp: app, tvIPAddress: deviceIP)
        } catch {
            tvError = error
        }
    }
    
    func tvCommanderDidConnect(_ tvCommander: TR_TVCommander) {
        DispatchQueue.main.async {
            self.isConnecting = false
            self.isConnected = true
        }
    }
    
    func tvCommanderDidDisconnect(_ tvCommander: TR_TVCommander) {
        DispatchQueue.main.async {
            self.isDisconnecting = false
            self.isConnected = false
            
            // ✅ ADD THIS
            self.webSocket?.cancel(with: .goingAway, reason: nil)
            self.webSocket = nil
            self.webSocketSession?.invalidateAndCancel()
            self.webSocketSession = nil
            
            self.RemoveTVCommander()
        }
    }
    
    func tvCommander(_ tvCommander: TR_TVCommander, didUpdateAuthState authStatus: TR_TVAuthStatus) {
        DispatchQueue.main.async {
            self.authStatus = authStatus
            self.authToken = tvCommander.tvConfig.token ?? TR_SamsungControlManager.getSavedToken(for: self.deviceIP)
            
            print("🔐 Auth TR_Status:", authStatus)
            print("🔑 Token:", self.authToken ?? "nil")
            
            // ✅ ONLY connect when fully authorized
            if authStatus == .allowed {
                print("✅ AUTH COMPLETE → Connecting Mouse Socket")
                // ✅ SAVE PERSISTED TOKEN HERE
                if let token = self.authToken, !token.isEmpty {
                    TR_SamsungControlManager.saveToken(token, for: self.deviceIP)
                }
                
                self.connectMouseSocket()
                
                // 🔥 NEW: Trigger the app fetching operation smoothly off-thread
                Task {
                    await self.fetchAndPopulateInstalledApps()
                }
            }
            
            if authStatus == .denied {
                // ❌ REMOVE INVALID TOKEN
                TR_SamsungControlManager.removeToken(for: self.deviceIP)
                print("🗑️ Token removed (denied)")
            }
        }
    }
    
    // 🔥 NEW
    @MainActor
    private func fetchAndPopulateInstalledApps() async {
        self.isLoadingApps = true
        do {
            let apps = try await appManager.fetchInstalledApps(tvIPAddress: deviceIP)
            self.installedApps = apps
            self.isLoadingApps = false
            print("Successfully loaded \(apps.count) installed apps from Samsung TR_TV")
        } catch {
            print("⚠️ Failed to pull installed apps from TR_TV: \(error.localizedDescription)")
            self.installedApps = []
            self.isLoadingApps = false
        }
    }
    
    func switchToPort(_ port: TR_TVApp) {
        guard isConnected else { return }
        switch port.id {
        case "KEY_HDMI1":
            commander?.sendRemoteCommand(key: .sourceHDMI)
        case "KEY_HDMI2", "KEY_HDMI3", "KEY_HDMI4", "KEY_SOURCE":
            commander?.sendRemoteCommand(key: .source)
        default:
            Task { await LaunchApplication(app: port) }
        }
    }
    
    func tvCommander(_ tvCommander: TR_TVCommander, didWriteRemoteCommand command: TR_TVRemoteCommand) {
    }
    
    func tvCommander(_ tvCommander: TR_TVCommander, didEncounterError error: TR_TVCommanderError) {
        tvError = error
    }
    
    private func connectMouseSocket() {
        let tokenToUse = authToken ?? TR_SamsungControlManager.getSavedToken(for: deviceIP)
        guard let token = tokenToUse, !token.isEmpty else {
            print("❌ Token not available yet")
            return
        }
        
        let urlString = "wss://\(deviceIP):8002/api/v2/channels/samsung.remote.control?name=U2FtU3VuZw==&token=\(token)"
        
        guard let url = URL(string: urlString) else { return }
        
        let config = URLSessionConfiguration.default
        webSocketSession = URLSession(configuration: config,
                                      delegate: unsafeDelegate,
                                      delegateQueue: OperationQueue())
        
        webSocket = webSocketSession?.webSocketTask(with: url)
        webSocket?.resume()
        
        receiveMessages()
        
        print("✅ Samsung Mouse WebSocket Connected")
    }
    
    func mouseMove(dx: Float, dy: Float) {
        guard isConnected else { return }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        
        let json: [String: Any] = [
            "method": "ms.remote.control",
            "params": [
                "Cmd": "Move",
                "Position": [
                    "Time": "\(timestamp)",
                    "x": Int(dx),
                    "y": Int(dy)
                ],
                "TypeOfRemote": "ProcessMouseDevice"
            ]
        ]
        
        send(json: json)
    }
    
    func mouseClick() {
        guard isConnected else { return }
        
        let json: [String: Any] = [
            "method": "ms.remote.control",
            "params": [
                "Cmd": "LeftClick",
                "TypeOfRemote": "ProcessMouseDevice"
            ]
        ]
        
        send(json: json)
    }
    
    private func send(json: [String: Any]) {
        guard let ws = webSocket, isSocketConnected else {
            print("⚠️ Socket not ready / not authorized")
            return
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: json),
           let string = String(data: data, encoding: .utf8) {
            
            ws.send(.string(string)) { error in
                if let error = error {
                    print("❌ Send error:", error)
                }
            }
        }
    }
}

class TR_UnsafeWebSocketDelegate: NSObject, URLSessionDelegate {
    
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // ✅ Accept all certificates (for local TR_TV)
        if let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
