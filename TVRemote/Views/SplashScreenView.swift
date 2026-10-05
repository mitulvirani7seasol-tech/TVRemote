//
//  SplashScreenView.swift
//  TV Remote
//
//  Created by iOS Developer on 14/09/2026.
//

import SwiftUI

struct SplashScreenView: View {
    var onFinished: () -> Void
    
    @State private var showSplashContent: Bool = false
    @State private var opacity: Double = 0.0
    @State private var smSplashScale: CGFloat = 0.88
    @State private var hasFinished: Bool = false
    
    var body: some View {
        ZStack {
            if showSplashContent {
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Center Logo & Title (1.5x scaled on iPad)
                    VStack(spacing: UIDevice.isIPad ? 28 : 20) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: UIDevice.isIPad ? 144 : 96,
                                height: UIDevice.isIPad ? 144 : 96
                            )
                            .shadow(color: Color.appPrimary.opacity(0.2), radius: 16, x: 0, y: 8)
                        
                        Text("TV Remote")
                            .font(.inter(.bold, size: 26))
                            .foregroundColor(Color(hex: "1A1D26"))
                            .tracking(0.3)
                    }
                    .scaleEffect(smSplashScale)
                    .opacity(opacity)
                    
                    Spacer()
                    
                    // Bottom Lottie Loader Animation
                    VStack(spacing: 12) {
                        AppLottieView(animationName: "loading bar")
                            .frame(
                                width: UIDevice.isIPad ? 210 : 140,
                                height: UIDevice.isIPad ? 9 : 6
                            )
                    }
                    .padding(.bottom, UIDevice.isIPad ? 60 : 50)
                    .opacity(opacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Image("BG")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        )
        .onAppear {
            // 1. Request UMP Consent Form and ATT dialog first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                AppConsentManager.shared.requestConsentAndTracking {
                    // 2. ONLY AFTER consent popup is dismissed, start Splash Screen animation and progress
                    startSplashAnimation()
                }
            }
        }
    }
    
    private func startSplashAnimation() {
        guard !hasFinished else { return }
        
        // Background pre-warm TV discovery
        DeviceConnectionManager.shared.startScanning()
        TR_RemoteViewModel.shared.startDiscovery()
        
        withAnimation(.easeOut(duration: 0.6)) {
            self.showSplashContent = true
            self.opacity = 1.0
            self.smSplashScale = 1.0
        }
        
        var isApiDone = false
        var isMinTimeDone = false
        
        func tryFinish() {
            guard isApiDone && isMinTimeDone && !self.hasFinished else { return }
            self.hasFinished = true
            self.finishNavigation()
        }
        
        // 1. Fetch Remote Configuration from AWS S3 JSON
        fetchRemoteConfiguration {
            isApiDone = true
            tryFinish()
        }
        
        // 2. Minimum splash screen loading animation duration (1.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            isMinTimeDone = true
            tryFinish()
        }
    }
    
    // MARK: - Remote Configuration Fetch from AWS S3 JSON
    func fetchRemoteConfiguration(completion: @escaping () -> Void) {
        guard let url = URL(string: getJSON) else {
            completion()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        sessionConfiguration.urlCache = nil
        
        let session = URLSession(configuration: sessionConfiguration)
        let requestTask = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ S3 API Error:", error.localizedDescription)
                DispatchQueue.main.async { completion() }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { completion() }
                return
            }
            do {
                if let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let appOpen = responseJSON["appopenId"] as? String, !appOpen.isEmpty { appopenId = appOpen }
                    if let native = responseJSON["nativeId"] as? String, !native.isEmpty { nativeId = native }
                    if let inter = responseJSON["interstialId"] as? String, !inter.isEmpty { interstialId = inter }
                    if let banner = responseJSON["bannerId"] as? String, !banner.isEmpty { bannerId = banner }
                    if let reward = responseJSON["rewardId"] as? String, !reward.isEmpty { rewardId = reward }
                    if let btnColor = responseJSON["addButtonColor"] as? String, !btnColor.isEmpty { addButtonColor = btnColor }
                    
                    if let configuration = responseJSON["extraFields"] as? [String: Any] {
                        small_native = configuration["small_native"] as? String ?? ""
                        second_small_native = configuration["second_small_native"] as? String ?? ""
                        second_native = configuration["second_native"] as? String ?? ""
                        second_appopen = configuration["second_appopen"] as? String ?? ""
                        androidBannerUrl = configuration["splash_banner"] as? String ?? androidBannerUrl
                        
                        iapLifetime = configuration["iapLifetime"] as? String ?? "true"
                        iapYearlyPlan = configuration["iapYearlyPlan"] as? String ?? "true"
                        iapMonthlyPlan = configuration["iapMonthlyPlan"] as? String ?? "true"
                        iapWeeklyPlan = configuration["iapWeeklyPlan"] as? String ?? "true"
                        
                        isShowPremium = configuration["isShowPremium"] as? String ?? "true"
                        pro_close_inter = configuration["pro_close_inter"] as? String ?? "true"
                        weatherAPIKey = configuration["weatherAPIKey"] as? String ?? ""
                        isYoutubeEnabled = configuration["isYoutubeEnabled"] as? String ?? "true"
                        isIPTVEnabled = configuration["isIPTVEnabled"] as? String ?? "false"
                        freeLimitCount = configuration["freeLimitCount"] as? String ?? "10"
                        cat_api = configuration["cat_api"] as? String ?? ""
                        cat_Identifier = configuration["cat_Identifier"] as? String ?? ""
                    }
                    
                    let customInterstitialCount = responseJSON["customInterstial"] as? Int ?? 0
                    
                    if let afterClickValue = responseJSON["afterClick"] as? String,
                       let clickCount = Int(afterClickValue) {
                        adsCount = clickCount
                    } else if let afterClickInt = responseJSON["afterClick"] as? Int {
                        adsCount = afterClickInt
                    } else {
                        adsCount = 4
                    }
                    
                    adsPlus = customInterstitialCount == 0 ? max(1, adsCount - 1) : adsCount
                    
                    DispatchQueue.main.async {
                        SM_AdCountViewModel.sharedd.afterClick = adsCount
                        print("==================================================")
                        print("📡 Remote Config API Response Loaded Successfully:")
                        print("   🔹 [Fresh Install / Before Home Ad IDs]:")
                        print("      - second_native:        \(second_native)")
                        print("      - second_small_native:  \(second_small_native)")
                        print("      - second_appopen:       \(second_appopen)")
                        print("   🔹 [Regular / After Home Ad IDs]:")
                        print("      - nativeId:             \(nativeId)")
                        print("      - small_native:         \(small_native)")
                        print("      - appopenId:            \(appopenId)")
                        print("      - interstialId:         \(interstialId)")
                        print("      - bannerId:             \(bannerId)")
                        print("   🔹 [Settings]:")
                        print("      - androidBannerUrl:     \(androidBannerUrl)")
                        print("      - afterClick:           \(adsCount)")
                        print("      - isShowPremium:        \(isShowPremium)")
                        print("==================================================")
                    }
                }
                DispatchQueue.main.async { completion() }
            } catch {
                print("❌ S3 JSON Parse Error:", error.localizedDescription)
                DispatchQueue.main.async { completion() }
            }
        }
        requestTask.resume()
    }
    
    private func finishNavigation() {
        withAnimation(.easeInOut(duration: 0.35)) {
            self.onFinished()
        }
    }
}
