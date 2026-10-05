//
//  AppConsentManager.swift
//  TV Remote
//
//  Created by iOS Developer on 14/09/2026.
//

import Foundation
import UIKit
import Combine
import AppTrackingTransparency
import UserMessagingPlatform

@MainActor
final class AppConsentManager: NSObject, ObservableObject {
    static let shared = AppConsentManager()
    
    @Published var isConsentCompleted: Bool = false
    private var isRequestInProgress: Bool = false
    
    private override init() {
        super.init()
    }
    
    // MARK: - Main Entry Point: Request UMP Consent -> ATT Dialog -> Completion
    func requestConsentAndTracking(from viewController: UIViewController? = nil, completion: @escaping () -> Void) {
        guard !isRequestInProgress else {
            completion()
            return
        }
        
        isRequestInProgress = true
        
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false
        
        #if DEBUG
        let debugSettings = DebugSettings()
        debugSettings.geography = .EEA
        parameters.debugSettings = debugSettings
        #endif
        
        print("📋 Requesting UMP Consent info update...")
        
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion()
                    return
                }
                
                if let error = error {
                    print("⚠️ UMP Consent info update failed: \(error.localizedDescription)")
                    self.handleConsentFinished(completion: completion)
                    return
                }
                
                let presentingVC = viewController ?? UIApplication.shared.topPresentedViewController
                
                ConsentForm.loadAndPresentIfRequired(from: presentingVC) { [weak self] formError in
                    DispatchQueue.main.async {
                        guard let self = self else {
                            completion()
                            return
                        }
                        
                        if let formError = formError {
                            print("⚠️ UMP Consent Form load/present failed: \(formError.localizedDescription)")
                        } else {
                            print("✅ UMP Consent Form handled successfully.")
                        }
                        
                        self.handleConsentFinished(completion: completion)
                    }
                }
            }
        }
    }
    
    // MARK: - Step 2: Request App Tracking Transparency (ATT)
    private func handleConsentFinished(completion: @escaping () -> Void) {
        self.requestTrackingAuthorizationIfNeeded { [weak self] in
            guard let self = self else {
                completion()
                return
            }
            self.isConsentCompleted = true
            self.isRequestInProgress = false
            completion()
        }
    }
    
    private func requestTrackingAuthorizationIfNeeded(completion: @escaping () -> Void) {
        if #available(iOS 14.5, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            if status == .notDetermined {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    print("🎯 Presenting AppTrackingTransparency (ATT) popup...")
                    ATTrackingManager.requestTrackingAuthorization { authStatus in
                        print("🎯 ATT Authorization result: \(authStatus.rawValue)")
                        DispatchQueue.main.async {
                            completion()
                        }
                    }
                }
                return
            }
        }
        completion()
    }
}

// MARK: - UIApplication & UIViewController Top-Most Helper
extension UIApplication {
    var topPresentedViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?
            .topMostViewController
    }
}

extension UIViewController {
    var topMostViewController: UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController
        }
        if let nav = self as? UINavigationController, let visible = nav.visibleViewController {
            return visible.topMostViewController
        }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController {
            return selected.topMostViewController
        }
        return self
    }
}
