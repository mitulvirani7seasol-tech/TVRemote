//
//  MainDashboardView.swift
//  TV Remote
//

import SwiftUI
import AVFoundation
import Photos
import StoreKit

enum TR_AppRoute: Hashable {
    case photosGallery(MediaGalleryTab)
    case photoPlayer(assetIdentifier: String, index: Int)
    case videoPlayer(assetIdentifier: String, index: Int)
    case audioPlayer(track: MusicItem, tracks: [MusicItem], index: Int)
    case settings
    case languageSelection
    case quickGuide
    case iptv
    case iptvChannels(title: String, channels: [TR_Channel])
    case iptvPlayer(channels: [TR_Channel], index: Int)
    case browser
    case browserCasting(url: String, isOpenFromYoutube: Bool = false)
    case youtubePlayer(YouTubePlayerData)
}

struct MainDashboardView: View {
    @ObservedObject var languageManager = TR_LanguageManager.shared
    var onOpenLanguage: () -> Void
    
    @State private var navigationPath = NavigationPath()
    @State private var selectedTab: TabSelection = .remote
    @State private var showConnectToTVSheet: Bool = false
    @State private var showKeypadSheet: Bool = false
    @State private var showKeyboardSheet: Bool = false
    @State private var showInputSourceSheet: Bool = false
    @State private var showChannelsSheet: Bool = false
    @State private var selectedInputSource: TVInputSource = .av1
    @State private var typedText: String = ""
    @State private var channelInput: String = ""
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @ObservedObject private var remoteVM = TR_RemoteViewModel.shared
    @ObservedObject private var deviceManager = DeviceConnectionManager.shared
    @ObservedObject private var commonVM = TR_DeviceConnectivityViewModel.shared
    @State private var showAirplayDisconnectAlert: Bool = false
    @State private var showRateAlert: Bool = false
    @State private var isKeyboardActive: Bool = false
    @State private var isKeyboardVisible: Bool = false
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { UIDevice.isIPad || horizontalSizeClass == .regular }
    
    private var isAnyModalOpen: Bool {
        showKeypadSheet || showKeyboardSheet || showInputSourceSheet || showChannelsSheet
    }
    
    private var isAirplayActive: Bool {
        TR_AirPlayManager.shared.isAirPlayConnected
            || deviceManager.isAirPlayConnected
            || (remoteVM.connectedTVType == .AIRPLAY && remoteVM.isConnectedSuccessfully)
    }
    
    private var isTVConnected: Bool {
        deviceManager.isActuallyConnected
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Navigation Stack (Root TR_Tab Views & Pushed Sub-Screens)
            NavigationStack(path: $navigationPath) {
                ZStack(alignment: .bottom) {
                    // Main TR_Tab Views
                    Group {
                        switch selectedTab {
                        case .remote:
                            RemoteControlView(
                                isKeyboardActive: $isKeyboardActive,
                                onOpenSettings: {
                                    withAnimation {
                                        selectedTab = .settings
                                    }
                                },
                                onOpenDeviceDiscovery: {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                        showConnectToTVSheet = true
                                    }
                                },
                                onOpenKeypad: {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                        showKeypadSheet = true
                                    }
                                },
                                onOpenKeyboard: {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                        showKeyboardSheet = true
                                    }
                                },
                                onOpenInputSource: {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                        showInputSourceSheet = true
                                    }
                                },
                                onOpenChannels: {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                        showChannelsSheet = true
                                    }
                                }
                            )
                        case .casting:
                            TR_CastingHubView(
                                onSelectFeature: { feature in
                                    if feature == "photos" {
                                        navigationPath.append(TR_AppRoute.photosGallery(.photos))
                                    } else if feature == "videos" {
                                        navigationPath.append(TR_AppRoute.photosGallery(.videos))
                                    } else if feature == "audio" || feature == "music" {
                                        navigationPath.append(TR_AppRoute.photosGallery(.audio))
                                    } else if feature == "iptv" {
                                        navigationPath.append(TR_AppRoute.iptv)
                                    } else if feature == "web" || feature == "browser" {
                                        navigationPath.append(TR_AppRoute.browser)
                                    } else if feature == "youtube" {
                                        navigationPath.append(TR_AppRoute.browserCasting(url: "https://www.youtube.com", isOpenFromYoutube: true))
                                    }
                                },
                                onOpenConnectToTV: {
                                    withAnimation(.easeInOut(duration: 0.28)) {
                                        showConnectToTVSheet = true
                                    }
                                },
                                onOpenSettings: {
                                    navigationPath.append(TR_AppRoute.settings)
                                }
                            )
                        case .settings:
                            SettingsView(
                                onOpenLanguage: {
                                    navigationPath.append(TR_AppRoute.languageSelection)
                                },
                                onCastTapped: {
                                    withAnimation(.easeInOut(duration: 0.28)) {
                                        showConnectToTVSheet = true
                                    }
                                }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .disabled(isAnyModalOpen)
                    
                    // Bottom Floating Tab Bar
                    MainTabBarView(
                        selectedTab: $selectedTab
                    )
                    .zIndex(50)
                    .padding(.bottom, 8)
                    .disabled(isAnyModalOpen)
                    .offset(y: isKeyboardActive ? 300 : 0)
                    .opacity(isKeyboardActive ? 0 : 1)
                    .animation(.spring(response: 0.30, dampingFraction: 0.85), value: isKeyboardActive)
                }
                .background(
                    Image("BG")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                )
                .toolbar(.hidden, for: .navigationBar)
                .navigationBarBackButtonHidden(true)
                .navigationDestination(for: TR_AppRoute.self) { route in
                    switch route {
                    case .photosGallery(let tab):
                        PhotosGalleryView(
                            initialTab: tab,
                            onBack: {
                                if !navigationPath.isEmpty {
                                    navigationPath.removeLast()
                                }
                            },
                            onCastTapped: {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    showConnectToTVSheet = true
                                }
                            },
                            onSelectPhoto: { asset, index in
                                if isAirplayActive {
                                    TR_ImageCastAirPlayManager.shared.playPHAssetImage(asset)
                                } else if isTVConnected {
                                    navigationPath.append(TR_AppRoute.photoPlayer(assetIdentifier: asset.localIdentifier, index: index))
                                } else {
                                    withAnimation(.easeInOut(duration: 0.28)) {
                                        showConnectToTVSheet = true
                                    }
                                }
                            },
                            onSelectVideo: { asset, index in
                                if isAirplayActive {
                                    TR_CastVideoPlayerManager.shared.playPHAssetVideo(asset)
                                } else if isTVConnected {
                                    navigationPath.append(TR_AppRoute.videoPlayer(assetIdentifier: asset.localIdentifier, index: index))
                                } else {
                                    withAnimation(.easeInOut(duration: 0.28)) {
                                        showConnectToTVSheet = true
                                    }
                                }
                            },
                            onSelectAudio: { track, tracks, index in
                                if isTVConnected {
                                    navigationPath.append(TR_AppRoute.audioPlayer(track: track, tracks: tracks, index: index))
                                } else {
                                    withAnimation(.easeInOut(duration: 0.28)) {
                                        showConnectToTVSheet = true
                                    }
                                }
                            }
                        )
                        .navigationBarBackButtonHidden(true)
                    case .photoPlayer(let assetIdentifier, let index):
                        let asset = PhotoGalleryManager.shared.photoAssets.first(where: { $0.localIdentifier == assetIdentifier })
                        PhotoCastPlayerView(
                            initialAsset: asset,
                            initialIndex: index,
                            onBack: {
                                if !navigationPath.isEmpty {
                                    navigationPath.removeLast()
                                }
                            },
                            onCastTapped: {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    showConnectToTVSheet = true
                                }
                            }
                        )
                        .navigationBarBackButtonHidden(true)
                    case .videoPlayer(let assetIdentifier, let index):
                        let asset = PhotoGalleryManager.shared.videoAssets.first(where: { $0.localIdentifier == assetIdentifier })
                        VideoCastPlayerView(
                            initialAsset: asset,
                            initialIndex: index,
                            onBack: {
                                if !navigationPath.isEmpty {
                                    navigationPath.removeLast()
                                }
                            },
                            onCastTapped: {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    showConnectToTVSheet = true
                                }
                            }
                        )
                        .navigationBarBackButtonHidden(true)
                    case .audioPlayer(let track, let tracks, let index):
                        AudioCastPlayerView(
                            initialTrack: track,
                            tracks: tracks,
                            initialIndex: index,
                            onBack: {
                                if !navigationPath.isEmpty {
                                    navigationPath.removeLast()
                                }
                            },
                            onCastTapped: {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    showConnectToTVSheet = true
                                }
                            }
                        )
                        .navigationBarBackButtonHidden(true)
                    case .settings:
                        SettingsView(
                            onBack: {
                                if !navigationPath.isEmpty {
                                    navigationPath.removeLast()
                                }
                            },
                            onOpenLanguage: {
                                navigationPath.append(TR_AppRoute.languageSelection)
                            },
                            onCastTapped: {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    showConnectToTVSheet = true
                                }
                            }
                        )
                        .navigationBarBackButtonHidden(true)
                    case .languageSelection:
                        LanguageSelectionView(
                            onContinue: {
                                if !navigationPath.isEmpty {
                                    navigationPath.removeLast()
                                }
                            }
                        )
                        .navigationBarBackButtonHidden(true)
                    case .quickGuide:
                        TR_QuickGuideView(
                            tvType: TR_RemoteViewModel.shared.connectedTVType,
                            onBack: {
                                if !navigationPath.isEmpty {
                                    navigationPath.removeLast()
                                }
                            }
                        )
                        .navigationBarBackButtonHidden(true)
                    case .iptv:
                        TR_IPTVView(
                            onBack: {
                                if !navigationPath.isEmpty {
                                    navigationPath.removeLast()
                                }
                            },
                            onCastTapped: {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    showConnectToTVSheet = true
                                }
                            },
                            onSelectChannels: { title, channels in
                                navigationPath.append(TR_AppRoute.iptvChannels(title: title, channels: channels))
                            }
                        )
                        .navigationBarBackButtonHidden(true)
                    case .iptvChannels(let title, let channels):
                        IPTVChannelListView(
                            title: title,
                            channels: channels,
                            onBack: {
                                if !navigationPath.isEmpty {
                                    navigationPath.removeLast()
                                }
                            },
                            onCastTapped: {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    showConnectToTVSheet = true
                                }
                            },
                            onSelectChannel: { channels, index in
                                if isTVConnected {
                                    navigationPath.append(TR_AppRoute.iptvPlayer(channels: channels, index: index))
                                } else {
                                    withAnimation(.easeInOut(duration: 0.28)) {
                                        showConnectToTVSheet = true
                                    }
                                }
                            }
                        )
                        .navigationBarBackButtonHidden(true)
                    case .iptvPlayer(let channels, let index):
                        IPTVPlayerView(
                            channels: channels,
                            initialIndex: index,
                            onBack: {
                                if !navigationPath.isEmpty {
                                    navigationPath.removeLast()
                                }
                            },
                            onCastTapped: {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    showConnectToTVSheet = true
                                }
                            }
                        )
                        .navigationBarBackButtonHidden(true)
                    case .browser:
                        TR_BrowserView(
                            onBack: {
                                if !navigationPath.isEmpty {
                                    navigationPath.removeLast()
                                }
                            },
                            onCastTapped: {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    showConnectToTVSheet = true
                                }
                            },
                            onOpenURL: { urlString in
                                navigationPath.append(TR_AppRoute.browserCasting(url: urlString, isOpenFromYoutube: false))
                            }
                        )
                        .navigationBarBackButtonHidden(true)
                    case .browserCasting(let urlString, let isOpenFromYoutube):
                        TR_BrowserCastingView(
                            initialURL: urlString,
                            isOpenFromYoutube: isOpenFromYoutube,
                            onBack: {
                                if !navigationPath.isEmpty {
                                    navigationPath.removeLast()
                                }
                            },
                            onCastTapped: {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    showConnectToTVSheet = true
                                }
                            },
                            onOpenPlayer: { streamURL, title, thumbnailURL, duration in
                                let playerData = YouTubePlayerData(
                                    streamURL: streamURL,
                                    title: title,
                                    thumbnailURL: thumbnailURL,
                                    duration: duration
                                )
                                navigationPath.append(TR_AppRoute.youtubePlayer(playerData))
                            }
                        )
                        .navigationBarBackButtonHidden(true)
                    case .youtubePlayer(let data):
                        YouTubeCastPlayerView(
                            data: data,
                            onBack: {
                                if !navigationPath.isEmpty {
                                    navigationPath.removeLast()
                                }
                            },
                            onCastTapped: {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    showConnectToTVSheet = true
                                }
                            }
                        )
                        .navigationBarBackButtonHidden(true)
                    }
                }
            }
            
            // Dimmer & Frosted Blur Background
            if isAnyModalOpen {
                ZStack {
                    TR_Blur(style: .systemUltraThinMaterialDark)
                        .opacity(0.85)
                    Color.black.opacity(0.25)
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        showConnectToTVSheet = false
                        showKeypadSheet = false
                        showKeyboardSheet = false
                        showInputSourceSheet = false
                    }
                }
                .zIndex(100)
            }
            
            // Connect to TV Full Screen
            if showConnectToTVSheet {
                ConnectToTVSheetView(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        showConnectToTVSheet = false
                    }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .zIndex(101)
            }
            
            // Keypad Bottom Sheet
            if showKeypadSheet {
                VStack(spacing: 0) {
                    Spacer()
                    KeypadSheetView(
                        channelInput: $channelInput,
                        isTVConnected: isTVConnected,
                        onOpenConnectTV: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                channelInput = ""
                                showKeypadSheet = false
                                showConnectToTVSheet = true
                            }
                        },
                        onDismiss: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                channelInput = ""
                                showKeypadSheet = false
                            }
                        }
                    )
                }
                .ignoresSafeArea(edges: isIPad ? [] : .bottom)
                .transition(.move(edge: .bottom))
                .zIndex(102)
            }
            
            // Keyboard Bottom Sheet
            if showKeyboardSheet {
                VStack(spacing: 0) {
                    Spacer()
                    KeyboardSheetView(
                        typedText: $typedText,
                        isTVConnected: isTVConnected,
                        onKeyTyped: { char in
                            if isTVConnected {
                                remoteVM.typeTextOnTV(char)
                            }
                        },
                        onBackspace: {
                            if isTVConnected {
                                remoteVM.sendBackspace()
                            }
                        },
                        onSend: { text in
                            if isTVConnected {
                                if !text.isEmpty {
                                    remoteVM.typeTextOnTV(text)
                                }
                                remoteVM.sendEnter()
                                typedText = ""
                            }
                        },
                        onOpenConnectTV: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                showKeyboardSheet = false
                                showConnectToTVSheet = true
                            }
                        },
                        onDismiss: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                typedText = ""
                                showKeyboardSheet = false
                            }
                        }
                    )
                }
                .ignoresSafeArea(edges: isIPad ? [] : .bottom)
                .transition(.move(edge: .bottom))
                .zIndex(103)
            }
            
            // Input Source Bottom Sheet
            if showInputSourceSheet {
                VStack(spacing: 0) {
                    Spacer()
                    InputSourceSheetView(
                        selectedSource: $selectedInputSource,
                        onDismiss: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                showInputSourceSheet = false
                            }
                        }
                    )
                }
                .ignoresSafeArea(edges: isIPad ? [] : .bottom)
                .transition(.move(edge: .bottom))
                .zIndex(104)
            }
            
            // Channels Bottom Sheet
            if showChannelsSheet {
                VStack(spacing: 0) {
                    Spacer()
                    TR_ChannelsSheetView(
                        isTVConnected: isTVConnected,
                        onOpenConnectTV: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                showChannelsSheet = false
                                showConnectToTVSheet = true
                            }
                        },
                        onClose: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                showChannelsSheet = false
                            }
                        }
                    )
                }
                .ignoresSafeArea(edges: isIPad ? [] : .bottom)
                .transition(.move(edge: .bottom))
                .zIndex(105)
            }
            
            // Toast Overlay
            if showToast {
                VStack {
                    Text(toastMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.85))
                        )
                        .padding(.top, 50)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(200)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: showConnectToTVSheet)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: showKeypadSheet)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: showKeyboardSheet)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: showInputSourceSheet)
        .onChange(of: remoteVM.showSearchingSheet) { shouldShow in
            if shouldShow {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    showConnectToTVSheet = true
                }
                remoteVM.showSearchingSheet = false
            }
        }
        .alert(
            languageManager.localized("airplay_disconnect_required"),
            isPresented: $showAirplayDisconnectAlert
        ) {
            Button(languageManager.localized("ok"), role: .cancel) { }
        } message: {
            Text(languageManager.localized("airplay_disconnect_required_desc"))
        }
        .onAppear {
            UserDefaults.standard.set(true, forKey: TR_SessionKeys.isHomeOpened)
            handlePostReviewLogic()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)

    }
    
    // MARK: - Post Review & App Rating Handlers
    func handlePostReviewLogic() {
        guard !TR_AppSession.shared.hasShownRate else { return }
        TR_AppSession.shared.hasShownRate = true
        
        let didAskForReview = UserDefaults.standard.bool(forKey: "didAskForReview")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if didAskForReview {
                // If user previously selected Yes -> directly show native App Store review prompt
                rateApp()
            } else {
                // If user hasn't selected Yes -> show "Do you like our app?" prompt
                showRateAlert = true
            }
        }
    }
    
    func rateApp() {
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
    
    private func showToast(message: String) {
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showToast = false
        }
    }
}
