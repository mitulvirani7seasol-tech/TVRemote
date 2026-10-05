//
//  AdOrientationManager.swift
//  TV Remote
//
//

import Foundation
import UIKit
import Combine

final class AdOrientationManager: ObservableObject {
    static let shared = AdOrientationManager()
    
    private var lastDeviceOrientation: UIDeviceOrientation = .unknown
    private var lastIsLandscape: Bool? = nil
    
    private init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceRotation),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    func startMonitoring() {
        if let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            lastIsLandscape = windowScene.interfaceOrientation.isLandscape
        }
        if UIDevice.current.orientation.isValidInterfaceOrientation {
            lastDeviceOrientation = UIDevice.current.orientation
        }
    }
    
    @objc private func handleDeviceRotation() {
        // Only dismiss ads on rotation if the device is an iPad
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        
        let smObservedOrientation = UIDevice.current.orientation
        let currentIsLandscape: Bool? = {
            let activeScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            return activeScene?.interfaceOrientation.isLandscape
        }()
        
        var didRotate = false
        
        // 1. Check physical device orientation change (portrait vs landscape)
        if smObservedOrientation.isValidInterfaceOrientation {
            if lastDeviceOrientation != .unknown && lastDeviceOrientation != smObservedOrientation {
                didRotate = true
            }
            lastDeviceOrientation = smObservedOrientation
        }
        
        // 2. Check window scene interface orientation change
        if let currentIsLandscape = currentIsLandscape {
            if let lastIsLandscape = lastIsLandscape, lastIsLandscape != currentIsLandscape {
                didRotate = true
            }
            lastIsLandscape = currentIsLandscape
        }
        
        if didRotate {
            print("🔄 [AdOrientationManager] iPad orientation rotation detected -> Auto-dismissing active ads")
            dismissAllActiveAds()
        }
    }
    
    private var isDismissing: Bool = false

    func dismissAllActiveAds() {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        guard !isDismissing else { return }
        
        isDismissing = true
        DispatchQueue.main.async {
            // Dismiss App Open Ads (triggers adCompletion to continue flow)
            TR_AppOpenAdManager.shared.dismissAdIfShowing()
            TR_AppOpenBackAdManager.shared.dismissAdIfShowing()
            
            // Dismiss Interstitial Ads (triggers onDismiss completion to continue flow)
            TR_AdCountViewModel.sharedd.interstitialManager.dismissAdIfShowing()
            TR_InterstitialAdManager.dismissAnyActiveInterstitial()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.isDismissing = false
            }
        }
    }
}
