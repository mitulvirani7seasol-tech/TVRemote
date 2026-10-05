//
//  BroadcastNotificationCenter.swift
//  TV Remote
//

import Foundation
import Combine
import UIKit
import GoogleCast

final class BroadcastNotificationCenter: ObservableObject {
    static let shared = BroadcastNotificationCenter()
    
    private init() {
        setupDarwinObservers()
        setupScreenCaptureObserver()
    }
    
    private func setupScreenCaptureObserver() {
        NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let isCaptured = UIScreen.main.isCaptured
            print("📱 BroadcastNotificationCenter: capturedDidChange -> isCaptured: \(isCaptured)")
            let isBroadcastingRaw = UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") ?? false
            // Only cleanup if screen capture stopped and no active ReplayKit broadcast extension is running
            if !isCaptured && !isBroadcastingRaw {
                self?.handleBroadcastStopped()
            }
        }
    }
    
    private func setupDarwinObservers() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        
        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, _, name, _, _ in
                DispatchQueue.main.async {
                    if let rawName = name?.rawValue as String? {
                        NotificationCenter.default.post(name: NSNotification.Name(rawName), object: nil)
                    }
                }
            },
            "BROADCAST_STARTED" as CFString,
            nil,
            .deliverImmediately
        )
        
        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, _, name, _, _ in
                DispatchQueue.main.async {
                    if let rawName = name?.rawValue as String? {
                        NotificationCenter.default.post(name: NSNotification.Name(rawName), object: nil)
                    }
                    BroadcastNotificationCenter.shared.handleBroadcastStopped()
                }
            },
            "BROADCAST_STOPPED" as CFString,
            nil,
            .deliverImmediately
        )
    }
    
    @MainActor func handleBroadcastStopped() {
        if let defaults = UserDefaults(suiteName: TR_AppStrings.groupID) {
            let mode = defaults.string(forKey: "broadcastMode") ?? ""
            if mode == "mirroring" || mode == "camera" || mode == "drawing" {
                defaults.set(false, forKey: "isBroadcasting")
                defaults.synchronize()
            }
        }
        
        // 1. End Google Cast custom receiver mirroring session
        let sessionManager = GCKCastContext.sharedInstance().sessionManager
        if sessionManager.currentCastSession != nil {
            sessionManager.endSessionAndStopCasting(true)
            print("🛑 BroadcastNotificationCenter: Disconnected custom receiver cast session")
        }
        
        // 2. Stop Silent Audio
        TR_SilentAudioManager.shared.stop()
        
        // 3. Mark mirroring inactive
        TR_MirroringServerManager.shared.isMirroringActive = false
        DeviceConnectionManager.shared.isMirroringActive = false
        
        // 4. Set placeholder banner on connected TR_TV for subsequent media casting
        Task { @MainActor in
            let commonVM = TR_DeviceConnectivityViewModel.shared
            let currentType = TR_RemoteViewModel.shared.connectedTVType ?? commonVM.connectedTvType ?? .ANDROID
            commonVM.setTVPlaceHolder(connectedTvType: currentType)
        }
        
        // 5. Dismiss system broadcast picker dialog
        BroadcastNotificationCenter.dismissSystemPickerIfPresent()
        
        // 6. Notify local observers
        NotificationCenter.default.post(name: NSNotification.Name("BROADCAST_STOPPED"), object: nil)
        print("🛑 Broadcast stopped globally & clean-up completed")
    }
    
    @MainActor
    static func dismissSystemPickerIfPresent() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for window in scene.windows {
                if let root = window.rootViewController {
                    var current: UIViewController? = root
                    while let presented = current?.presentedViewController {
                        let className = String(describing: type(of: presented))
                        print("📱 Checking presented VC for dismissal: \(className)")
                        if className.contains("Broadcast") || className.contains("Picker") || className.contains("Remote") || className.contains("Alert") {
                            presented.dismiss(animated: true, completion: nil)
                            return
                        }
                        current = presented
                    }
                    if let top = current?.presentedViewController {
                        top.dismiss(animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    static func stopBroadcastExtension() {
        if let defaults = UserDefaults(suiteName: TR_AppStrings.groupID) {
            defaults.set(true, forKey: "shouldStopBroadcast")
            defaults.set(false, forKey: "isBroadcasting")
            defaults.synchronize()
        }
        
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("STOP_BROADCAST_FROM_APP" as CFString),
            nil,
            nil,
            true
        )
        
        DispatchQueue.main.async {
            BroadcastNotificationCenter.shared.handleBroadcastStopped()
        }
    }
}
