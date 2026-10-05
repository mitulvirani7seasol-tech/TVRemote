import Foundation
import GoogleMobileAds
import SwiftUI

final class TR_InterstitialAdManager: NSObject, FullScreenContentDelegate {

    // MARK: - Private Properties
    private var interstitial: InterstitialAd?
    private var isLoadings: Bool = false
    private var pendingDismissCompletion: (() -> Void)?
    private weak var presentingVC: UIViewController?
    private weak var presentedAdVC: UIViewController?

    static var activeManagers = NSHashTable<TR_InterstitialAdManager>.weakObjects()

    // MARK: - Initialization
    override init() {
        super.init()
        TR_InterstitialAdManager.activeManagers.add(self)
    }

    func update() {
        load()
    }

    func load() {
        guard !isLoadings else {
            print("⚙️ [AdManager] Already loading an interstitial, skipping duplicate request.")
            return
        }

        isLoadings = true

        let adUnit = !interstialId.isEmpty ? interstialId : "ca-app-pub-3940256099942544/4411468910"
        let request = Request()
        print("📡 [AdManager] Loading interstitial ad for unit ID: \(adUnit)")

        InterstitialAd.load(with: adUnit, request: request) { ad, error in
            self.isLoadings = false

            if let error {
                print("❌ [AdManager] Failed to load interstitial: \(error.localizedDescription)")
                return
            }

            self.interstitial = ad
            self.interstitial?.fullScreenContentDelegate = self
            print("✅ [AdManager] Interstitial loaded successfully for ID: \(adUnit)")
        }
    }

    /// Presents the interstitial ad if available; otherwise reloads.
    func present() {
        present(onDismiss: nil)
    }

    func present(onDismiss: (() -> Void)? = nil) {
        guard let root = UIApplication.topViewController else {
            print("⚠️ [AdManager] No rootViewController found for presentation.")
            onDismiss?()
            return
        }

        guard let interstitial else {
            print("⚠️ [AdManager] Ad not ready, attempting reload.")
            load()
            onDismiss?()
            return
        }

        pendingDismissCompletion = onDismiss
        TR_AdState.shared.isShowingInterstitial = true
        presentingVC = root
        interstitial.present(from: root)
    }

    // MARK: - GADFullScreenContentDelegate

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("ℹ️ [AdManager] Interstitial will present full screen content.")
        TR_AdState.shared.isShowingInterstitial = true
        if let presented = presentingVC?.presentedViewController {
            presentedAdVC = presented
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("ℹ️ [AdManager] Interstitial dismissed. Preparing next ad.")
        cleanupAndCompleteDismissal()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ [AdManager] Failed to present interstitial: \(error.localizedDescription)")
        cleanupAndCompleteDismissal()
    }

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("👁️ [AdManager] Interstitial impression recorded.")
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        print("🖱️ [AdManager] Interstitial clicked.")
    }

    // MARK: - Dismiss on iPad Rotation
    func dismissAdIfShowing() {
        guard TR_AdState.shared.isShowingInterstitial else { return }
        print("🔄 [InterstitialAd] Dismissing Interstitial Ad due to iPad orientation rotation")
        DispatchQueue.main.async { [weak self] in
            guard let self = self, TR_AdState.shared.isShowingInterstitial else { return }
            let vcToDismiss = self.presentedAdVC ?? self.presentingVC?.presentedViewController
            
            if let vc = vcToDismiss, !vc.isBeingDismissed {
                vc.dismiss(animated: true) { [weak self] in
                    self?.cleanupAndCompleteDismissal()
                }
            } else {
                self.cleanupAndCompleteDismissal()
            }
        }
    }
    
    private func cleanupAndCompleteDismissal() {
        guard TR_AdState.shared.isShowingInterstitial || pendingDismissCompletion != nil else { return }
        TR_AdState.shared.isShowingInterstitial = false
        interstitial = nil
        presentedAdVC = nil
        presentingVC = nil
        load()
        
        let completion = pendingDismissCompletion
        pendingDismissCompletion = nil
        completion?()
    }

    static func dismissAnyActiveInterstitial() {
        for manager in activeManagers.allObjects {
            manager.dismissAdIfShowing()
        }
    }
}
