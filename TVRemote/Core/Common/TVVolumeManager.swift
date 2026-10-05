//
//  TVVolumeManager.swift
//  TV Remote
//

import Foundation
import SwiftUI
import Combine
import MediaPlayer
import AVFoundation
import ConnectSDK

@MainActor
final class TVVolumeManager: ObservableObject {
    static let shared = TVVolumeManager()
    
    @Published var currentVolume: Double = 0.8
    @Published var isMuted: Bool = false
    
    private var isDragging: Bool = false
    private var lastSentVolume: Double = 0.8
    private var lastStepTime: Date = Date.distantPast
    private var previousUnmutedVolume: Double = 0.8
    
    private var audioSessionObserver: NSKeyValueObservation?
    
    private init() {
        let initialVol = Double(AVAudioSession.sharedInstance().outputVolume)
        if initialVol > 0.01 {
            self.currentVolume = initialVol
            self.lastSentVolume = initialVol
            self.previousUnmutedVolume = initialVol
        } else {
            self.currentVolume = 0.8
            self.lastSentVolume = 0.8
            self.previousUnmutedVolume = 0.8
        }
        setupVolumeObservation()
    }
    
    private func setupVolumeObservation() {
        audioSessionObserver = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let newVol = change.newValue else { return }
            Task { @MainActor in
                guard let self = self, !self.isDragging else { return }
                if Date().timeIntervalSince(self.lastStepTime) > 0.3 {
                    self.currentVolume = Double(newVol)
                    self.lastSentVolume = Double(newVol)
                    self.isMuted = (newVol < 0.01)
                    if newVol >= 0.01 {
                        self.previousUnmutedVolume = Double(newVol)
                    }
                }
            }
        }
    }
    
    // MARK: - Slider Interactions
    func onSliderChanged(newVolume: Double) {
        isDragging = true
        let clamped = max(0.0, min(1.0, newVolume))
        self.currentVolume = clamped
        
        if clamped > 0.01 {
            self.isMuted = false
            self.previousUnmutedVolume = clamped
        } else {
            self.isMuted = true
        }
        
        // 1. Direct absolute volume to Cast, ConnectSDK, and AirPlay/System
        sendAbsoluteVolume(Float(clamped))
        
        // 2. Remote TR_Key Steps (VOLUMEUP / VOLUMEDOWN)
        let delta = clamped - lastSentVolume
        let now = Date()
        let elapsed = now.timeIntervalSince(lastStepTime)
        
        // Step every ~3% change with 80ms throttle
        if abs(delta) >= 0.025 && elapsed >= 0.08 {
            if delta > 0 {
                sendVolumeUp()
            } else {
                sendVolumeDown()
            }
            lastSentVolume = clamped
            lastStepTime = now
        }
    }
    
    func onSliderEnded(finalVolume: Double) {
        isDragging = false
        let clamped = max(0.0, min(1.0, finalVolume))
        self.currentVolume = clamped
        self.lastSentVolume = clamped
        
        if clamped > 0.01 {
            self.isMuted = false
            self.previousUnmutedVolume = clamped
        } else {
            self.isMuted = true
        }
        
        sendAbsoluteVolume(Float(clamped))
    }
    
    // MARK: - Mute Toggle
    func toggleMute() {
        if currentVolume > 0.01 && !isMuted {
            previousUnmutedVolume = currentVolume > 0.05 ? currentVolume : 0.8
            isMuted = true
            currentVolume = 0.0
            lastSentVolume = 0.0
            sendMuteCommand(isMute: true)
        } else {
            isMuted = false
            let restoreVol = previousUnmutedVolume > 0.05 ? previousUnmutedVolume : 0.8
            currentVolume = restoreVol
            lastSentVolume = restoreVol
            sendMuteCommand(isMute: false)
        }
    }
    
    // MARK: - Volume Commands (Unified Across All Places)
    func sendVolumeUp() {
        let newVol = min(1.0, currentVolume + 0.01)
        currentVolume = newVol
        lastSentVolume = newVol
        isMuted = false
        lastStepTime = Date()
        
        let tvType = TR_DeviceConnectivityViewModel.shared.getConnectedTvType()
        
        switch tvType {
        case .AIRPLAY:
            SystemVolumeManager.shared.setSystemVolume(Float(newVol))
            
        case .LG, .ROKU, .FIRE, .ANDROID, .SAMSUNG:
            TR_RemoteViewModel.shared.sendCommand(.VOLUMEUP)
            
        case .NONETV, .none:
            if DeviceConnectionManager.shared.isAirPlayConnected || TR_AirPlayManager.shared.isAirPlayConnected {
                SystemVolumeManager.shared.setSystemVolume(Float(newVol))
            } else if TR_RemoteViewModel.shared.connectedTVType != nil && TR_RemoteViewModel.shared.connectedTVType != .NONETV {
                TR_RemoteViewModel.shared.sendCommand(.VOLUMEUP)
            } else if let lgDev = TR_DeviceConnectivityViewModel.shared.connectSDKDiscoveryModel.selectedLGDevice {
                lgDev.volumeControl()?.volumeUp(success: nil, failure: nil)
            } else if TR_DeviceConnectivityViewModel.shared.castViewModel.isConnected {
                TR_DeviceConnectivityViewModel.shared.setVolume(Float(newVol))
            }
        }
    }
    
    func sendVolumeDown() {
        let newVol = max(0.0, currentVolume - 0.01)
        currentVolume = newVol
        lastSentVolume = newVol
        isMuted = (newVol <= 0.01)
        lastStepTime = Date()
        
        let tvType = TR_DeviceConnectivityViewModel.shared.getConnectedTvType()
        
        switch tvType {
        case .AIRPLAY:
            SystemVolumeManager.shared.setSystemVolume(Float(newVol))
            
        case .LG, .ROKU, .FIRE, .ANDROID, .SAMSUNG:
            TR_RemoteViewModel.shared.sendCommand(.VOLUMEDOWN)
            
        case .NONETV, .none:
            if DeviceConnectionManager.shared.isAirPlayConnected || TR_AirPlayManager.shared.isAirPlayConnected {
                SystemVolumeManager.shared.setSystemVolume(Float(newVol))
            } else if TR_RemoteViewModel.shared.connectedTVType != nil && TR_RemoteViewModel.shared.connectedTVType != .NONETV {
                TR_RemoteViewModel.shared.sendCommand(.VOLUMEDOWN)
            } else if let lgDev = TR_DeviceConnectivityViewModel.shared.connectSDKDiscoveryModel.selectedLGDevice {
                lgDev.volumeControl()?.volumeDown(success: nil, failure: nil)
            } else if TR_DeviceConnectivityViewModel.shared.castViewModel.isConnected {
                TR_DeviceConnectivityViewModel.shared.setVolume(Float(newVol))
            }
        }
    }
    
    private func sendMuteCommand(isMute: Bool) {
        let tvType = TR_DeviceConnectivityViewModel.shared.getConnectedTvType()
        
        switch tvType {
        case .AIRPLAY:
            SystemVolumeManager.shared.setSystemVolume(isMute ? 0.0 : Float(currentVolume))
            
        case .LG, .ROKU, .FIRE, .ANDROID, .SAMSUNG:
            TR_RemoteViewModel.shared.sendCommand(.MUTE)
            
        case .NONETV, .none:
            if DeviceConnectionManager.shared.isAirPlayConnected || TR_AirPlayManager.shared.isAirPlayConnected {
                SystemVolumeManager.shared.setSystemVolume(isMute ? 0.0 : Float(currentVolume))
            } else if TR_RemoteViewModel.shared.connectedTVType != nil && TR_RemoteViewModel.shared.connectedTVType != .NONETV {
                TR_RemoteViewModel.shared.sendCommand(.MUTE)
            } else if let lgDev = TR_DeviceConnectivityViewModel.shared.connectSDKDiscoveryModel.selectedLGDevice {
                lgDev.volumeControl()?.setMute(isMute, success: nil, failure: nil)
            }
        }
    }
    
    private func sendAbsoluteVolume(_ vol: Float) {
        let tvType = TR_DeviceConnectivityViewModel.shared.getConnectedTvType()
        
        switch tvType {
        case .AIRPLAY:
            SystemVolumeManager.shared.setSystemVolume(vol)
            
        case .LG:
            TR_DeviceConnectivityViewModel.shared.connectSDKDiscoveryModel.selectedLGDevice?.volumeControl()?.setVolume(vol, success: nil, failure: nil)
            DeviceConnectionManager.shared.connectedDevice?.connectableDevice?.volumeControl()?.setVolume(vol, success: nil, failure: nil)
            
        case .ROKU, .FIRE:
            DeviceConnectionManager.shared.connectedDevice?.connectableDevice?.volumeControl()?.setVolume(vol, success: nil, failure: nil)
            
        case .ANDROID:
            if TR_DeviceConnectivityViewModel.shared.castViewModel.selectedDevice != nil && TR_DeviceConnectivityViewModel.shared.castViewModel.isConnected {
                TR_DeviceConnectivityViewModel.shared.setVolume(vol)
            }
            
        case .SAMSUNG:
            if TR_DeviceConnectivityViewModel.shared.castViewModel.selectedDevice != nil && TR_DeviceConnectivityViewModel.shared.castViewModel.isConnected {
                TR_DeviceConnectivityViewModel.shared.setVolume(vol)
            } else {
                DeviceConnectionManager.shared.connectedDevice?.connectableDevice?.volumeControl()?.setVolume(vol, success: nil, failure: nil)
            }
            
        case .NONETV, .none:
            if DeviceConnectionManager.shared.isAirPlayConnected || TR_AirPlayManager.shared.isAirPlayConnected {
                SystemVolumeManager.shared.setSystemVolume(vol)
            } else if let lgDev = TR_DeviceConnectivityViewModel.shared.connectSDKDiscoveryModel.selectedLGDevice {
                lgDev.volumeControl()?.setVolume(vol, success: nil, failure: nil)
            } else if TR_DeviceConnectivityViewModel.shared.castViewModel.isConnected {
                TR_DeviceConnectivityViewModel.shared.setVolume(vol)
            }
        }
    }
}
