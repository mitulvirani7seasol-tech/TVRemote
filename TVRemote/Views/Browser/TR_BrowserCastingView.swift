//
//  TR_BrowserCastingView.swift
//  TV Remote
//

import SwiftUI
import WebKit
import AVFAudio

// Helper: Custom WKWebView Representable
struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView
    
    func makeUIView(context: Context) -> WKWebView {
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.isOpaque = false
        uiView.backgroundColor = .clear
        uiView.scrollView.backgroundColor = .clear
    }
}

struct TR_BrowserCastingView: View {
    @ObservedObject var languageManager = TR_LanguageManager.shared
    @StateObject private var browserVM = BrowserViewModel()
    @ObservedObject private var connectivityVM = TR_DeviceConnectivityViewModel.shared
    @ObservedObject private var connectionManager = DeviceConnectionManager.shared
    
    let initialURL: String
    var isOpenFromYoutube: Bool = false
    var onBack: () -> Void
    var onCastTapped: (() -> Void)? = nil
    var onOpenPlayer: ((URL, String, URL?, Double) -> Void)? = nil
    
    @AppStorage(TR_SessionKeys.isPro) var isPro = false
    @State private var searchInput: String = ""
    @State private var showShareSheet = false
    @State private var showCastingToast = false
    @State private var toastMessage = ""
    @State private var showPremium = false
    
    init(
        initialURL: String,
        isOpenFromYoutube: Bool = false,
        onBack: @escaping () -> Void,
        onCastTapped: (() -> Void)? = nil,
        onOpenPlayer: ((URL, String, URL?, Double) -> Void)? = nil
    ) {
        self.initialURL = initialURL
        self.isOpenFromYoutube = isOpenFromYoutube
        self.onBack = onBack
        self.onCastTapped = onCastTapped
        self.onOpenPlayer = onOpenPlayer
    }
    
    private var isAirPlayConnected: Bool {
        TR_AirPlayManager.shared.isAirPlayConnected ||
        connectionManager.isAirPlayConnected ||
        (TR_RemoteViewModel.shared.connectedTVType == .AIRPLAY && TR_RemoteViewModel.shared.isConnectedSuccessfully)
    }
    
    private var isTVConnected: Bool {
        return DeviceConnectionManager.shared.isActuallyConnected
    }
    
    private var isWebOSTVConnected: Bool {
        connectivityVM.getConnectedTvType() == .LG ||
        TR_RemoteViewModel.shared.connectedTVType == .LG ||
        connectivityVM.connectSDKDiscoveryModel.isConnectedToLG ||
        (TR_RemoteViewModel.shared.currentTVManager is TR_LGControlManager)
    }
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { UIDevice.isIPad || horizontalSizeClass == .regular }
    
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let horizontalPadding: CGFloat = isIPad ? (isLandscape ? 36 : 24) : 16
            
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // 1. Top Custom Navigation Header (Back on Left, Title in Center, Cast with ic_cast on Right)
                    topNavigationBar(isIPad: isIPad, horizontalPadding: horizontalPadding)
                        .padding(.top, isIPad ? 16 : 8)
                        .padding(.bottom, isIPad ? 10 : 6)
                    
                    // 2. Search / Enter URL Bar (Top Positioned)
                    searchBar(isIPad: isIPad, horizontalPadding: horizontalPadding)
                        .padding(.bottom, isIPad ? 10 : 8)
                    
                    // 3. Loading Progress Bar
                    if browserVM.isLoading {
                        ProgressView(value: browserVM.estimatedProgress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "8E03A1")))
                            .frame(height: 3)
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, 6)
                    }
                    
                    // 4. Main Web View Surface Card with Floating Cast to TV Button
                    ZStack(alignment: .bottom) {
                        WebViewRepresentable(webView: browserVM.webView)
                            .clipShape(RoundedRectangle(cornerRadius: isIPad ? 26 : 20, style: .continuous))
                        
                        // Floating "Cast to TV" Card (Image 3: ic_tv_cast + Arrow Button)
                        let hasVideoLink = browserVM.streamableVideoURL != nil
                        let isFetching = browserVM.isFetchingStream
                        let isButtonEnabled = hasVideoLink || !isTVConnected
                        
                        if isButtonEnabled || isFetching {
                            Button(action: {
                                if isTVConnected {
                                    if hasVideoLink {
                                        castCurrentWebOrVideo()
                                    }
                                } else {
                                    onCastTapped?()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    // Left Icon Container (App Gradient Rounded Square with ic_tv_cast)
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                             .fill(
                                                LinearGradient(
                                                    colors: isTVConnected
                                                        ? [Color(hex: "8E03A1"), Color(hex: "E25F89")]
                                                        : [Color(hex: "6B7280"), Color(hex: "4B5563")],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: isIPad ? 44 : 38, height: isIPad ? 44 : 38)
                                        
                                        Image("ic_tv_cast")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(.white)
                                            .scaledToFit()
                                            .frame(width: isIPad ? 26 : 22, height: isIPad ? 26 : 22)
                                    }
                                    
                                    // Center Title
                                    Text(isTVConnected ? languageManager.localized("cast_to_tv") : languageManager.localized("connect_device"))
                                        .font(.inter(.semiBold, size: isIPad ? 16 : 14, autoScaleForPad: false))
                                        .foregroundColor(Color(hex: "111827"))
                                    
                                    Spacer()
                                    
                                    // Right Arrow Circle Button
                                    if isFetching {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "8E03A1")))
                                            .scaleEffect(isIPad ? 1.0 : 0.85)
                                    } else {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: isTVConnected
                                                            ? [Color(hex: "8E03A1"), Color(hex: "E25F89")]
                                                            : [Color(hex: "6B7280"), Color(hex: "4B5563")],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: isIPad ? 36 : 30, height: isIPad ? 36 : 30)
                                            
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: isIPad ? 14 : 12, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .padding(.horizontal, isIPad ? 16 : 14)
                                .padding(.vertical, isIPad ? 12 : 10)
                                .frame(maxWidth: isIPad ? 340 : 280)
                                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .glassCard(cornerRadius: 18, isInteractive: true)
                                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
                            }
                            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
                            .padding(.bottom, isIPad ? 22 : 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: hasVideoLink)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: isIPad ? 26 : 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: isIPad ? 26 : 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.70), Color.white.opacity(0.20)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, isIPad ? 14 : 10)
                    
                    // 5. Bottom Browser Navigation Toolbar
                    bottomFloatingToolbar(isIPad: isIPad, horizontalPadding: horizontalPadding)
                        .padding(.bottom, isIPad ? 24 : 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 6. Toast Banner for Casting Status
                if showCastingToast {
                    HStack(spacing: 8) {
                        Image(systemName: "tv.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text(toastMessage)
                            .font(.inter(.semiBold, size: isIPad ? 15 : 13, autoScaleForPad: false))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(hex: "111827").opacity(0.92))
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
                    .padding(.bottom, isIPad ? 140 : 120)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(
            Image("BG")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        )
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationBarHidden(true)
        .enableNativeSwipeBack()
        .onAppear {
            AudioPlaybackController.dismissGlobalExternalDisplay()
            TR_ImageCastAirPlayManager.shared.stopPlayback()
            TR_CastVideoPlayerManager.shared.stopPlayback()
            searchInput = initialURL
            browserVM.loadSearchOrURL(input: initialURL)
            
            if !isOpenFromYoutube, isWebOSTVConnected, let url = URL(string: initialURL) {
                connectivityVM.connectSDKDiscoveryModel.sendMediaToLGTVWeb(mediaUrl: url)
            }
        }
        .onDisappear {
            TR_CastVideoPlayerManager.shared.stopPlayback()
        }
        .onChange(of: browserVM.searchInputText) { newURL in
            if !newURL.isEmpty {
                searchInput = newURL
            }
        }
        .onChange(of: browserVM.streamableVideoURL) { newStreamURL in
            if newStreamURL != nil {
                AudioPlaybackController.dismissGlobalExternalDisplay()
                TR_ImageCastAirPlayManager.shared.stopPlayback()
                if isAirPlayConnected && isPro {
                    castCurrentWebOrVideo()
                }
            }
        }
        .onChange(of: isTVConnected) { connected in
            if connected && isAirPlayConnected && browserVM.streamableVideoURL != nil && isPro {
                castCurrentWebOrVideo()
            }
        }
        .onChange(of: TR_RemoteViewModel.shared.showSearchingSheet) { isShowing in
            if !isShowing && isAirPlayConnected && browserVM.streamableVideoURL != nil && isPro {
                castCurrentWebOrVideo()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = browserVM.currentURL {
                TR_ShareSheet(activityItems: [url])
            }
        }
    }
    
    // MARK: - 1. Top Navigation Bar (Back, "Web", Cast with ic_cast)
    @ViewBuilder
    private func topNavigationBar(isIPad: Bool, horizontalPadding: CGFloat) -> some View {
        HStack(alignment: .center) {
            // Back Button
            GlassBackButton(isIPad: isIPad, action: {
                let isMirroring = DeviceConnectionManager.shared.isMirroringActive 
                    || UIScreen.main.isCaptured 
                    || (UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") == true)
                    || TR_MirroringServerManager.shared.isMirroringActive
                if !isMirroring {
                    connectivityVM.stopMediaCasting()
                }
                onBack()
            })
            
            Spacer()
            
            // Screen Title: "Youtube" or "Web"
            Text(isOpenFromYoutube ? languageManager.localized("youtube") : languageManager.localized("web"))
                .font(.inter(.bold, size: isIPad ? 22 : 18, autoScaleForPad: false))
                .foregroundColor(Color(hex: "111827"))
            
            Spacer()
            
            // Cast Button with Liquid Glass Container
            Button(action: {
                HapticFeedback.generate(.light)
                onCastTapped?()
            }) {
                ZStack {
                    Image("ic_cast")
                        .resizable()
                        .scaledToFit()
                        .frame(width: isIPad ? 24 : 20, height: isIPad ? 24 : 20)
                }
                .frame(width: isIPad ? 46 : 40, height: isIPad ? 46 : 40)
                .glassModifier(cornerRadius: (isIPad ? 46 : 40) / 2)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
        }
        .padding(.horizontal, horizontalPadding)
    }
    
    // MARK: - 2. Search / Enter URL Bar
    @ViewBuilder
    private func searchBar(isIPad: Bool, horizontalPadding: CGFloat) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: isIPad ? 18 : 15, weight: .medium))
                .foregroundColor(Color(hex: "9CA3AF"))
              
            TextField(languageManager.localized("search_or_enter_url"), text: $searchInput, onCommit: {
                submitSearch()
            })
            .font(.inter(.regular, size: isIPad ? 15 : 13, autoScaleForPad: false))
            .foregroundColor(Color(hex: "111827"))
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .keyboardType(.webSearch)
            
            Button(action: {
                HapticFeedback.generate(.light)
                browserVM.reload()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: isIPad ? 17 : 14, weight: .medium))
                    .foregroundColor(Color(hex: "9CA3AF"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, isIPad ? 16 : 14)
        .frame(height: isIPad ? 50 : 42)
        .glassCard(cornerRadius: isIPad ? 18 : 14)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        .padding(.horizontal, horizontalPadding)
    }
    
    // MARK: - 3. Bottom Floating Navigation Toolbar (4-button Design)
    @ViewBuilder
    private func bottomFloatingToolbar(isIPad: Bool, horizontalPadding: CGFloat) -> some View {
        HStack {
            // 1. Back
            Button(action: {
                HapticFeedback.generate(.light)
                browserVM.goBack()
            }) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: isIPad ? 20 : 16, weight: .semibold))
                    .foregroundStyle(
                        browserVM.canGoBack
                        ? LinearGradient(
                            colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color(hex: "9CA3AF"), Color(hex: "9CA3AF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(maxWidth: .infinity)
            }
            .disabled(!browserVM.canGoBack)
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
            
            // 2. Forward
            Button(action: {
                HapticFeedback.generate(.light)
                browserVM.goForward()
            }) {
                Image(systemName: "chevron.forward")
                    .font(.system(size: isIPad ? 20 : 16, weight: .semibold))
                    .foregroundStyle(
                        browserVM.canGoForward
                        ? LinearGradient(
                            colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color(hex: "9CA3AF"), Color(hex: "9CA3AF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(maxWidth: .infinity)
            }
            .disabled(!browserVM.canGoForward)
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
            
            // 3. Share
            Button(action: {
                HapticFeedback.generate(.light)
                showShareSheet = true
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: isIPad ? 20 : 16, weight: .semibold))
                    .foregroundColor(Color(hex: "7E8B9B"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
            
            // 4. Tabs / Windows (Back to shortcuts screen)
            Button(action: {
                HapticFeedback.generate(.light)
                let isMirroring = DeviceConnectionManager.shared.isMirroringActive 
                    || UIScreen.main.isCaptured 
                    || (UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") == true)
                    || TR_MirroringServerManager.shared.isMirroringActive
                if !isMirroring {
                    connectivityVM.stopMediaCasting()
                }
                onBack()
            }) {
                Image(systemName: "square.on.square")
                    .font(.system(size: isIPad ? 20 : 16, weight: .semibold))
                    .foregroundColor(Color(hex: "7E8B9B"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
        }
        .padding(.horizontal, isIPad ? 20 : 14)
        .frame(height: isIPad ? 52 : 44)
        .glassCard(cornerRadius: isIPad ? 22 : 18)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.horizontal, horizontalPadding)
    }
    
    // MARK: - Web & Video Casting
    private func castCurrentWebOrVideo() {
        guard isTVConnected else {
            onCastTapped?()
            return
        }
        
        guard let streamURL = browserVM.streamableVideoURL else {
            print("⚠️ Waiting for streamableVideoURL")
            return
        }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Mute & pause mobile in-page video/audio so sound plays exclusively on the TV
        browserVM.muteAndPauseInPageMedia()
        
        let connectedName = DeviceConnectionManager.shared.connectedDevice?.name
        let tvName = isAirPlayConnected ? "AirPlay TV" : (TR_RemoteViewModel.shared.deviceName ?? connectedName ?? "TV")
        let ytid = browserVM.detectedVideoID ?? (browserVM.currentURL != nil ? browserVM.extractYouTubeID(from: browserVM.currentURL!.absoluteString) : nil)
        let videoTitle = !browserVM.detectedVideoTitle.isEmpty ? browserVM.detectedVideoTitle : (browserVM.pageTitle.isEmpty ? "YouTube Video" : browserVM.pageTitle)
        let thumb = browserVM.detectedVideoThumbnailURL ?? (ytid != nil ? URL(string: "https://img.youtube.com/vi/\(ytid!)/hqdefault.jpg") : nil)
        let dur = browserVM.detectedVideoDuration > 0 ? browserVM.detectedVideoDuration : 276.0
        
        if isAirPlayConnected {
            AudioPlaybackController.dismissGlobalExternalDisplay()
            TR_ImageCastAirPlayManager.shared.stopPlayback()
            TR_CastVideoPlayerManager.shared.stopPlayback()
            toastMessage = "Playing on \(tvName)"
        } else {
            let tvType = connectivityVM.getConnectedTvType()
            if isOpenFromYoutube {
                if tvType == .LG {
                    connectivityVM.connectSDKDiscoveryModel.sendMediaToLGTVYT(mediaUrl: streamURL, mimeType: "text/html")
                } else {
                    connectivityVM.CastMedia(
                        url: streamURL,
                        mediaType: "video/mp4",
                        title: videoTitle,
                        des: "",
                        imgHei: 1024,
                        imgWid: 1024,
                        mediaURL: thumb
                    )
                }
            } else {
                if tvType == .LG {
                    if let videoID = ytid ?? browserVM.detectedVideoID, !videoID.isEmpty {
                        connectivityVM.connectSDKDiscoveryModel.sendYouTubeToLGTV(videoID: videoID, webURL: browserVM.currentURL)
                    } else if let currentURL = browserVM.currentURL {
                        connectivityVM.connectSDKDiscoveryModel.sendMediaToLGTVWeb(mediaUrl: currentURL)
                    } else {
                        connectivityVM.connectSDKDiscoveryModel.sendMediaToLGTVWeb(mediaUrl: URL(string: "https://www.youtube.com")!)
                    }
                } else if tvType == .ROKU {
                    connectivityVM.connectSDKDiscoveryModel.sendMediaToLGTVYT(mediaUrl: streamURL, mimeType: "text/html")
                } else {
                    connectivityVM.CastMedia(
                        url: streamURL,
                        mediaType: "video/mp4",
                        title: videoTitle,
                        des: "",
                        imgHei: 1024,
                        imgWid: 1024,
                        mediaURL: thumb
                    )
                }
            }
            toastMessage = "Casting Video to \(tvName)"
        }
        
        // Redirect to YouTube Player Screen
        onOpenPlayer?(streamURL, videoTitle, thumb, dur)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showCastingToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showCastingToast = false
            }
        }
    }
    
    private func submitSearch() {
        let trimmed = searchInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        browserVM.loadSearchOrURL(input: trimmed)
        
        if !isOpenFromYoutube && isWebOSTVConnected {
            let validURLString: String
            if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
                validURLString = trimmed
            } else if trimmed.contains(".") && !trimmed.contains(" ") {
                validURLString = "https://\(trimmed)"
            } else {
                let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
                validURLString = "https://www.google.com/search?q=\(encoded)"
            }
            if let url = URL(string: validURLString) {
                connectivityVM.connectSDKDiscoveryModel.sendMediaToLGTVWeb(mediaUrl: url)
            }
        }
    }
}
