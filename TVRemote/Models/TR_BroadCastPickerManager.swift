//
//  BroadCastManager.swift
//  ClarioMirror
//
//  Created by Vivek Rakholiya on 06/05/26.
//

import Foundation
import Combine
import GoogleCast

class TR_BroadCastPickerManager: NSObject, ObservableObject, GCKSessionManagerListener {
    @Published var isConnected: Bool = false
    private var castSession: GCKCastSession?
    private var customChannel: TR_MyCustomCastChannel?
    private let commonVm: TR_DeviceConnectivityViewModel?
    private var broadcastTimer: Timer?
    private var setupCompleted: Bool = false
    private let suiteName = TR_AppStrings.groupID

    init(commonVm: TR_DeviceConnectivityViewModel) {
        self.commonVm = commonVm
        super.init()
    
        GCKCastContext.sharedInstance().sessionManager.add(self)
        
        // If there's already an active cast session matching custom receiver, attach custom channel immediately
        if let current = GCKCastContext.sharedInstance().sessionManager.currentCastSession {
            if current.applicationMetadata?.applicationID == TR_AppStrings.kCustomReceiverAppID {
                self.castSession = current
                addCustomChannelToSession(current)
            }
        }
        
        broadcastTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkBroadcastStatus()
        }
    }

    private func checkBroadcastStatus() {
        guard !setupCompleted else {
            broadcastTimer?.invalidate()
            return
        }
        
        let common = commonVm ?? TR_DeviceConnectivityViewModel.shared
        let tvType = TR_RemoteViewModel.shared.connectedTVType ?? common.connectedTvType
        
        // If connected to LG or AirPlay, do NOT start Google Cast receiver session
        if tvType == .LG || tvType == .AIRPLAY {
            broadcastTimer?.invalidate()
            return
        }
        
        guard let userDefaults = UserDefaults(suiteName: suiteName) else { return }
        let isBroadcasting = userDefaults.bool(forKey: "isBroadcasting")
        let mode = userDefaults.string(forKey: "broadcastMode") ?? ""
        
        // Connect / cast to TR_TV when mode is mirroring, camera, or drawing
        guard isBroadcasting && (mode == "mirroring" || mode == "camera" || mode == "drawing" || mode.isEmpty) else {
            return
        }
        
        if isConnected {
            sendMessageToCustomChannel()
            setupCompleted = true
            broadcastTimer?.invalidate()
        } else {
            connectToDevice()
        }
    }
    
    func stopCastingSession() {
        broadcastTimer?.invalidate()
        broadcastTimer = nil
        let sessionManager = GCKCastContext.sharedInstance().sessionManager
        if sessionManager.currentCastSession != nil {
            sessionManager.endSessionAndStopCasting(true)
            print("🛑 TR_BroadCastPickerManager: Disconnected from device and stopped receiver")
        }
        isConnected = false
        setupCompleted = false
    }

    @objc private func handleStartCastingSession() {
        print("channel connected")
        connectToDevice()
    }

    private func connectToDevice() {
        Task { @MainActor in
            let common = self.commonVm ?? TR_DeviceConnectivityViewModel.shared
            let currentTVType = TR_RemoteViewModel.shared.connectedTVType ?? common.connectedTvType
            
            // Only proceed for Google Cast compatible devices
            if currentTVType == .LG || currentTVType == .AIRPLAY || currentTVType == .ROKU || currentTVType == .FIRE {
                print("🛑 TR_BroadCastPickerManager: Skipping Cast receiver for \(currentTVType?.rawValue ?? "connected TR_TV")")
                return
            }
            
            var device = self.commonVm?.castViewModel.selectedDevice
            if device == nil {
                var targetIP = TR_RemoteViewModel.shared.connectingDeviceAddress ?? ""
                if targetIP.isEmpty {
                    targetIP = DeviceConnectionManager.shared.connectedDevice?.ipAddress ?? TR_UserDefaultManager.shared.getShared(forKey: "ConnectedDeviceIP") ?? ""
                }
                if !targetIP.isEmpty {
                    if let match = gcastDevice.first(where: { $0.ipAddress == targetIP }) {
                        device = match
                    } else {
                        print("⚠️ TR_BroadCastPickerManager: Connected TR_TV IP (\(targetIP)) is not a Google Cast device. Skipping Cast connection.")
                        return
                    }
                } else if currentTVType == .ANDROID, let first = gcastDevice.first {
                    device = first
                }
                self.commonVm?.castViewModel.selectedDevice = device
            }
            
            guard let targetDevice = device else {
                print("❌ No valid Google Cast device selected for mirroring")
                return
            }
            
            print("📱 TR_BroadCastPickerManager: Launching custom receiver session for \(targetDevice.friendlyName ?? "device")")
            self.commonVm?.castViewModel.startCustomReceiverSession(with: targetDevice)
            TR_SilentAudioManager.shared.start()
        }
    }

    func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKSession) {
        guard let castSession = session as? GCKCastSession else {
            print("Failed to cast session to GCKCastSession")
            return
        }
        self.castSession = castSession
        addCustomChannelToSession(castSession)
        print("Session started with device: \(session.device.friendlyName ?? "Unknown TR_Device")")
    }

    private func addCustomChannelToSession(_ session: GCKCastSession) {
        if customChannel == nil {
            let channel = TR_MyCustomCastChannel(namespace: TR_AppStrings.channelNamespace, suiteName: suiteName)
            channel.onConnected = { [weak self] in
                DispatchQueue.main.async {
                    self?.isConnected = true
                    self?.sendMessageToCustomChannel()
                }
            }
            channel.onDisconnected = { [weak self] in
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
            }
            customChannel = channel
        }

        if let channel = customChannel {
            session.add(channel)
            if channel.isConnected {
                self.isConnected = true
                self.sendMessageToCustomChannel()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.isConnected = channel.isConnected
                self?.checkBroadcastStatus()
            }
        } else {
            isConnected = false
        }
    }

    private func sendMessageToCustomChannel() {
        guard let customChannel = customChannel, isConnected else {
            print("CustomChannel is not connected or initialized")
            return
        }
        if let url = TR_MirroringServerManager.shared.effectiveServerURL ?? TR_MirroringServerManager.shared.serverURL {
            let urlString = url.absoluteString
            print("🚀 Sending Mirroring stream URL to TR_TV: \(urlString)")
            sendMessage(urlString)
        }
    }

    private func sendMessage(_ message: String) {
        guard let customChannel = customChannel, isConnected else {
            print("CustomChannel is not connected or initialized")
            return
        }
        var error: GCKError?
        customChannel.sendTextMessage(message, error: &error)
        if let error = error {
            print("Error sending text message: \(error.localizedDescription)")
        } else {
            print("✅ Successfully sent message to TR_TV Custom TR_Channel: \(message)")
        }
    }

    func sessionManager(_ sessionManager: GCKSessionManager, didResume session: GCKSession) {
        guard let castSession = session as? GCKCastSession else {
            print("Failed to cast session to GCKCastSession")
            return
        }
        self.castSession = castSession
        addCustomChannelToSession(castSession)
        print("Session resumed with device: \(session.device.friendlyName ?? "Unknown TR_Device")")
    }

    func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKSession, withError error: Error?) {
        isConnected = false
        setupCompleted = false
        TR_SilentAudioManager.shared.stop()
    }

    func sessionManager(_ sessionManager: GCKSessionManager, didFailToStart session: GCKSession, withError error: Error) {
        isConnected = false
        setupCompleted = false
    }
    
    deinit {
        broadcastTimer?.invalidate()
        broadcastTimer = nil
        GCKCastContext.sharedInstance().sessionManager.remove(self)
    }
    
    func removeCurrentSession(){
        GCKCastContext.sharedInstance().sessionManager.remove(self)
    }
}


class TR_MyCustomCastChannel: GCKCastChannel, GCKSessionManagerListener {
    private let suiteName: String
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?

    init(namespace: String, suiteName: String) {
        self.suiteName = suiteName
        super.init(namespace: namespace)
    }

    override func didReceiveTextMessage(_ message: String) {
        super.didReceiveTextMessage(message)
        print("Received message: \(message)")
        handleMessage(message: message)
    }
    
    override func didConnect() {
        super.didConnect()
        print("✅ TR_Channel connected to Custom Receiver")
        onConnected?()
    }
    
    override func didDisconnect() {
        super.didDisconnect()
        GCKCastContext.sharedInstance().sessionManager.remove(self)
        print("❌ TR_Channel disconnected from Custom Receiver")
        onDisconnected?()
    }
    
    private func handleMessage(message: String) {
        print("Handling message: \(message)")
    }
}

