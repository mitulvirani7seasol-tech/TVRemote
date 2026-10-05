//
//  AppOpenAd.swift
//  TV Remote Casting
//
//  Created by Ronik Hirpara on 28/10/25.
//

//import SwiftUI
//import GoogleMobileAds
//import UIKit
//import Foundation
//
final class TR_AdState {
    static let shared = TR_AdState()
    
    var isShowingInterstitial = false
}
//
//class TR_AppOpenAdManager: NSObject, FullScreenContentDelegate {
//    var appOpenAd: AppOpenAd?
//    var isLoadingAd = false
//    var isShowingAd = false
//    var loadTime: Date?
//    var hasLoadedOnce = false
//    static let shared = TR_AppOpenAdManager()
//
//    // Keep a reference to the completion closure
//    private var adCompletion: (() -> Void)?
//
//    // MARK: - Load Ad
//    func loadAd() async {
//        if isLoadingAd {
//            print("⏳ Ad is already loading.")
//            return
//        }
//        if hasLoadedOnce {
//            print("✅ App open ad already loaded this session — skipping.")
//            return
//        }
//
//        isLoadingAd = true
//        do {
//            print("🚀 Loading App Open Ad...")
//            appOpenAd = try await AppOpenAd.load(
//                with: appopenId,
//                request: Request()
//            )
//            appOpenAd?.fullScreenContentDelegate = self
//            loadTime = Date()
//            hasLoadedOnce = true
//            print("✅ App Open Ad successfully loaded.")
//        } catch {
//            print("❌ Failed to load App Open Ad: \(error.localizedDescription)")
//            appOpenAd = nil
//            loadTime = nil
//        }
//        isLoadingAd = false
//    }
//
//    // MARK: - Show Ad with Completion
//    func showAdIfAvailable(completion: @escaping () -> Void) {
//        
//        if TR_AdState.shared.isShowingInterstitial {
//                print("⛔ Skipping AppOpenAd because interstitial is showing")
//                completion()
//                return
//            }
//        
//        if isShowingAd {
//            print("⚠️ App open ad is already showing.")
//            completion()
//            return
//        }
//        guard let ad = appOpenAd else {
//            print("⚠️ App open ad not available.")
//            completion()
//            return
//        }
//        if let topVC = UIApplication.topViewController {
//            print("🎬 Presenting App Open Ad...")
//            ad.present(from: topVC)
//            isShowingAd = true
//            adCompletion = completion
//        } else {
//            completion()
//        }
//    }
//
//    // MARK: - Ad Delegate Callbacks
//    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
//        print("ℹ️ Ad will present full screen content.")
//    }
//
//    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
//        print("ℹ️ App open ad impression recorded.")
//    }
//
//    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
//        print("ℹ️ App open ad clicked.")
//    }
//
//    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
//        print("ℹ️ App open ad will dismiss.")
//    }
//
//    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
//        print("✅ App open ad dismissed.")
//        finishAdFlow()
//    }
//
//    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
//        print("❌ Ad failed to present: \(error.localizedDescription)")
//        finishAdFlow()
//    }
//
//    private func finishAdFlow() {
//        isShowingAd = false
//        appOpenAd = nil
//        hasLoadedOnce = true
//        adCompletion?()
//        adCompletion = nil
//    }
//
//    // MARK: - Reset for new session
//    func resetForForeground() {
//        print("🔄 Resetting TR_AppOpenAdManager for foreground session.")
//        hasLoadedOnce = false
//        appOpenAd = nil
////        isShowingAd = false
//        loadTime = nil
//    }
//}
//
//
//class TR_AppOpenBackAdManager: NSObject, FullScreenContentDelegate {
//    var appOpenAd: AppOpenAd?
//    weak var appOpenAdManagerDelegate: TR_AppOpenAdManagerDelegate?
//    var isLoadingAd = false
//    var isShowingAd = false
//    var loadTime: Date?
//    var hasLoadedOnce = false
//
//    static let shared = TR_AppOpenBackAdManager()
//
//    protocol TR_AppOpenAdManagerDelegate: AnyObject {
//        func appOpenAdManagerAdDidComplete(_ appOpenAdManager: TR_AppOpenBackAdManager)
//    }
//
//    // MARK: - Load Ad
//    func loadAd() async {
//        if isLoadingAd {
//            print("⏳ Ad is already loading.")
//            return
//        }
//        if hasLoadedOnce {
//            print("✅ App open ad already loaded this session — skipping.")
//            return
//        }
//
//        isLoadingAd = true
//        do {
//            print("🚀 Loading App Open Ad...")
//            appOpenAd = try await AppOpenAd.load(
//                with: appopenId,
//                request: Request()
//            )
//            appOpenAd?.fullScreenContentDelegate = self
//            loadTime = Date()
//            hasLoadedOnce = true
//            print("✅ App Open Ad successfully loaded.")
//        } catch {
//            print("❌ Failed to load App Open Ad: \(error.localizedDescription)")
//            appOpenAd = nil
//            loadTime = nil
//        }
//        isLoadingAd = false
//    }
//
//    // MARK: - Show Ad
//    func showAdIfAvailable() {
//        if isShowingAd {
//            print("⚠️ App open ad is already showing.")
//            return
//        }
//        guard let ad = appOpenAd else {
//            print("⚠️ App open ad not available.")
//            appOpenAdManagerDelegate?.appOpenAdManagerAdDidComplete(self)
//            return
//        }
//        if let topVC = UIApplication.topViewController {
//            print("🎬 Presenting App Open Ad...")
//            ad.present(from: topVC)
//            isShowingAd = true
//        }
//    }
//
//    // MARK: - Ad Delegate Callbacks
//    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
//        print("ℹ️ Ad will present full screen content.")
//    }
//
//    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
//        print("ℹ️ App open ad impression recorded.")
//    }
//
//    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
//        print("ℹ️ App open ad clicked.")
//    }
//
//    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
//        print("ℹ️ App open ad will dismiss.")
//    }
//
//    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
//        print("✅ App open ad dismissed.")
//        isShowingAd = false
//        appOpenAd = nil
//        appOpenAdManagerDelegate?.appOpenAdManagerAdDidComplete(self)
//    }
//
//    func ad(_ ad: FullScreenPresentingAd,
//            didFailToPresentFullScreenContentWithError error: Error) {
//        print("❌ Ad failed to present: \(error.localizedDescription)")
//        isShowingAd = false
//        appOpenAd = nil
//        appOpenAdManagerDelegate?.appOpenAdManagerAdDidComplete(self)
//    }
//
//    // MARK: - Reset for new session
//    func resetForForeground() {
//        print("🔄 Resetting TR_AppOpenAdManager for foreground session.")
//        hasLoadedOnce = false
//        appOpenAd = nil
////        isShowingAd = false
//        loadTime = nil
//    }
//}
//
//// MARK: - Top View Controller helper
//extension UIApplication {
//    static var topViewController: UIViewController? {
//        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//              let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
//            return nil
//        }
//        var top = root
//        while let presented = top.presentedViewController {
//            top = presented
//        }
//        return top
//    }
//}

import SwiftUI
import GoogleMobileAds
import UIKit
import Foundation

class TR_AppOpenAdManager: NSObject, FullScreenContentDelegate {
    var appOpenAd: AppOpenAd?
    var isLoadingAd = false
    var isShowingAd = false
    var loadTime: Date?
    var hasLoadedOnce = false
    static let shared = TR_AppOpenAdManager()
    
    private var adCompletion: (() -> Void)?
    private weak var presentingVC: UIViewController?
    private weak var presentedAdVC: UIViewController?
    
    // MARK: - Load Ad
    func loadAd() async {
        if isLoadingAd {
            print("⏳ [AppOpenAd] Ad is already loading.")
            return
        }
        if hasLoadedOnce {
            print("✅ [AppOpenAd] App open ad already loaded this session — skipping.")
            return
        }
        
        isLoadingAd = true
        do {
            let isHomeOpened = UserDefaults.standard.bool(forKey: TR_SessionKeys.isHomeOpened)
            let unitId: String = {
                if !isHomeOpened {
                    return !second_appopen.isEmpty ? second_appopen : (!appopenId.isEmpty ? appopenId : "ca-app-pub-3940256099942544/5575463023")
                } else {
                    return !appopenId.isEmpty ? appopenId : (!second_appopen.isEmpty ? second_appopen : "ca-app-pub-3940256099942544/5575463023")
                }
            }()
            print("🚀 [AppOpenAd] Loading with ID: \(unitId) | isHomeOpened: \(isHomeOpened)")
            appOpenAd = try await AppOpenAd.load(
                with: unitId,
                request: Request()
            )
            appOpenAd?.fullScreenContentDelegate = self
            loadTime = Date()
            hasLoadedOnce = true
            print("✅ [AppOpenAd] Successfully loaded with ID: \(unitId)")
        } catch {
            print("❌ [AppOpenAd] Failed to load: \(error.localizedDescription)")
            appOpenAd = nil
            loadTime = nil
        }
        isLoadingAd = false
    }
    
    // MARK: - Show Ad with Completion
    func showAdIfAvailable(completion: @escaping () -> Void) {
        if isShowingAd {
            print("⚠️ App open ad is already showing.")
            completion()
            return
        }
        guard let ad = appOpenAd else {
            print("⚠️ App open ad not available.")
            completion()
            return
        }
        if let topVC = UIApplication.topViewController {
            print("🎬 Presenting App Open Ad...")
            isShowingAd = true
            adCompletion = completion
            presentingVC = topVC
            ad.present(from: topVC)
        } else {
            completion()
        }
    }
    
    // MARK: - Ad Delegate Callbacks
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("ℹ️ Ad will present full screen content.")
        isShowingAd = true
        if let presented = presentingVC?.presentedViewController {
            presentedAdVC = presented
        }
    }
    
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("ℹ️ App open ad impression recorded.")
    }
    
    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        print("ℹ️ App open ad clicked.")
    }
    
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("ℹ️ App open ad will dismiss.")
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("✅ App open ad dismissed.")
        finishAdFlow()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ Ad failed to present: \(error.localizedDescription)")
        finishAdFlow()
    }
    
    private func finishAdFlow() {
        guard isShowingAd || adCompletion != nil else { return }
        isShowingAd = false
        appOpenAd = nil
        hasLoadedOnce = true
        presentedAdVC = nil
        presentingVC = nil
        
        let completion = adCompletion
        adCompletion = nil
        completion?()
    }
    
    // MARK: - Dismiss on iPad Rotation
    func dismissAdIfShowing() {
        guard isShowingAd else { return }
        print("🔄 [AppOpenAd] Dismissing App Open Ad due to iPad orientation rotation")
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isShowingAd else { return }
            let vcToDismiss = self.presentedAdVC ?? self.presentingVC?.presentedViewController
            
            if let vc = vcToDismiss, !vc.isBeingDismissed {
                vc.dismiss(animated: true) { [weak self] in
                    self?.finishAdFlow()
                }
            } else {
                self.finishAdFlow()
            }
        }
    }
    
    // MARK: - Reset for new session
    func resetForForeground() {
        print("🔄 Resetting TR_AppOpenAdManager for foreground session.")
        hasLoadedOnce = false
        appOpenAd = nil
        isShowingAd = false
        loadTime = nil
    }
}


class TR_AppOpenBackAdManager: NSObject, FullScreenContentDelegate {
    var appOpenAd: AppOpenAd?
    weak var appOpenAdManagerDelegate: TR_AppOpenAdManagerDelegate?
    var isLoadingAd = false
    var isShowingAd = false
    var loadTime: Date?
    var hasLoadedOnce = false
    private var adCompletion: (() -> Void)?
    private weak var presentingVC: UIViewController?
    private weak var presentedAdVC: UIViewController?
    
    static let shared = TR_AppOpenBackAdManager()
    
    protocol TR_AppOpenAdManagerDelegate: AnyObject {
        func appOpenAdManagerAdDidComplete(_ appOpenAdManager: TR_AppOpenBackAdManager)
    }
    
    // MARK: - Load Ad
    func loadAd() async {
        if isLoadingAd {
            print("⏳ [AppOpenBackAd] Ad is already loading.")
            return
        }
        if hasLoadedOnce {
            print("✅ [AppOpenBackAd] App open ad already loaded this session — skipping.")
            return
        }
        
        isLoadingAd = true
        do {
            let isHomeOpened = UserDefaults.standard.bool(forKey: TR_SessionKeys.isHomeOpened)
            let unitId: String = {
                if isHomeOpened {
                    return !appopenId.isEmpty ? appopenId : (!second_appopen.isEmpty ? second_appopen : "ca-app-pub-3940256099942544/5575463023")
                } else {
                    return !second_appopen.isEmpty ? second_appopen : (!appopenId.isEmpty ? appopenId : "ca-app-pub-3940256099942544/5575463023")
                }
            }()
            print("🚀 [AppOpenBackAd] Loading with ID: \(unitId) | isHomeOpened: \(isHomeOpened)")
            appOpenAd = try await AppOpenAd.load(
                with: unitId,
                request: Request()
            )
            appOpenAd?.fullScreenContentDelegate = self
            loadTime = Date()
            hasLoadedOnce = true
            print("✅ [AppOpenBackAd] Successfully loaded with ID: \(unitId)")
        } catch {
            print("❌ [AppOpenBackAd] Failed to load: \(error.localizedDescription)")
            appOpenAd = nil
            loadTime = nil
        }
        isLoadingAd = false
    }
    
    // MARK: - Show Ad
    func showAdIfAvailable(completion: @escaping () -> Void) {
        if isShowingAd {
            print("⚠️ App open ad is already showing.")
            completion()
            return
        }
        guard let ad = appOpenAd else {
            print("⚠️ App open ad not available.")
            completion()
            return
        }
        if let topVC = UIApplication.topViewController {
            print("🎬 Presenting App Open Ad...")
            isShowingAd = true
            adCompletion = completion
            presentingVC = topVC
            ad.present(from: topVC)
        } else {
            completion()
        }
    }
    
    // MARK: - Ad Delegate Callbacks
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("ℹ️ Ad will present full screen content.")
        isShowingAd = true
        if let presented = presentingVC?.presentedViewController {
            presentedAdVC = presented
        }
    }
    
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("ℹ️ App open ad impression recorded.")
    }
    
    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        print("ℹ️ App open ad clicked.")
    }
    
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("ℹ️ App open ad will dismiss.")
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("✅ App open ad dismissed.")
        finishAdFlow()
    }
    
    func ad(_ ad: FullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ Ad failed to present: \(error.localizedDescription)")
        finishAdFlow()
    }
    
    private func finishAdFlow() {
        guard isShowingAd || adCompletion != nil else { return }
        isShowingAd = false
        appOpenAd = nil
        hasLoadedOnce = true
        presentedAdVC = nil
        presentingVC = nil
        
        let completion = adCompletion
        adCompletion = nil
        completion?()
        
        appOpenAdManagerDelegate?.appOpenAdManagerAdDidComplete(self)
    }
    
    // MARK: - Dismiss on iPad Rotation
    func dismissAdIfShowing() {
        guard isShowingAd else { return }
        print("🔄 [AppOpenBackAd] Dismissing App Open Back Ad due to iPad orientation rotation")
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isShowingAd else { return }
            let vcToDismiss = self.presentedAdVC ?? self.presentingVC?.presentedViewController
            
            if let vc = vcToDismiss, !vc.isBeingDismissed {
                vc.dismiss(animated: true) { [weak self] in
                    self?.finishAdFlow()
                }
            } else {
                self.finishAdFlow()
            }
        }
    }
    
    // MARK: - Reset for new session
    func resetForForeground() {
        print("🔄 Resetting TR_AppOpenAdManager for foreground session.")
        hasLoadedOnce = false
        appOpenAd = nil
        isShowingAd = false
        loadTime = nil
    }
}

// MARK: - Top View Controller helper
extension UIApplication {
    static var topViewController: UIViewController? {
        let activeScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            
        guard let windowScene = activeScene,
              let root = (windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first)?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
