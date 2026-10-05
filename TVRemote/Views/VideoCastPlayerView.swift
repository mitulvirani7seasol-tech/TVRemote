//
//  VideoCastPlayerView.swift
//  TV Remote
//

import SwiftUI
import Photos
import AVKit
import Combine
import ConnectSDK

// Helper: Custom AVPlayer UIViewRepresentable for seamless Aspect Fill video rendering
struct AVPlayerViewRepresentable: UIViewRepresentable {
    let player: AVPlayer?
    
    func makeUIView(context: Context) -> TR_PlayerUIView {
        let view = TR_PlayerUIView()
        view.player = player
        return view
    }
    
    func updateUIView(_ uiView: TR_PlayerUIView, context: Context) {
        uiView.player = player
    }
}

class TR_PlayerUIView: UIView {
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resizeAspect
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct VideoCastPlayerView: View {
    let initialAsset: PHAsset?
    let initialIndex: Int
    var samplePreviewImage: UIImage? = nil
    let onBack: () -> Void
    let onCastTapped: () -> Void
    
    @ObservedObject private var galleryManager = PhotoGalleryManager.shared
    @ObservedObject private var deviceManager = DeviceConnectionManager.shared
    @State private var showConnectToTVSheet: Bool = false
    @ObservedObject private var languageManager = TR_LanguageManager.shared
    
    @State private var currentIndex: Int = 0
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0.0
    @State private var totalDuration: Double = 0.0
    @State private var isDraggingSeeker: Bool = false
    @State private var dragSeekProgress: Double = 0.0
    @ObservedObject private var tvVolumeManager = TVVolumeManager.shared
    @State private var timeObserverToken: Any?
    @State private var playerItemEndObserver: NSObjectProtocol?
    @State private var currentRequestId: PHImageRequestID?
    @State private var isVideoLoaded: Bool = false
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { horizontalSizeClass == .regular }
    
    private var isSmartTVConnected: Bool {
        let isAirPlay = TR_AirPlayManager.shared.isAirPlayConnected || TR_DeviceConnectivityViewModel.shared.isAirPlayConnected() || DeviceConnectionManager.shared.isAirPlayConnected
        let isConnected = (TR_DeviceConnectivityViewModel.shared.getConnectedTvType() != .NONETV &&
                           TR_DeviceConnectivityViewModel.shared.getConnectedTvType() != nil &&
                           TR_DeviceConnectivityViewModel.shared.getConnectedTvType() != .AIRPLAY) ||
                          (DeviceConnectionManager.shared.connectedDevice != nil && !DeviceConnectionManager.shared.connectedDevice!.isAirPlay) ||
                          (TR_RemoteViewModel.shared.connectedTVType != nil && TR_RemoteViewModel.shared.connectedTVType != .NONETV && TR_RemoteViewModel.shared.connectedTVType != .AIRPLAY && TR_RemoteViewModel.shared.isConnectedSuccessfully) ||
                          TR_DeviceConnectivityViewModel.shared.isDeviceConnected
        return isConnected && !isAirPlay
    }
    
    init(
        initialAsset: PHAsset? = nil,
        initialIndex: Int = 0,
        samplePreviewImage: UIImage? = nil,
        onBack: @escaping () -> Void,
        onCastTapped: @escaping () -> Void
    ) {
        self.initialAsset = initialAsset
        let resolvedIndex: Int
        if let initial = initialAsset,
           let idx = PhotoGalleryManager.shared.videoAssets.firstIndex(where: { $0.localIdentifier == initial.localIdentifier }) {
            resolvedIndex = idx
        } else {
            resolvedIndex = max(0, initialIndex)
        }
        self.initialIndex = resolvedIndex
        self.samplePreviewImage = samplePreviewImage
        self.onBack = onBack
        self.onCastTapped = onCastTapped
        _currentIndex = State(initialValue: resolvedIndex)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let screenHeight = geometry.size.height
            let availableForCard = screenHeight - 280
            let cardSize = min(max(availableForCard, 190), min(geometry.size.width - 32, 360))
            
            ZStack {
                VStack(spacing: 0) {
                    // 1. Navigation Header
                    navigationHeader(isIPad: isIPad)
                        .padding(.horizontal, isIPad ? 32 : 16)
                        .padding(.top, isIPad ? 24 : 12)
                        .padding(.bottom, isIPad ? 12 : 4)
                    
                    if isIPad {
                        // iPad layout
                        VStack(spacing: 20) {
                            videoContainerView(screenSize: geometry.size, isIPad: true, isLandscape: isLandscape)
                                .padding(.top, 10)
                            
                            playbackSeekerView(isIPad: true)
                                .padding(.horizontal, isLandscape ? 60 : 36)
                            
                            playbackControlsView(isIPad: true)
                                .padding(.vertical, 8)
                            
                            Spacer(minLength: 0)
                            
                            bottomThumbnailsStrip(isIPad: true)
                                .padding(.bottom, 24)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Spacer(minLength: 0)
                    } else {
                        // iPhone: Adaptive non-scrolling layout with video thumbnails strip
                        VStack(spacing: screenHeight < 700 ? 8 : 14) {
                            // 2. Large Video Player Container
                            videoContainerView(screenSize: geometry.size, isIPad: false, isLandscape: isLandscape)
                                .padding(.top, 4)
                            
                            // 3. Playback Seeker (Current Time - Slider - Duration)
                            playbackSeekerView(isIPad: false)
                                .padding(.horizontal, 20)
                            
                            // 4. Playback & Volume Controls Row [- ⏪ ⏯ ⏩ +]
                            playbackControlsView(isIPad: false)
                                .padding(.vertical, 4)
                            
                            Spacer(minLength: 2)
                            
                            // 5. Bottom Horizontal Video Thumbnails Strip
                            bottomThumbnailsStrip(isIPad: false)
                                .padding(.bottom, screenHeight < 700 ? 8 : 16)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .disabled(showConnectToTVSheet)
                
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
        .disableNativeSwipeBack()
        .onAppear {
            let isMirroring = deviceManager.isMirroringActive || UIScreen.main.isCaptured || (UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") == true)
            guard deviceManager.isDeviceConnected || isMirroring || samplePreviewImage != nil else {
                cleanupPlayer()
                onBack()
                return
            }
            if !isMirroring {
                TR_CastingServerManager.shared.setupServer()
                let tvType = TR_DeviceConnectivityViewModel.shared.getConnectedTvType()
                if tvType == .ANDROID || (tvType == .SAMSUNG && TR_DeviceConnectivityViewModel.shared.castViewModel.selectedDevice != nil) {
                    TR_DeviceConnectivityViewModel.shared.castViewModel.startCastSession()
                }
            }
            configureAudioSession()
            if self.isSmartTVConnected {
                player?.volume = 0.0
                player?.isMuted = true
            } else {
                player?.volume = Float(tvVolumeManager.currentVolume)
                player?.isMuted = false
            }
            if samplePreviewImage == nil {
                let targetIndex = setupInitialIndex()
                loadCurrentVideo(index: targetIndex)
            } else {
                totalDuration = 240 // Mock 04:00
                currentTime = 90    // Mock 01:30
                isPlaying = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.didConnectNotification)) { _ in
            updateExternalDisplay()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.didDisconnectNotification)) { _ in
            dismissExternalDisplay()
        }
        .onChange(of: deviceManager.isDeviceConnected) { isConnected in
            let isMirroring = deviceManager.isMirroringActive || UIScreen.main.isCaptured || (UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") == true)
            if !isConnected && !isMirroring && samplePreviewImage == nil {
                cleanupPlayer()
                onBack()
            }
        }
        .onChange(of: tvVolumeManager.currentVolume) { newVol in
            if isSmartTVConnected {
                player?.volume = 0.0
                player?.isMuted = true
            } else {
                if tvVolumeManager.isMuted {
                    player?.volume = 0.0
                } else {
                    player?.volume = Float(newVol)
                }
            }
        }
        .onChange(of: tvVolumeManager.isMuted) { isMuted in
            if isSmartTVConnected {
                player?.volume = 0.0
                player?.isMuted = true
            } else {
                if isMuted {
                    player?.volume = 0.0
                } else {
                    player?.volume = Float(tvVolumeManager.currentVolume)
                }
            }
        }
        .onDisappear {
            cleanupPlayer()
        }
    }
    
    // MARK: - 1. Top Navigation Bar (Figma Exact)
    @ViewBuilder
    private func navigationHeader(isIPad: Bool) -> some View {
        HStack(alignment: .center) {
            // Back Button
            GlassBackButton(isIPad: isIPad) {
                cleanupPlayer()
                onBack()
            }
            
            Spacer()
            
            // Title
            Text(languageManager.localized("videos"))
                .font(.inter(.bold, size: isIPad ? 24 : 18, autoScaleForPad: false))
                .foregroundColor(Color(hex: "111827"))
            
            Spacer()
            
            // Cast Button (ic_cast with Glass effect matching GlassBackButton)
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
    
    // MARK: - 2. Video Display Container
    @ViewBuilder
    private func videoContainerView(screenSize: CGSize, isIPad: Bool, isLandscape: Bool) -> some View {
        let cardWidth = isIPad ? (isLandscape ? 520 : 460) : min(screenSize.width - 32, 360)
        let availableHeight = screenSize.height - (isIPad ? 390 : 300)
        let cardHeight = isIPad ? (isLandscape ? 380 : 340) : min(max(availableHeight, 380), min(screenSize.width - 32, 460))
        
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.85))
            
            if let sample = samplePreviewImage {
                Image(uiImage: sample)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: cardWidth, maxHeight: cardHeight)
                    .clipped()
            } else if let player = player {
                AVPlayerViewRepresentable(player: player)
                    .frame(maxWidth: cardWidth, maxHeight: cardHeight)
                    .clipped()
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(Color(hex: "8E03A1"))
                        .scaleEffect(1.2)
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticFeedback.generate(.medium)
            togglePlayPause()
        }
    }
    
    // MARK: - 3. Playback Seeker (01:30 ---O--- 04:00)
    @ViewBuilder
    private func playbackSeekerView(isIPad: Bool) -> some View {
        let displayCurrent = isDraggingSeeker ? dragSeekProgress : (totalDuration > 0 ? currentTime / totalDuration : 0)
        let currentSeconds = isDraggingSeeker ? (dragSeekProgress * totalDuration) : currentTime
        
        HStack(spacing: 12) {
            // Current Time Label
            Text(formatTime(currentSeconds))
                .font(.inter(.medium, size: isIPad ? 15 : 13, autoScaleForPad: false))
                .foregroundColor(Color(hex: "8E8E93"))
                .frame(minWidth: isIPad ? 60 : 48, alignment: .leading)
            
            // Custom Draggable Progress Bar with Thumb
            GeometryReader { barGeo in
                let smProgressBarWidth = barGeo.size.width
                let progressClamped = max(0, min(1, displayCurrent))
                
                ZStack(alignment: .leading) {
                    // Track Background
                    Capsule()
                        .fill(Color(hex: "E2E8F0").opacity(0.85))
                        .frame(height: isIPad ? 5 : 4)
                    
                    // Filled Progress Track (App Official Gradient)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: smProgressBarWidth * progressClamped, height: isIPad ? 5 : 4)
                    
                    // Thumb Circle
                    Circle()
                        .fill(Color.white)
                        .frame(width: isIPad ? 16 : 13, height: isIPad ? 16 : 13)
                        .shadow(color: Color.black.opacity(0.20), radius: 3, x: 0, y: 1)
                        .offset(x: max(0, min(smProgressBarWidth - (isIPad ? 16 : 13), smProgressBarWidth * progressClamped - (isIPad ? 8 : 6.5))))
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDraggingSeeker {
                                HapticFeedback.selection()
                            }
                            isDraggingSeeker = true
                            dragSeekProgress = max(0, min(1, value.location.x / smProgressBarWidth))
                        }
                        .onEnded { value in
                            let finalProgress = max(0, min(1, value.location.x / smProgressBarWidth))
                            isDraggingSeeker = false
                            HapticFeedback.generate(.light)
                            seek(to: finalProgress * totalDuration)
                        }
                )
            }
            .frame(height: 24)
            
            // Total Duration Label
            Text(formatTime(totalDuration))
                .font(.inter(.medium, size: isIPad ? 15 : 13, autoScaleForPad: false))
                .foregroundColor(Color(hex: "8E8E93"))
                .frame(minWidth: isIPad ? 60 : 48, alignment: .trailing)
        }
    }
    
    // MARK: - 4. Playback & Volume Controls Row [- ⏪ ⏯ ⏩ +]
    @ViewBuilder
    private func playbackControlsView(isIPad: Bool) -> some View {
        let volBtnSize: CGFloat = isIPad ? 46 : 38
        let skipBtnSize: CGFloat = isIPad ? 52 : 44
        let playBtnSize: CGFloat = isIPad ? 72 : 62
        
        HStack(spacing: isIPad ? 22 : 14) {
            // Volume Down (-)
            ContinuousPressButton(action: {
                HapticFeedback.generate(.light)
                tvVolumeManager.sendVolumeDown()
            }) {
                ZStack {
                    Image(systemName: "minus")
                        .font(.system(size: isIPad ? 18 : 15, weight: .bold))
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
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
            
            // Previous Button
            Button(action: previousVideo) {
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
                .frame(width: skipBtnSize, height: skipBtnSize)
                .contentShape(Rectangle())
                .glassModifier(cornerRadius: skipBtnSize / 2)
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
            
            // Play / Pause Button
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
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.90))
            
            // Next Button
            Button(action: nextVideo) {
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
                .frame(width: skipBtnSize, height: skipBtnSize)
                .contentShape(Rectangle())
                .glassModifier(cornerRadius: skipBtnSize / 2)
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
            
            // Volume Up (+)
            ContinuousPressButton(action: {
                HapticFeedback.generate(.light)
                tvVolumeManager.sendVolumeUp()
            }) {
                ZStack {
                    Image(systemName: "plus")
                        .font(.system(size: isIPad ? 18 : 15, weight: .bold))
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
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
        }
    }
    
    // MARK: - 6. Bottom Horizontal Video Thumbnails Strip
    @ViewBuilder
    private func bottomThumbnailsStrip(isIPad: Bool) -> some View {
        let thumbSize: CGFloat = isIPad ? 130 : 100
        let assets = galleryManager.videoAssets
        
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    if assets.isEmpty {
                        // Mock preview thumbnails if gallery empty
                        ForEach(0..<6, id: \.self) { idx in
                            let isSelected = idx == currentIndex
                            ZStack {
                                if let sample = samplePreviewImage {
                                    Image(uiImage: sample)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(Color.gray.opacity(0.6))
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color.white.opacity(0.4))
                                }
                            }
                            .frame(width: thumbSize, height: thumbSize)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        isSelected ? LinearGradient(colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        lineWidth: isSelected ? 2.5 : 0
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                        }
                    } else {
                        ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { idx, asset in
                            let isSelected = idx == currentIndex
                            
                            Button(action: {
                                HapticFeedback.generate(.light)
                                currentIndex = idx
                                loadCurrentVideo(index: idx)
                            }) {
                                PhotoThumbnailCell(
                                    asset: asset,
                                    isVideo: true,
                                    cellHeight: thumbSize
                                )
                                .frame(width: thumbSize, height: thumbSize)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            isSelected ? LinearGradient(colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                                            lineWidth: isSelected ? 2.5 : 0
                                        )
                                )
                                .shadow(color: Color.black.opacity(isSelected ? 0.10 : 0.03), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94))
                            .id(idx)
                        }
                    }
                }
                .padding(.horizontal, isIPad ? 32 : 16)
                .padding(.vertical, 4)
            }
            .frame(height: thumbSize + 8)
            .onChange(of: currentIndex) { newIdx in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newIdx, anchor: .center)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo(currentIndex, anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Helpers & Player Management
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let hours = total / 3600
        let min = (total % 3600) / 60
        let sec = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, min, sec)
        } else {
            return String(format: "%02d:%02d", min, sec)
        }
    }
    
    private func setupInitialIndex() -> Int {
        if let initial = initialAsset,
           let idx = galleryManager.videoAssets.firstIndex(where: { $0.localIdentifier == initial.localIdentifier }) {
            currentIndex = idx
            return idx
        } else if currentIndex >= galleryManager.videoAssets.count {
            currentIndex = 0
            return 0
        }
        return currentIndex
    }
    
    private func loadCurrentVideo(index: Int) {
        guard !galleryManager.videoAssets.isEmpty else { return }
        let safeIndex = min(max(0, index), galleryManager.videoAssets.count - 1)
        self.currentIndex = safeIndex
        let asset = galleryManager.videoAssets[safeIndex]
        
        stopLocalPlayerOnly()
        isVideoLoaded = false
        totalDuration = asset.duration
        currentTime = 0.0
        
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        let reqId = PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
            let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
            if isCancelled { return }
            guard let avAsset = avAsset else { return }
            
            DispatchQueue.main.async {
                guard self.currentIndex == safeIndex else { return }
                
                let playerItem = AVPlayerItem(asset: avAsset)
                let newPlayer = AVPlayer(playerItem: playerItem)
                newPlayer.allowsExternalPlayback = true
                newPlayer.usesExternalPlaybackWhileExternalScreenIsActive = true
                newPlayer.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
                
                if self.isSmartTVConnected {
                    newPlayer.isMuted = true
                    newPlayer.volume = 0.0
                } else {
                    newPlayer.isMuted = false
                    newPlayer.volume = Float(self.tvVolumeManager.currentVolume)
                }
                
                self.player = newPlayer
                self.isVideoLoaded = true
                self.isPlaying = true
                newPlayer.play()
                self.addTimeObserver()
                self.updateExternalDisplay()
                
                // Stream directly to TR_TV instantly in background
                self.exportAndCastVideo(avAsset: avAsset)
            }
        }
        self.currentRequestId = reqId
    }
    
    private static var sharedExternalWindow: UIWindow?
    
    private func updateExternalDisplay() {
        guard let player = player else {
            dismissExternalDisplay()
            return
        }
        guard UIScreen.screens.count > 1, let externalScreen = UIScreen.screens.last else {
            dismissExternalDisplay()
            return
        }
        
        if VideoCastPlayerView.sharedExternalWindow == nil || VideoCastPlayerView.sharedExternalWindow?.screen != externalScreen {
            let window = UIWindow(frame: externalScreen.bounds)
            window.screen = externalScreen
            VideoCastPlayerView.sharedExternalWindow = window
        }
        
        let hostingController = UIHostingController(rootView: ExternalTVVideoView(player: player))
        hostingController.view.frame = externalScreen.bounds
        hostingController.view.backgroundColor = .black
        VideoCastPlayerView.sharedExternalWindow?.rootViewController = hostingController
        VideoCastPlayerView.sharedExternalWindow?.isHidden = false
    }
    
    private func dismissExternalDisplay() {
        VideoCastPlayerView.sharedExternalWindow?.isHidden = true
        VideoCastPlayerView.sharedExternalWindow?.rootViewController = nil
        VideoCastPlayerView.sharedExternalWindow = nil
    }
    
    private func exportAndCastVideo(avAsset: AVAsset) {
        let isAirPlay = TR_AirPlayManager.shared.isAirPlayConnected || TR_DeviceConnectivityViewModel.shared.isAirPlayConnected() || DeviceConnectionManager.shared.isAirPlayConnected
        let isMirroring = DeviceConnectionManager.shared.isMirroringActive || UIScreen.main.isCaptured || (UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") == true)
        if isAirPlay || isMirroring {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let urlAsset = avAsset as? AVURLAsset {
                // Direct instant local streaming (Zero re-encoding lag)
                TR_DeviceConnectivityViewModel.shared.castLocalVideoFile(urlAsset.url)
            } else {
                let exportPath = NSTemporaryDirectory().appending("temp_cast_video_\(UUID().uuidString).mp4")
                let exportURL = URL(fileURLWithPath: exportPath)
                try? FileManager.default.removeItem(at: exportURL)
                
                if let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetPassthrough) ?? AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPreset1920x1080) {
                    exportSession.outputURL = exportURL
                    exportSession.outputFileType = .mp4
                    exportSession.exportAsynchronously {
                        if exportSession.status == .completed {
                            TR_DeviceConnectivityViewModel.shared.castLocalVideoFile(exportURL)
                        }
                    }
                }
            }
        }
    }
    
    private func addTimeObserver() {
        guard let player = player else { return }
        
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let endObs = playerItemEndObserver {
            NotificationCenter.default.removeObserver(endObs)
            playerItemEndObserver = nil
        }
        
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            if !isDraggingSeeker {
                let current = CMTimeGetSeconds(time)
                if !current.isNaN && !current.isInfinite {
                    currentTime = current
                }
            }
            if let duration = player.currentItem?.duration {
                let dur = CMTimeGetSeconds(duration)
                if !dur.isNaN && !dur.isInfinite && dur > 0 {
                    totalDuration = dur
                }
            }
        }
        
        if let currentItem = player.currentItem {
            playerItemEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: currentItem,
                queue: .main
            ) { _ in
                self.nextVideo()
            }
        }
    }
    
    private func togglePlayPause() {
        guard let player = player else { return }
        HapticFeedback.generate(.medium)
        if isPlaying {
            player.pause()
            isPlaying = false
            
            // 1. Google Cast / ConnectSDK Pause
            TR_DeviceConnectivityViewModel.shared.isPlaying = true
            TR_DeviceConnectivityViewModel.shared.togglePauseResume()
            
            // 2. Direct ConnectSDK MediaControl Pause
            TR_DeviceConnectivityViewModel.shared.connectSDKDiscoveryModel.selectedLGDevice?.mediaControl()?.pause(success: nil, failure: nil)
            DeviceConnectionManager.shared.connectedDevice?.connectableDevice?.mediaControl()?.pause(success: nil, failure: nil)
            
            // 3. Remote Control Protocol Key Command (Samsung, LG, Roku, FireTV, Android TV)
            TR_RemoteViewModel.shared.sendCommand(.PAUSE)
            
            // 4. Samsung UPnP Caster Pause
            let dev = DeviceConnectionManager.shared.connectedDevice
            var targetIP = TR_RemoteViewModel.shared.connectingDeviceAddress
            if targetIP == nil { targetIP = dev?.ipAddress }
            if targetIP == nil { targetIP = TR_DeviceConnectivityViewModel.shared.connectSDKDiscoveryModel.selectedLGDevice?.address }
            if let ip = targetIP {
                SamsungUPnPCaster.shared.pause(tvIP: ip)
            }
        } else {
            player.play()
            isPlaying = true
            
            // 1. Google Cast / ConnectSDK Play
            TR_DeviceConnectivityViewModel.shared.isPlaying = false
            TR_DeviceConnectivityViewModel.shared.togglePauseResume()
            
            // 2. Direct ConnectSDK MediaControl Play
            TR_DeviceConnectivityViewModel.shared.connectSDKDiscoveryModel.selectedLGDevice?.mediaControl()?.play(success: nil, failure: nil)
            DeviceConnectionManager.shared.connectedDevice?.connectableDevice?.mediaControl()?.play(success: nil, failure: nil)
            
            // 3. Remote Control Protocol Key Command (Samsung, LG, Roku, FireTV, Android TV)
            TR_RemoteViewModel.shared.sendCommand(.PLAY)
            
            // 4. Samsung UPnP Caster Play
            let dev = DeviceConnectionManager.shared.connectedDevice
            var targetIP = TR_RemoteViewModel.shared.connectingDeviceAddress
            if targetIP == nil { targetIP = dev?.ipAddress }
            if targetIP == nil { targetIP = TR_DeviceConnectivityViewModel.shared.connectSDKDiscoveryModel.selectedLGDevice?.address }
            if let ip = targetIP {
                SamsungUPnPCaster.shared.play(tvIP: ip)
            }
        }
    }
    
    private func seek(to seconds: Double) {
        guard let player = player else { return }
        let targetTime = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = seconds
        
        // 1. Common ViewModel Seek (handles Cast + ConnectSDK + UPnP)
        TR_DeviceConnectivityViewModel.shared.seek(to: Float(seconds))
        
        // 2. Direct ConnectSDK MediaControl Seek
        let lgControl = TR_DeviceConnectivityViewModel.shared.connectSDKDiscoveryModel.selectedLGDevice?.mediaControl()
        lgControl?.seek(TimeInterval(seconds), success: { [weak lgControl] _ in
            lgControl?.play(success: nil, failure: nil)
        }, failure: nil)
        
        let connectedDev = DeviceConnectionManager.shared.connectedDevice
        let cDevMediaControl = connectedDev?.connectableDevice?.mediaControl()
        cDevMediaControl?.seek(TimeInterval(seconds), success: { [weak cDevMediaControl] _ in
            cDevMediaControl?.play(success: nil, failure: nil)
        }, failure: nil)
        
        // 3. Direct Samsung UPnP Caster Seek & Play
        var targetIP = TR_RemoteViewModel.shared.connectingDeviceAddress
        if targetIP == nil {
            targetIP = connectedDev?.ipAddress
        }
        if targetIP == nil {
            targetIP = TR_DeviceConnectivityViewModel.shared.connectSDKDiscoveryModel.selectedLGDevice?.address
        }
        if targetIP == nil {
            targetIP = connectedDev?.connectableDevice?.address
        }
        
        if let ip = targetIP {
            SamsungUPnPCaster.shared.seek(tvIP: ip, seconds: TimeInterval(seconds)) { success in
                SamsungUPnPCaster.shared.play(tvIP: ip)
            }
        }
    }
    
    private func nextVideo() {
        guard !galleryManager.videoAssets.isEmpty else { return }
        HapticFeedback.generate(.light)
        currentIndex = (currentIndex + 1) % galleryManager.videoAssets.count
        loadCurrentVideo(index: currentIndex)
    }
    
    private func previousVideo() {
        guard !galleryManager.videoAssets.isEmpty else { return }
        HapticFeedback.generate(.light)
        currentIndex = currentIndex > 0 ? (currentIndex - 1) : (galleryManager.videoAssets.count - 1)
        loadCurrentVideo(index: currentIndex)
    }
    
    private func stopLocalPlayerOnly() {
        if let reqId = currentRequestId {
            PHImageManager.default().cancelImageRequest(reqId)
            currentRequestId = nil
        }
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let endObs = playerItemEndObserver {
            NotificationCenter.default.removeObserver(endObs)
            playerItemEndObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
    }
    
    private func cleanupPlayer() {
        dismissExternalDisplay()
        stopLocalPlayerOnly()
        let isMirroring = DeviceConnectionManager.shared.isMirroringActive 
            || UIScreen.main.isCaptured 
            || (UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") == true)
            || TR_MirroringServerManager.shared.isMirroringActive
        if !isMirroring {
            TR_DeviceConnectivityViewModel.shared.stopMediaCasting()
        }
    }
}

// MARK: - Xcode SwiftUI Canvas Previews
struct VideoCastPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        VideoCastPlayerView(
            initialAsset: nil,
            initialIndex: 0,
            samplePreviewImage: UIImage(named: "img_casting") ?? UIImage(systemName: "video.fill"),
            onBack: {},
            onCastTapped: {}
        )
    }
}

