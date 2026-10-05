//
//  IPTVPlayerView.swift
//  TV Remote
//

import SwiftUI
import AVKit
import AVFoundation
import ConnectSDK

struct IPTVPlayerView: View {
    @ObservedObject var languageManager = TR_LanguageManager.shared
    @ObservedObject private var connectivityVM = TR_DeviceConnectivityViewModel.shared
    @ObservedObject private var tvVolumeManager = TVVolumeManager.shared
    
    let channels: [TR_Channel]
    @State private var currentIndex: Int
    var onBack: () -> Void
    var onCastTapped: (() -> Void)? = nil
    
    @State private var player: AVPlayer?
    @State private var isPlaying = true
    @State private var isLoading = true
    @State private var showCastingToast = false
    @State private var toastMessage = ""
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { UIDevice.isIPad || horizontalSizeClass == .regular }
    
    var currentChannel: TR_Channel {
        if channels.indices.contains(currentIndex) {
            return channels[currentIndex]
        }
        return TR_Channel(name: "Live TR_Channel", logo: nil, url: nil)
    }
    
    private var isAirPlayConnected: Bool {
        TR_AirPlayManager.shared.isAirPlayConnected ||
        DeviceConnectionManager.shared.isAirPlayConnected ||
        (TR_RemoteViewModel.shared.connectedTVType == .AIRPLAY && TR_RemoteViewModel.shared.isConnectedSuccessfully)
    }
    
    private var isSmartTVConnected: Bool {
        if isAirPlayConnected { return false }
        return (TR_RemoteViewModel.shared.connectedTVType != nil && TR_RemoteViewModel.shared.connectedTVType != .NONETV && TR_RemoteViewModel.shared.connectedTVType != .AIRPLAY && TR_RemoteViewModel.shared.isConnectedSuccessfully) ||
               (connectivityVM.connectedTvType != nil && connectivityVM.connectedTvType != .NONETV && connectivityVM.connectedTvType != .AIRPLAY && connectivityVM.isDeviceConnected) ||
               (DeviceConnectionManager.shared.connectedDevice != nil && !DeviceConnectionManager.shared.connectedDevice!.isAirPlay && (DeviceConnectionManager.shared.connectedDevice?.isConnected == true || DeviceConnectionManager.shared.connectedDevice?.connectableDevice?.connected == true)) ||
               (connectivityVM.castViewModel.selectedDevice != nil && connectivityVM.castViewModel.isConnected) ||
               connectivityVM.connectSDKDiscoveryModel.isConnectedToLG ||
               (connectivityVM.connectSDKDiscoveryModel.selectedLGDevice?.connected == true)
    }
    
    private var isTVConnected: Bool {
        return DeviceConnectionManager.shared.isActuallyConnected
    }
    
    init(channels: [TR_Channel], initialIndex: Int = 0, onBack: @escaping () -> Void, onCastTapped: (() -> Void)? = nil) {
        self.channels = channels
        self._currentIndex = State(initialValue: initialIndex)
        self.onBack = onBack
        self.onCastTapped = onCastTapped
    }
    
    init(channel: TR_Channel, onBack: @escaping () -> Void, onCastTapped: (() -> Void)? = nil) {
        self.channels = [channel]
        self._currentIndex = State(initialValue: 0)
        self.onBack = onBack
        self.onCastTapped = onCastTapped
    }
    
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let horizontalPadding: CGFloat = isIPad ? (isLandscape ? 40 : 32) : 16
            
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // 1. Top Custom Navigation Header
                    topNavigationBar(isIPad: isIPad, horizontalPadding: horizontalPadding)
                    
                    // 2. Video Player Surface
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: isIPad ? 28 : 22, style: .continuous)
                            .fill(Color.black)
                        
                        if let player {
                            VideoPlayer(player: player)
                                .clipShape(RoundedRectangle(cornerRadius: isIPad ? 28 : 22, style: .continuous))
                                .allowsHitTesting(false)
                        }
                        
                        if isLoading {
                            RoundedRectangle(cornerRadius: isIPad ? 28 : 22, style: .continuous)
                                .fill(Color.black.opacity(0.85))
                                .overlay {
                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .scaleEffect(isIPad ? 1.6 : 1.3)
                                            .tint(.white)
                                        Text(languageManager.localized("loading_stream"))
                                            .font(.inter(.medium, size: isIPad ? 15 : 13, autoScaleForPad: false))
                                            .foregroundColor(.white.opacity(0.80))
                                    }
                                }
                        }
                        
                        // Top-Left LIVE Badge
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                            Text(languageManager.localized("live"))
                                .font(.inter(.bold, size: isIPad ? 13 : 11, autoScaleForPad: false))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: "EF4444"))
                        .clipShape(Capsule())
                        .padding(.top, isIPad ? 18 : 14)
                        .padding(.leading, isIPad ? 18 : 14)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, isIPad ? 12 : 8)
                    .padding(.bottom, isIPad ? 20 : 16)
                    
                    // 3. Playback & Remote Volume Controls (Volume -, Prev, Play/Pause, Next, Volume +)
                    playbackControlsView(isIPad: isIPad)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 4. Toast Notification for TR_TV Casting
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
                    .padding(.bottom, isIPad ? 120 : 100)
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
        .navigationBarHidden(true)
        .enableNativeSwipeBack()
        .onAppear {
            preparePlayer()
            if let player = player {
                if isSmartTVConnected {
                    player.volume = 0.0
                    player.isMuted = true
                } else {
                    player.volume = Float(tvVolumeManager.currentVolume)
                    player.isMuted = tvVolumeManager.isMuted
                }
            }
            if isTVConnected {
                castIPTVStream()
            }
        }
        .onChange(of: tvVolumeManager.currentVolume) { newVol in
            if let player = player {
                if isSmartTVConnected {
                    player.volume = 0.0
                    player.isMuted = true
                } else {
                    if tvVolumeManager.isMuted {
                        player.volume = 0.0
                        player.isMuted = true
                    } else {
                        player.volume = Float(newVol)
                        player.isMuted = false
                    }
                }
            }
        }
        .onChange(of: tvVolumeManager.isMuted) { isMuted in
            if let player = player {
                if isSmartTVConnected {
                    player.volume = 0.0
                    player.isMuted = true
                } else {
                    player.isMuted = isMuted
                    player.volume = isMuted ? 0.0 : Float(tvVolumeManager.currentVolume)
                }
            }
        }
        .onChange(of: isTVConnected) { connected in
            if connected {
                if isSmartTVConnected {
                    player?.volume = 0.0
                    player?.isMuted = true
                }
                castIPTVStream()
            }
        }
        .onChange(of: connectivityVM.isDeviceConnected) { connected in
            if connected {
                if isSmartTVConnected {
                    player?.volume = 0.0
                    player?.isMuted = true
                }
                castIPTVStream()
            }
        }
        .onDisappear {
            cleanupPlayer()
            let isMirroring = DeviceConnectionManager.shared.isMirroringActive 
                || UIScreen.main.isCaptured 
                || (UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") == true)
                || TR_MirroringServerManager.shared.isMirroringActive
            if !isMirroring {
                connectivityVM.setTVPlaceHolder(connectedTvType: connectivityVM.connectedTvType ?? .ANDROID)
            }
        }
    }
    
    // MARK: - 1. Top Navigation Bar
    @ViewBuilder
    private func topNavigationBar(isIPad: Bool, horizontalPadding: CGFloat) -> some View {
        HStack(alignment: .center) {
            // Back Button
            GlassBackButton(isIPad: isIPad) {
                cleanupPlayer()
                onBack()
            }
            
            Spacer()
            
            // Channel Name Title
            Text(currentChannel.name ?? languageManager.localized("live_tv"))
                .font(.inter(.bold, size: isIPad ? 22 : 18, autoScaleForPad: false))
                .foregroundColor(Color(hex: "111827"))
                .lineLimit(1)
            
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
        .padding(.top, isIPad ? 18 : 8)
        .padding(.bottom, isIPad ? 10 : 6)
    }
    
    // MARK: - 2. Playback & Remote Volume Controls
    @ViewBuilder
    private func playbackControlsView(isIPad: Bool) -> some View {
        let btnSize: CGFloat = isIPad ? 54 : 44
        let playBtnSize: CGFloat = isIPad ? 76 : 64
        
        HStack(spacing: isIPad ? 24 : 16) {
            // Volume Minus (-) Remote Button
            ContinuousPressButton(action: handleVolumeDown) {
                ZStack {
                    Image(systemName: "minus")
                        .font(.system(size: isIPad ? 20 : 16, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: btnSize, height: btnSize)
                .glassModifier(cornerRadius: btnSize / 2)
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
            
            // Previous Channel Button
            Button(action: previousChannel) {
                ZStack {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: isIPad ? 20 : 16, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: btnSize, height: btnSize)
                .glassModifier(cornerRadius: btnSize / 2)
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
            
            // Play / Pause Button (App Official Gradient)
            Button(action: {
                HapticFeedback.generate(.medium)
                togglePlayPause()
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: playBtnSize, height: playBtnSize)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.80), Color.white.opacity(0.25)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color(hex: "E25F89").opacity(0.40), radius: 12, x: 0, y: 4)
                    
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: isIPad ? 30 : 25, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: isPlaying ? 0 : 1.5)
                }
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
            
            // Next Channel Button
            Button(action: nextChannel) {
                ZStack {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: isIPad ? 20 : 16, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: btnSize, height: btnSize)
                .glassModifier(cornerRadius: btnSize / 2)
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
            
            // Volume Plus (+) Remote Button
            ContinuousPressButton(action: handleVolumeUp) {
                ZStack {
                    Image(systemName: "plus")
                        .font(.system(size: isIPad ? 20 : 16, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: btnSize, height: btnSize)
                .glassModifier(cornerRadius: btnSize / 2)
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
        .padding(.bottom, isIPad ? 36 : 24)
    }
    
    // MARK: - Next / Previous TR_Channel Logic
    private func nextChannel() {
        guard !channels.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if currentIndex + 1 < channels.count {
            currentIndex += 1
        } else {
            currentIndex = 0
        }
        switchChannel()
    }
    
    private func previousChannel() {
        guard !channels.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if currentIndex - 1 >= 0 {
            currentIndex -= 1
        } else {
            currentIndex = max(0, channels.count - 1)
        }
        switchChannel()
    }
    
    private func switchChannel() {
        cleanupPlayer()
        preparePlayer()
    }
    
    // MARK: - Remote Volume Actions (Single-TR_Command Dispatch)
    private func handleVolumeUp() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        tvVolumeManager.sendVolumeUp()
        if let player = player {
            if isSmartTVConnected {
                player.volume = 0.0
                player.isMuted = true
            } else {
                player.volume = Float(tvVolumeManager.currentVolume)
                player.isMuted = false
            }
        }
    }
    
    private func handleVolumeDown() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        tvVolumeManager.sendVolumeDown()
        if let player = player {
            if isSmartTVConnected {
                player.volume = 0.0
                player.isMuted = true
            } else {
                player.volume = Float(tvVolumeManager.currentVolume)
                player.isMuted = false
            }
        }
    }
    
    // MARK: - AVPlayer Operations
    private func preparePlayer() {
        isLoading = true
        guard let urlString = currentChannel.url, let url = URL(string: urlString) else {
            isLoading = false
            return
        }
        
        // Configure audio session for playback with AirPlay support
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .defaultToSpeaker])
        try? AVAudioSession.sharedInstance().setActive(true)
        
        let newPlayer = AVPlayer(url: url)
        newPlayer.allowsExternalPlayback = true
        newPlayer.usesExternalPlaybackWhileExternalScreenIsActive = true
        if self.isSmartTVConnected {
            newPlayer.volume = 0.0
            newPlayer.isMuted = true
        } else {
            newPlayer.volume = Float(tvVolumeManager.currentVolume)
            newPlayer.isMuted = tvVolumeManager.isMuted
        }
        self.player = newPlayer
        newPlayer.play()
        self.isPlaying = true
        
        // Listen for player readiness
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.isLoading = false
            if self.isTVConnected {
                self.castIPTVStream()
            }
        }
    }
    
    private func togglePlayPause() {
        HapticFeedback.generate(.medium)
        if isPlaying {
            player?.pause()
            isPlaying = false
            
            // 1. Google Cast / ConnectSDK Pause
            connectivityVM.isPlaying = true
            connectivityVM.togglePauseResume()
            
            // 2. Direct ConnectSDK MediaControl Pause
            connectivityVM.connectSDKDiscoveryModel.selectedLGDevice?.mediaControl()?.pause(success: nil, failure: nil)
            DeviceConnectionManager.shared.connectedDevice?.connectableDevice?.mediaControl()?.pause(success: nil, failure: nil)
            
            // 3. Remote Control Protocol Key Command (Samsung, LG, Roku, FireTV, Android TV)
            TR_RemoteViewModel.shared.sendCommand(.PAUSE)
            
            // 4. Samsung UPnP Caster Pause
            let dev = DeviceConnectionManager.shared.connectedDevice
            var targetIP = TR_RemoteViewModel.shared.connectingDeviceAddress
            if targetIP == nil { targetIP = dev?.ipAddress }
            if targetIP == nil { targetIP = connectivityVM.connectSDKDiscoveryModel.selectedLGDevice?.address }
            if let ip = targetIP {
                SamsungUPnPCaster.shared.pause(tvIP: ip)
            }
        } else {
            player?.play()
            isPlaying = true
            
            // 1. Google Cast / ConnectSDK Play
            connectivityVM.isPlaying = false
            connectivityVM.togglePauseResume()
            
            // 2. Direct ConnectSDK MediaControl Play
            connectivityVM.connectSDKDiscoveryModel.selectedLGDevice?.mediaControl()?.play(success: nil, failure: nil)
            DeviceConnectionManager.shared.connectedDevice?.connectableDevice?.mediaControl()?.play(success: nil, failure: nil)
            
            // 3. Remote Control Protocol Key Command (Samsung, LG, Roku, FireTV, Android TV)
            TR_RemoteViewModel.shared.sendCommand(.PLAY)
            
            // 4. Samsung UPnP Caster Play
            let dev = DeviceConnectionManager.shared.connectedDevice
            var targetIP = TR_RemoteViewModel.shared.connectingDeviceAddress
            if targetIP == nil { targetIP = dev?.ipAddress }
            if targetIP == nil { targetIP = connectivityVM.connectSDKDiscoveryModel.selectedLGDevice?.address }
            if let ip = targetIP {
                SamsungUPnPCaster.shared.play(tvIP: ip)
            }
        }
    }
    
    private func cleanupPlayer() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        isPlaying = false
    }
    
    private func castIPTVStream() {
        guard let urlString = currentChannel.url, let url = URL(string: urlString) else { return }
        
        if isTVConnected {
            connectivityVM.IPTVCast(
                mediaUrl: url,
                title: currentChannel.name ?? languageManager.localized("live_tv"),
                des: "IPTV"
            )
            
            let connectedName = DeviceConnectionManager.shared.connectedDevice?.name
            let tvName = TR_RemoteViewModel.shared.deviceName ?? connectedName ?? "TR_TV"
            toastMessage = "Casting to \(tvName)"
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showCastingToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showCastingToast = false
                }
            }
        } else {
            onCastTapped?()
        }
    }
}

// MARK: - Xcode SwiftUI Canvas Previews
struct IPTVPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        IPTVPlayerView(
            channel: TR_Channel(name: "BBC News", logo: nil, url: "https://example.com/stream.m3u8"),
            onBack: {},
            onCastTapped: {}
        )
    }
}
