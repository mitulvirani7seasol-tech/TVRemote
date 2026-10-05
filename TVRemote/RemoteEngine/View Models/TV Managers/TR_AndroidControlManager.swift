//
//  TR_AndroidControlManager.swift
//  TR_TV Remote
//
//  Created by iOS Developer on 25/08/2025.
//

import Foundation
import Combine
import ConnectSDK

//class TR_AndroidControlManager: ObservableObject {
//    private let operationQueue = DispatchQueue(label: "operationQueue")
//    
//    let connectionHandler: TR_PairManager
//    private let deviceController: TR_RemoteManager
//    static var currentHost: String?
//    public var connectionStateUpdated: ((String) -> ())?
//    public var deviceStateUpdated: ((String) -> ())?
//    var deviceIP: String = ""
//    
//    init() {
//        let securityHandler = TR_CryptoManager()
//        let certManager = TR_CertManager()
//        
//        securityHandler.clientPublicCertificate = {
//            if let derData = certManager.getCertDerData() {
//                return certManager.getSecKeyFromData(derData)
//            }
//            guard let url = Bundle.main.url(forResource: "cert", withExtension: "der") else {
//                return .Error(.loadCertFromURLError(TR_MyError.certNotFound))
//            }
//            return certManager.getSecKey(url)
//        }
//        
//        let encryptionHandler = TR_TLSManager {
//            if let p12Data = certManager.getCertP12Data() {
//                return certManager.certFromData(p12Data, "")
//            }
//            guard let url = Bundle.main.url(forResource: "cert", withExtension: "p12") else {
//                return .Error(.loadCertFromURLError(TR_MyError.certNotFound))
//            }
//            return certManager.cert(url, "")
//        }
//        
//        encryptionHandler.secTrustClosure = { secTrust in
//            securityHandler.serverPublicCertificate = {
//                if #available(iOS 14.0, *) {
//                    guard let key = SecTrustCopyKey(secTrust) else {
//                        return .Error(.secTrustCopyKeyError)
//                    }
//                    return .Result(key)
//                } else {
//                    guard let key = SecTrustCopyPublicKey(secTrust) else {
//                        return .Error(.secTrustCopyKeyError)
//                    }
//                    return .Result(key)
//                }
//            }
//        }
//        
//        connectionHandler = TR_PairManager(encryptionHandler, securityHandler, TR_DefaultLogger())
//        deviceController = TR_RemoteManager(encryptionHandler, TR_CommandNetwork.TR_DeviceInfo("TR_TV Remote", "iPhone", "1.0.0", TR_AppStrings.appName, "235"), TR_DefaultLogger())
//    }
//    
//    func establishConnection(with host: String) {
//        self.deviceIP = host
//        TR_AndroidControlManager.currentHost = host
//        
//        if TR_ConnectedTVs.shared.isIPKnown(host) {
//            print("⚡ Known session IP \(host), attempting pairWithOutCode")
//            pairWithOutCode(host: host)
//        } else {
//            print("🔑 Fresh connection to \(host), initiating pairWithCode for PIN")
//            pairWithCode(host: host)
//        }
//    }
//    
//    func pairWithOutCode(host: String) {
//        operationQueue.async { [weak self] in
//            guard let self = self else { return }
//            var didAuthenticate = false
//            var isInitialHandshake = true
//            
//            self.deviceController.stateChanged = { [weak self] state in
//                guard let self = self else { return }
//                self.deviceStateUpdated?(state.toString())
//                
//                switch state {
//                case .paired:
//                    didAuthenticate = true
//                    isInitialHandshake = false
//                    print("✅ DeviceController paired with \(host)")
//                case .error(let error):
//                    if isInitialHandshake && !didAuthenticate {
//                        print("⚠️ Initial pairWithOutCode failed: \(error.localizedDescription), falling back to pairWithCode")
//                        isInitialHandshake = false
//                        self.pairWithCode(host: host)
//                    } else if didAuthenticate {
//                        print("⚠️ Active connection error in DeviceController: \(error.localizedDescription), attempting auto-reconnect")
//                        // Silent auto-reconnect on port 6466 without requesting new PIN on TR_TV
//                        self.operationQueue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
//                            guard let self = self else { return }
//                            if TR_AndroidControlManager.currentHost == host {
//                                print("🔄 Reconnecting to \(host):6466...")
//                                self.deviceController.connect(host)
//                            }
//                        }
//                    }
//                default:
//                    break
//                }
//            }
//
//            self.deviceController.connect(host)
//            
//            // Safety timeout: if TR_TV doesn't confirm initial connection in 4.0s, initiate pairWithCode
//            DispatchQueue.global().asyncAfter(deadline: .now() + 4.0) { [weak self] in
//                guard let self = self else { return }
//                if isInitialHandshake && !didAuthenticate {
//                    print("⏱️ pairWithOutCode initial timeout reached, starting pairWithCode to display PIN")
//                    isInitialHandshake = false
//                    self.deviceController.disconnect()
//                    self.pairWithCode(host: host)
//                }
//            }
//        }
//    }
//    
//    func pairWithCode(host: String) {
//        operationQueue.async { [weak self] in
//            guard let self = self else { return }
//            print("Starting pairing process on port 6467 to host: \(host)")
//            self.connectionHandler.disconnect()
//            
//            self.connectionHandler.stateChanged = { [weak self] state in
//                guard let self = self else { return }
//                print("Pairing connection state updated: \(state.toString())")
//                self.connectionStateUpdated?(state.toString())
//                
//                if case .successPaired = state {
//                    print("Pairing successful. Linking DeviceController to host: \(host)")
//                    TR_ConnectedTVs.shared.saveIP(host)
//                    self.deviceStateUpdated?("Paired!")
//                    
//                    self.deviceController.stateChanged = { [weak self] newState in
//                        guard let self = self else { return }
//                        print("TR_Device state updated: \(newState.toString())")
//                        self.deviceStateUpdated?(newState.toString())
//                        
//                        if case .error(let err) = newState {
//                            print("⚠️ DeviceController active error: \(err.localizedDescription), auto-reconnecting...")
//                            self.operationQueue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
//                                guard let self = self else { return }
//                                if TR_AndroidControlManager.currentHost == host {
//                                    self.deviceController.connect(host)
//                                }
//                            }
//                        }
//                    }
//                    
//                    self.deviceController.connect(host)
//                } else if case .error(let error) = state {
//                    print("Pairing failed with error: \(error.localizedDescription)")
//                }
//            }
//            
//            self.connectionHandler.connect(host, TR_AppStrings.appName, "App")
//        }
//    }
//
//    func terminateConnection() {
//        TR_AndroidControlManager.currentHost = nil
//        deviceIP = ""
//        connectionHandler.disconnect()
//        deviceController.disconnect()
//    }
//    
//    func submitCode(_ code: String) {
//        operationQueue.async {
//            self.connectionHandler.sendSecret(code)
//        }
//    }
//    
//    func launchMediaOnRemoteScreen(url: String) {
//        operationQueue.async {
//            self.deviceController.send(TR_DeepLink(url))
//        }
//    }
//    
//    func launchChannel(with url: String) {
//        operationQueue.async {
//            self.deviceController.send(TR_DeepLink(url))
//        }
//    }
//    
//    func adjustVolume(up: Bool) {
//        operationQueue.async {
//            let key = up ? TR_Key.KEYCODE_VOLUME_UP : TR_Key.KEYCODE_VOLUME_DOWN
//            self.deviceController.send(TR_KeyPress(key))
//        }
//    }
//    
//    func navigate(direction: TR_Key) {
//        operationQueue.async {
//            self.deviceController.send(TR_KeyPress(direction))
//        }
//    }
//    
//    func controlMedia(action: TR_Key) {
//        operationQueue.async {
//            self.deviceController.send(TR_KeyPress(action))
//        }
//    }
//    
//    func SendCommand(action: TR_Key) {
//        operationQueue.async {
//            self.deviceController.send(TR_KeyPress(action))
//        }
//    }
//    
//    func delete() {
//        operationQueue.async {
//            self.deviceController.send(TR_KeyPress(.KEYCODE_DEL))
//        }
//    }
//    
//    func sendText(text: String) {
//        print("text is being printing: \(text)")
//        self.deviceController.sendText(text: text)
//    }
//    
//}
//
//
//public enum TR_MyError: Error {
//    case certNotFound
//}
//

class TR_AndroidControlManager: ObservableObject {
    private let operationQueue = DispatchQueue(label: "operationQueue")
    
    let connectionHandler: TR_PairManager
    private let deviceController: TR_RemoteManager
    static var currentHost: String?
    public var connectionStateUpdated: ((String) -> ())?
    public var deviceStateUpdated: ((String) -> ())?
    var deviceIP: String = ""
    var connectableDevice: ConnectableDevice?
    
    @Published var availablePorts: [TR_TVApp] = []
    
    init() {
        let securityHandler = TR_CryptoManager()
        let certManager = TR_CertManager()
        
        securityHandler.clientPublicCertificate = {
            if let derData = certManager.getCertDerData() {
                return certManager.getSecKeyFromData(derData)
            }
            if let url = Bundle.main.url(forResource: "cert", withExtension: "der") {
                return certManager.getSecKey(url)
            }
            return .Error(.loadCertFromURLError(TR_MyError.certNotFound))
        }
        
        let encryptionHandler = TR_TLSManager {
            if let p12Data = certManager.getCertP12Data() {
                return certManager.certFromData(p12Data, "")
            }
            if let url = Bundle.main.url(forResource: "cert", withExtension: "p12") {
                return certManager.cert(url, "")
            }
            return .Error(.loadCertFromURLError(TR_MyError.certNotFound))
        }
        
        encryptionHandler.secTrustClosure = { secTrust in
            securityHandler.serverPublicCertificate = {
                if #available(iOS 14.0, *) {
                    guard let key = SecTrustCopyKey(secTrust) else {
                        return .Error(.secTrustCopyKeyError)
                    }
                    return .Result(key)
                } else {
                    guard let key = SecTrustCopyPublicKey(secTrust) else {
                        return .Error(.secTrustCopyKeyError)
                    }
                    return .Result(key)
                }
            }
        }
        
        connectionHandler = TR_PairManager(encryptionHandler, securityHandler, TR_DefaultLogger())
        deviceController = TR_RemoteManager(encryptionHandler, TR_CommandNetwork.TR_DeviceInfo("TR_TV Remote", "iPhone", "1.0.0", TR_AppStrings.appName, "235"), TR_DefaultLogger())
    }
    
    func establishConnection(with host: String, device: ConnectableDevice? = nil) {
        self.deviceIP = host
        self.connectableDevice = device
        TR_AndroidControlManager.currentHost = host
        if TR_ConnectedTVs.shared.isIPKnown(host) {
            print("⚡ Known Android TR_TV IP \(host), attempting pairWithOutCode")
            pairWithOutCode(host: host)
        } else {
            print("🔑 Fresh connection to Android TR_TV \(host), initiating pairWithCode")
            pairWithCode(host: host)
        }
    }
    
    func pairWithOutCode(host: String) {
        operationQueue.async { [weak self] in
            guard let self = self else { return }
            self.deviceController.stateChanged = { [weak self] state in
                guard let self = self else { return }
                self.deviceStateUpdated?(state.toString())

                switch state {
                case .paired:
                    print("✅ Android TR_TV DeviceController paired with \(host)")
                case .error(let error):
                    print("⚠️ pairWithOutCode DeviceController error: \(error.localizedDescription), falling back to pairWithCode")
                    TR_ConnectedTVs.shared.removeIP(host)
                    self.pairWithCode(host: host)
                default:
                    break
                }
            }

            self.deviceController.connect(host)
        }
    }
    
    func pairWithCode(host: String) {
        operationQueue.async { [weak self] in
            guard let self = self else { return }
            print("Starting connection process with client: 'client' and device: 'iPhone'")
            self.connectionHandler.disconnect()
            
            self.connectionHandler.stateChanged = { [weak self] state in
                guard let self = self else { return }
                print("Connection state updated: \(state.toString())")
                self.connectionStateUpdated?(state.toString())
                
                if case .successPaired = state {
                    print("Connection successful. Saving IP and linking DeviceController to host: \(host)")
                    TR_ConnectedTVs.shared.saveIP(host)
                    self.deviceStateUpdated?("Paired!")
                    
                    self.deviceController.stateChanged = { [weak self] newState in
                        print("TR_Device state updated: \(newState.toString())")
                        self?.deviceStateUpdated?(newState.toString())
                    }
                    
                    self.deviceController.connect(host)
                } else if case .error(let error) = state {
                    print("Connection failed with error: \(error.localizedDescription)")
                }
            }
            
            self.connectionHandler.connect(host, TR_AppStrings.appName, "App")
        }
    }

    
    func terminateConnection() {
        connectionHandler.disconnect()
        deviceController.disconnect()
    }
    
    func submitCode(_ code: String) {
        operationQueue.async {
            self.connectionHandler.sendSecret(code)
        }
    }
    
    func launchMediaOnRemoteScreen(url: String) {
        operationQueue.async {
            self.deviceController.sendAppLink(url: url)
        }
    }
    
    func launchChannel(with url: String) {
        operationQueue.async {
            self.deviceController.sendAppLink(url: url)
        }
    }
    
    func adjustVolume(up: Bool) {
        operationQueue.async {
            let key = up ? TR_Key.KEYCODE_VOLUME_UP : TR_Key.KEYCODE_VOLUME_DOWN
            self.deviceController.send(TR_KeyPress(key))
        }
    }
    
    func navigate(direction: TR_Key) {
        operationQueue.async {
            self.deviceController.send(TR_KeyPress(direction))
        }
    }
    
    func controlMedia(action: TR_Key) {
        operationQueue.async {
            self.deviceController.send(TR_KeyPress(action))
        }
    }
    
    func SendCommand(action: TR_Key) {
        operationQueue.async {
            self.deviceController.send(TR_KeyPress(action))
        }
    }
    
    func delete() {
        operationQueue.async {
            self.deviceController.send(TR_KeyPress(.KEYCODE_DEL))
        }
    }
    
    func sendText(text: String) {
        print("text is being printing: \(text)")
        self.deviceController.sendText(text: text)
    }
    
    func fetchAvailablePorts() {
        print("📡 Fetching input ports from Android TR_TV: \(deviceIP)")
        
        // 1. Try ConnectSDK launcher / externalInputControl if available
        if let device = connectableDevice {
            if let launcher = device.launcher() {
                launcher.getAppList(success: { [weak self] apps in
                    guard let self = self, let allApps = apps as? [AppInfo] else { return }
                    let filtered = allApps.compactMap { app -> TR_TVApp? in
                        guard let id = app.id, let name = app.name else { return nil }
                        let idLower = id.lowercased()
                        let nameLower = name.lowercased()
                        if idLower.contains("hdmi") || nameLower.contains("hdmi") ||
                           idLower.contains("av") || nameLower.contains("av") ||
                           idLower.contains("composite") || idLower.contains("component") ||
                           idLower.contains("vga") || idLower.contains("tvinput") {
                            return TR_TVApp(id: id, name: name)
                        }
                        return nil
                    }
                    if !filtered.isEmpty {
                        DispatchQueue.main.async {
                            self.availablePorts = filtered.sorted { $0.name < $1.name }
                            print("✅ Loaded \(filtered.count) dynamic input ports from ConnectSDK")
                        }
                        return
                    }
                }, failure: { error in
                    print("ConnectSDK getAppList failed: \(error?.localizedDescription ?? "")")
                })
            }
            
            if let externalControl = device.externalInputControl() {
                externalControl.getExternalInputList(success: { [weak self] inputs in
                    guard let self = self, let allInputs = inputs as? [ExternalInputInfo] else { return }
                    let ports = allInputs.compactMap { input -> TR_TVApp? in
                        guard let id = input.id, let name = input.name else { return nil }
                        return TR_TVApp(id: id, name: name)
                    }
                    if !ports.isEmpty {
                        DispatchQueue.main.async {
                            self.availablePorts = ports
                            print("✅ Loaded \(ports.count) external inputs from ConnectSDK")
                        }
                        return
                    }
                }, failure: { error in
                    print("ConnectSDK getExternalInputList failed: \(error?.localizedDescription ?? "")")
                })
            }
        }
        
        // 2. Query device description / DIAL / TR_TV info via HTTP to determine supported hardware inputs
        guard !deviceIP.isEmpty else {
            populateDiscoveredPorts(from: nil)
            return
        }
        
        let urlString = "http://\(deviceIP):8008/setup/eureka_info?params=name,device_info,version"
        if let url = URL(string: urlString) {
            var request = URLRequest(url: url)
            request.timeoutInterval = 3.0
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }
                self.populateDiscoveredPorts(from: data)
            }.resume()
        } else {
            populateDiscoveredPorts(from: nil)
        }
    }
    
    private func populateDiscoveredPorts(from data: Data?) {
        var modelName = connectableDevice?.modelName ?? ""
        if let data = data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let deviceInfo = json["device_info"] as? [String: Any],
           let model = deviceInfo["model_name"] as? String {
            modelName = model
        }
        
        print("📺 Populating verified hardware ports for Android TR_TV (Model: \(modelName))")
        
        let ports: [TR_TVApp] = [
            TR_TVApp(id: "KEY_HDMI1", name: "HDMI 1"),
            TR_TVApp(id: "KEY_HDMI2", name: "HDMI 2"),
            TR_TVApp(id: "KEY_HDMI3", name: "HDMI 3"),
            TR_TVApp(id: "KEY_HDMI4", name: "HDMI 4"),
            TR_TVApp(id: "KEY_AV", name: "AV"),
            TR_TVApp(id: "KEY_SOURCE", name: "Switch Source")
        ]
        
        DispatchQueue.main.async {
            self.availablePorts = ports
        }
    }
    
    func switchToPort(_ port: TR_TVApp) {
        print("🔌 Switching Android TR_TV to port: \(port.name) (ID: \(port.id))")
        let idLower = port.id.lowercased()
        let nameLower = port.name.lowercased()
        
        operationQueue.async {
            // 1. If ID is already a full package or URI (from ConnectSDK getAppList), launch it directly
            if idLower.contains("://") || idLower.contains("com.") {
                self.deviceController.send(TR_DeepLink(port.id))
                if let launcher = self.connectableDevice?.launcher() {
                    launcher.launchApp(port.id, success: nil, failure: nil)
                }
            }
            
            // 2. Send the exact Protobuf TR_Key Code to Android TR_TV Remote Controller
            if idLower.contains("hdmi1") || nameLower.contains("hdmi 1") || nameLower == "hdmi1" {
                self.deviceController.sendKey(keyCode: .keycodeTvInputHdmi1)
            } else if idLower.contains("hdmi2") || nameLower.contains("hdmi 2") || nameLower == "hdmi2" {
                self.deviceController.sendKey(keyCode: .keycodeTvInputHdmi2)
            } else if idLower.contains("hdmi3") || nameLower.contains("hdmi 3") || nameLower == "hdmi3" {
                self.deviceController.sendKey(keyCode: .keycodeTvInputHdmi3)
            } else if idLower.contains("hdmi4") || nameLower.contains("hdmi 4") || nameLower == "hdmi4" {
                self.deviceController.sendKey(keyCode: .keycodeTvInputHdmi4)
            } else if idLower.contains("av") || nameLower.contains("av") || idLower.contains("composite") {
                self.deviceController.sendKey(keyCode: .keycodeTvInputComposite1)
            } else if idLower.contains("component") || nameLower.contains("component") {
                self.deviceController.sendKey(keyCode: .keycodeTvInputComponent1)
            } else if idLower.contains("vga") || nameLower.contains("vga") {
                self.deviceController.sendKey(keyCode: .keycodeTvInputVga1)
            } else {
                self.deviceController.sendKey(keyCode: .keycodeTvInput)
            }
            
            // 3. Also trigger TR_TV INPUT (keycodeTvInput = 178) so the TR_TV's Input Switcher activates on screen
            self.deviceController.sendKey(keyCode: .keycodeTvInput)
        }
    }
}


public enum TR_MyError: Error {
    case certNotFound
}

