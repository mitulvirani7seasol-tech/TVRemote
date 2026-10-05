//
//  NativeAd.swift
//  TV Remote Casting
//
//  Created by Ronik Hirpara on 17/10/25.
//

import Foundation
import SwiftUI
import GoogleMobileAds
import UIKit
import Combine

final class TR_NativeAdViewModel: NSObject, ObservableObject {
    @Published var nativeAd: NativeAd?
    @Published var smallNativeAd: NativeAd?
    @Published var secondNativeAd: NativeAd?
    @Published var secondSmallNativeAd: NativeAd?
    
    @Published var didFailToLoad: Bool = false
    @Published var didFailToSmallLoad: Bool = false
    @Published var didFailToSecondLoad: Bool = false
    @Published var didFailToSmallNativeLoad: Bool = false

    private var adLoader: AdLoader?
    private var smallAdLoader: AdLoader?
    private var secondAdLoader: AdLoader?
    private var secondSmallAdLoader: AdLoader?

    func refreshAd() {
        didFailToLoad = true
        nativeAd = nil
    }
    
    func refreshSecondNative() {
        didFailToSecondLoad = true
        secondNativeAd = nil
    }
    
    func refreshSmallNative() {
        didFailToSmallLoad = true
        smallNativeAd = nil
    }
    
    func refreshSecondSmallNative() {
        didFailToSmallNativeLoad = true
        secondSmallNativeAd = nil
    }
}

// MARK: - Delegates
extension TR_NativeAdViewModel: NativeAdLoaderDelegate, NativeAdDelegate {
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        DispatchQueue.main.async {
            if adLoader == self.smallAdLoader {
                self.smallNativeAd = nativeAd
                self.didFailToSmallLoad = false
                nativeAd.delegate = self
                print("✅ [Small NativeAd] Loaded successfully with ID: \(adLoader.adUnitID)")
            } else if adLoader == self.secondAdLoader {
                self.secondNativeAd = nativeAd
                self.didFailToSecondLoad = false
                nativeAd.delegate = self
                print("✅ [Second NativeAd Large] Loaded successfully with ID: \(adLoader.adUnitID)")
            } else if adLoader == self.secondSmallAdLoader {
                self.secondSmallNativeAd = nativeAd
                self.didFailToSmallNativeLoad = false
                nativeAd.delegate = self
                print("✅ [Second Small NativeAd] Loaded successfully with ID: \(adLoader.adUnitID)")
            } else {
                self.nativeAd = nativeAd
                self.didFailToLoad = false
                nativeAd.delegate = self
                print("✅ [NativeAd Large] Loaded successfully with ID: \(adLoader.adUnitID)")
            }
        }
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        DispatchQueue.main.async {
            if adLoader == self.smallAdLoader {
                self.didFailToSmallLoad = true
                print("❌ [Small NativeAd] Failed to load (ID: \(adLoader.adUnitID)): \(error.localizedDescription)")
            } else if adLoader == self.secondAdLoader {
                self.didFailToSecondLoad = true
                print("❌ [Second NativeAd Large] Failed to load (ID: \(adLoader.adUnitID)): \(error.localizedDescription)")
            } else if adLoader == self.secondSmallAdLoader {
                self.didFailToSmallNativeLoad = true
                print("❌ [Second Small NativeAd] Failed to load (ID: \(adLoader.adUnitID)): \(error.localizedDescription)")
            } else {
                self.didFailToLoad = true
                print("❌ [NativeAd Large] Failed to load (ID: \(adLoader.adUnitID)): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - NativeAdDelegate
    func nativeAdDidRecordClick(_ nativeAd: NativeAd) { print("🖱️ Click recorded") }
    func nativeAdDidRecordImpression(_ nativeAd: NativeAd) { print("👀 Impression recorded") }
    func nativeAdWillPresentScreen(_ nativeAd: NativeAd) { print("📱 Will present screen") }
    func nativeAdWillDismissScreen(_ nativeAd: NativeAd) { print("📴 Will dismiss screen") }
    func nativeAdDidDismissScreen(_ nativeAd: NativeAd) { print("✅ Screen dismissed") }
}

//class TR_NativeAdViewModel: NSObject, ObservableObject, NativeAdLoaderDelegate {
//    @Published var nativeAd: NativeAd?
//    private var adLoader: AdLoader!
//    
//    func refreshAd() {
//        adLoader = AdLoader(
//            adUnitID: SessionManager.shared.getSplashData()?.nativeID ?? "",
//            rootViewController: nil,
//            adTypes: [.native], options: nil)
//        adLoader.delegate = self
//        adLoader.load(Request())
//    }
//    
//    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
//        self.nativeAd = nativeAd
//        nativeAd.delegate = self
//    }
//    
//    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
//        print("\(adLoader) failed with error: \(error.localizedDescription)")
//    }
//}
//
//extension TR_NativeAdViewModel: NativeAdDelegate {
//  func nativeAdDidRecordClick(_ nativeAd: NativeAd) {
//    print("\(#function) called")
//  }
//
//  func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {
//    print("\(#function) called")
//  }
//
//  func nativeAdWillPresentScreen(_ nativeAd: NativeAd) {
//    print("\(#function) called")
//  }
//
//  func nativeAdWillDismissScreen(_ nativeAd: NativeAd) {
//    print("\(#function) called")
//  }
//
//  func nativeAdDidDismissScreen(_ nativeAd: NativeAd) {
//    print("\(#function) called")
//  }
//}



