//
//  YouTubeCastPlayerView.swift
//  TV Remote
//
//

import SwiftUI
import Combine
import AVFoundation
import AVKit
import ConnectSDK

struct YouTubePlayerData: Hashable {
    let id = UUID()
    let streamURL: URL
    let title: String
    let thumbnailURL: URL?
    let duration: Double
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: YouTubePlayerData, rhs: YouTubePlayerData) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - External TR_TV Video Display View (For AirPlay Screen / External Monitor)
struct ExternalTVVideoView: View {
    let player: AVPlayer
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AVPlayerViewRepresentable(player: player)
                .ignoresSafeArea()
        }
    }
}

struct YouTubeCastPlayerView: View {
    let data: YouTubePlayerData
    let onBack: () -> Void
    let onCastTapped: () -> Void
    
    @ObservedObject private var connectivityVM = TR_DeviceConnectivityViewModel.shared
    @ObservedObject private var deviceManager = DeviceConnectionManager.shared
    @ObservedObject private var tvVolumeManager = TVVolumeManager.shared
    @ObservedObject private var languageManager = TR_LanguageManager.shared
    
    @State private var player: AVPlayer?
    @State private var timeObserverToken: Any?
    @State private var playerItemEndObserver: NSObjectProtocol?
    @State private var isPlaying: Bool = true
    @State private var currentTime: Double = 0.0
    @State private var totalDuration: Double = 0.0
    @State private var isDraggingSeeker: Bool = false
    @State private var dragSeekProgress: Double = 0.0
    @State private var showConnectToTVSheet: Bool = false
    
    private static var sharedExternalWindow: UIWindow?
    
    static func dismissGlobalExternalDisplay() {
        sharedExternalWindow?.isHidden = true
        sharedExternalWindow?.rootViewController = nil
        sharedExternalWindow = nil
    }
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { UIDevice.isIPad || horizontalSizeClass == .regular }
    
    private var isAirPlay: Bool {
        TR_AirPlayManager.shared.isAirPlayConnected ||
        deviceManager.isAirPlayConnected ||
        connectivityVM.isAirPlayConnected() ||
        AVAudioSession.sharedInstance().currentRoute.outputs.contains { $0.portType == .airPlay }
    }
    
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let screenHeight = geo.size.height
            let cardWidth = isIPad ? (isLandscape ? 560.0 : 480.0) : min(geo.size.width - 32, 380.0)
            let availableHeight = screenHeight - (isIPad ? 300 : 220)
            let cardHeight = isIPad ? (isLandscape ? 400.0 : 380.0) : min(max(availableHeight, 300), min(geo.size.width - 32, 390.0))
            
            ZStack {
                VStack(spacing: 0) {
                    // 1. Top Navigation Bar (Figma Exact)
                    topNavigationBar(isIPad: isIPad)
                        .padding(.horizontal, isIPad ? 32 : 16)
                        .padding(.top, isIPad ? 16 : 8)
                        .padding(.bottom, 8)
                    
                    // 2. Center Video Playback Card (Increased Height, Zero Excess Gap)
                    thumbnailCard(width: cardWidth, height: cardHeight, isIPad: isIPad)
                        .padding(.horizontal, isIPad ? 32 : 16)
                    
                    // 3. Progress Bar & Duration Labels (Directly below Video Card)
                    progressSeekerBar(isIPad: isIPad)
                        .padding(.horizontal, isIPad ? (isLandscape ? 60 : 40) : 24)
                        .padding(.top, isIPad ? 16 : 10)
                    
                    // 4. Play/Pause & Volume Controls Row [- ⏯ +] (Directly below Seekbar)
                    playPauseControlRow(isIPad: isIPad)
                        .padding(.top, isIPad ? 20 : 12)
                    
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .disabled(showConnectToTVSheet)
                
                // Connect to TR_TV Bottom Sheet
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            Image("BG")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        )
        .animation(.easeInOut(duration: 0.28), value: showConnectToTVSheet)
        .onChange(of: TR_RemoteViewModel.shared.showSearchingSheet) { shouldShow in
            if shouldShow {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    showConnectToTVSheet = true
                }
                TR_RemoteViewModel.shared.showSearchingSheet = false
            }
        }
        .navigationBarHidden(true)
        .enableNativeSwipeBack()
        .onAppear {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try? AVAudioSession.sharedInstance().setActive(true)
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
        .onChange(of: connectivityVM.playbackPosition) { newTime in
            if !isDraggingSeeker {
                let sec = Double(newTime)
                if abs(currentTime - sec) > 2.0 {
                    let targetTime = CMTime(seconds: sec, preferredTimescale: 600)
                    player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
                }
                currentTime = sec
            }
        }
        .onChange(of: connectivityVM.duration) { newDur in
            if newDur > 0 {
                totalDuration = Double(newDur)
            }
        }
        .onChange(of: connectivityVM.isPlaying) { playing in
            isPlaying = playing
            if playing {
                player?.play()
            } else {
                player?.pause()
            }
        }
        .onChange(of: tvVolumeManager.currentVolume) { newVol in
            if isAirPlay {
                player?.volume = Float(newVol)
            }
        }
        .onChange(of: isAirPlay) { airPlayActive in
            if airPlayActive {
                player?.isMuted = false
                player?.volume = Float(tvVolumeManager.currentVolume)
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
                try? AVAudioSession.sharedInstance().setActive(true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.didConnectNotification)) { _ in
            updateExternalDisplay()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.didDisconnectNotification)) { _ in
            dismissExternalDisplay()
        }
    }
    
    // MARK: - 1. Top Navigation Bar (Figma Exact)
    @ViewBuilder
    private func topNavigationBar(isIPad: Bool) -> some View {
        HStack(alignment: .center) {
            // Back Button
            GlassBackButton(isIPad: isIPad) {
                cleanupPlayer()
                onBack()
            }
            
            Spacer()
            
            // Title: "YouTube" / Video Title
            Text(languageManager.localized("youtube"))
                .font(.inter(.bold, size: isIPad ? 22 : 18, autoScaleForPad: false))
                .foregroundColor(Color(hex: "111827"))
            
            Spacer()
            
            // Cast Button with Liquid Glass Container
            Button(action: {
                HapticFeedback.generate(.light)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    showConnectToTVSheet = true
                }
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
    }
    
    // MARK: - 2. Center Video Playback Card
    @ViewBuilder
    private func thumbnailCard(width: CGFloat, height: CGFloat, isIPad: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: isIPad ? 26 : 22, style: .continuous)
                .fill(Color.black)
            
            // Thumbnail Image shown on device (video plays exclusively on the TR_TV)
            if let thumb = data.thumbnailURL {
                AsyncImage(url: thumb) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: height)
                            .clipped()
                    case .failure:
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: isIPad ? 64 : 50))
                            .foregroundColor(Color.white.opacity(0.4))
                    default:
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
            } else {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: isIPad ? 64 : 50))
                    .foregroundColor(Color.white.opacity(0.4))
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: isIPad ? 26 : 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 5)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticFeedback.generate(.light)
            togglePlayPause()
        }
    }
    
    // MARK: - 3. Progress Seeker Bar
    @ViewBuilder
    private func progressSeekerBar(isIPad: Bool) -> some View {
        let total = max(1.0, totalDuration)
        let current = max(0.0, min(total, currentTime))
        let progress = isDraggingSeeker ? dragSeekProgress : (current / total)
        let progressClamped = max(0.0, min(1.0, progress.isNaN ? 0.0 : progress))
        let currentSeconds = isDraggingSeeker ? (progressClamped * total) : current
        
        HStack(spacing: 12) {
            // Current Time
            Text(formatTime(currentSeconds))
                .font(.inter(.medium, size: isIPad ? 15 : 13, autoScaleForPad: false))
                .foregroundColor(Color(hex: "8E8E93"))
                .frame(minWidth: isIPad ? 56 : 44, alignment: .leading)
            
            // Slider Track with White Pill Thumb
            GeometryReader { barGeo in
                let smSliderTrackWidth = barGeo.size.width
                let thumbWidth: CGFloat = isIPad ? 28 : 22
                let thumbHeight: CGFloat = isIPad ? 14 : 11
                let thumbOffset = max(0, min(smSliderTrackWidth - thumbWidth, smSliderTrackWidth * CGFloat(progressClamped) - thumbWidth / 2))
                
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color(hex: "D1D5DB").opacity(0.85))
                        .frame(height: 4)
                    
                    // Filled track (App Official Theme Gradient)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(smSliderTrackWidth, smSliderTrackWidth * CGFloat(progressClamped))), height: 4)
                    
                    // White pill thumb
                    Capsule()
                        .fill(Color.white)
                        .frame(width: thumbWidth, height: thumbHeight)
                        .shadow(color: Color.black.opacity(0.20), radius: 3, x: 0, y: 1)
                        .offset(x: thumbOffset)
                }
                .frame(height: barGeo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDraggingSeeker {
                                HapticFeedback.selection()
                            }
                            isDraggingSeeker = true
                            connectivityVM.isSeeking = true
                            let progress = max(0.0, min(1.0, Double(value.location.x / smSliderTrackWidth)))
                            dragSeekProgress = progress
                        }
                        .onEnded { value in
                            HapticFeedback.generate(.light)
                            let progress = max(0.0, min(1.0, Double(value.location.x / smSliderTrackWidth)))
                            let targetSeconds = progress * totalDuration
                            isDraggingSeeker = false
                            seek(to: targetSeconds)
                        }
                )
            }
            .frame(height: 24)
            
            // Total Duration
            Text(formatTime(totalDuration))
                .font(.inter(.medium, size: isIPad ? 15 : 13, autoScaleForPad: false))
                .foregroundColor(Color(hex: "8E8E93"))
                .frame(minWidth: isIPad ? 56 : 44, alignment: .trailing)
        }
    }
    
    // MARK: - 4. Play/Pause & Volume Controls Row [- ⏯ +]
    @ViewBuilder
    private func playPauseControlRow(isIPad: Bool) -> some View {
        let volBtnSize: CGFloat = isIPad ? 52 : 44
        let playBtnSize: CGFloat = isIPad ? 78 : 66
        
        HStack(spacing: isIPad ? 36 : 24) {
            // Volume Down (-) Supports Continuous Long Press
            ContinuousPressButton(action: {
                HapticFeedback.generate(.light)
                tvVolumeManager.sendVolumeDown()
            }) {
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
                .frame(width: volBtnSize, height: volBtnSize)
                .contentShape(Rectangle())
                .glassModifier(cornerRadius: volBtnSize / 2)
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
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
            
            // Large Play / Pause Button
            Button(action: togglePlayPause) {
                ZStack {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: isIPad ? 30 : 26, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .offset(x: isPlaying ? 0 : 2)
                }
                .frame(width: playBtnSize, height: playBtnSize)
                .contentShape(Rectangle())
                .glassModifier(cornerRadius: playBtnSize / 2)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.90), Color.white.opacity(0.40)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.90))
            
            // Volume Up (+) Supports Continuous Long Press
            ContinuousPressButton(action: {
                HapticFeedback.generate(.light)
                tvVolumeManager.sendVolumeUp()
            }) {
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
                .frame(width: volBtnSize, height: volBtnSize)
                .contentShape(Rectangle())
                .glassModifier(cornerRadius: volBtnSize / 2)
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
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
        }
    }
    
    // MARK: - Actions & Helpers
    private func setupPlayer() {
        if data.duration > 0 {
            totalDuration = data.duration
        } else if connectivityVM.duration > 0 {
            totalDuration = Double(connectivityVM.duration)
        } else {
            totalDuration = 276.0
        }
        
        let headers: [String: String] = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        ]
        let asset = AVURLAsset(url: data.streamURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 2
        
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.automaticallyWaitsToMinimizeStalling = false
        
        // Enable external playback for AirPlay
        newPlayer.allowsExternalPlayback = true
        newPlayer.usesExternalPlaybackWhileExternalScreenIsActive = true
        newPlayer.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        
        if isAirPlay {
            newPlayer.isMuted = false
            newPlayer.volume = Float(tvVolumeManager.currentVolume)
            
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try? AVAudioSession.sharedInstance().setActive(true)
        } else {
            // Mute local video player on phone so audio only plays from Smart TR_TV
            newPlayer.isMuted = true
            newPlayer.volume = 0.0
        }
        
        // Periodic time observer to sync progress bar
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak newPlayer] time in
            guard let newPlayer = newPlayer else { return }
            let sec = CMTimeGetSeconds(time)
            if !self.isDraggingSeeker && !sec.isNaN && sec >= 0 {
                self.currentTime = sec
            }
            if let dur = newPlayer.currentItem?.duration, !dur.seconds.isNaN, dur.seconds > 0 {
                self.totalDuration = dur.seconds
            }
        }
        
        // Loop video when ended
        playerItemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak newPlayer] _ in
            newPlayer?.seek(to: .zero)
            newPlayer?.play()
        }
        
        self.player = newPlayer
        newPlayer.play()
        self.isPlaying = true
        self.updateExternalDisplay()
    }
    
    private func updateExternalDisplay() {
        guard let player = player else {
            dismissExternalDisplay()
            return
        }
        guard UIScreen.screens.count > 1, let externalScreen = UIScreen.screens.last else {
            dismissExternalDisplay()
            return
        }
        
        if YouTubeCastPlayerView.sharedExternalWindow == nil || YouTubeCastPlayerView.sharedExternalWindow?.screen != externalScreen {
            let window = UIWindow(frame: externalScreen.bounds)
            window.screen = externalScreen
            YouTubeCastPlayerView.sharedExternalWindow = window
        }
        
        let hostingController = UIHostingController(rootView: ExternalTVVideoView(player: player))
        hostingController.view.frame = externalScreen.bounds
        hostingController.view.backgroundColor = .black
        YouTubeCastPlayerView.sharedExternalWindow?.rootViewController = hostingController
        YouTubeCastPlayerView.sharedExternalWindow?.isHidden = false
    }
    
    private func dismissExternalDisplay() {
        YouTubeCastPlayerView.dismissGlobalExternalDisplay()
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
    
    private func seek(to seconds: Double) {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return }
        let targetTime = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = seconds
        if !isAirPlay {
            connectivityVM.seek(to: Float(seconds))
        }
    }
    
    private func cleanupPlayer() {
        dismissExternalDisplay()
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let observer = playerItemEndObserver {
            NotificationCenter.default.removeObserver(observer)
            playerItemEndObserver = nil
        }
        player?.pause()
        player = nil
        
        let isMirroring = DeviceConnectionManager.shared.isMirroringActive 
            || UIScreen.main.isCaptured 
            || (UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") == true)
            || TR_MirroringServerManager.shared.isMirroringActive
        if !isMirroring {
            connectivityVM.stopMediaCasting()
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "00:00" }
        let totalSec = Int(seconds)
        let hours = totalSec / 3600
        let minutes = (totalSec % 3600) / 60
        let secs = totalSec % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}

// MARK: - Xcode Preview Provider
struct YouTubeCastPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        YouTubeCastPlayerView(
            data: YouTubePlayerData(
                streamURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!,
                title: "Dhun Song - Saiyaara",
                thumbnailURL: URL(string: "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg"),
                duration: 276.0
            ),
            onBack: {},
            onCastTapped: {}
        )
    }
}
