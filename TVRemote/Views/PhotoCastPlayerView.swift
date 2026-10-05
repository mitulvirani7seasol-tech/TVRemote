//
//  PhotoCastPlayerView.swift
//  TV Remote
//

import SwiftUI
import Photos
import Combine

enum PhotoQualityOption: String, CaseIterable, Identifiable {
    case optimized = "optimized"
    case balanced = "balanced"
    case best = "best"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .optimized: return "Optimized"
        case .balanced: return "Balanced"
        case .best: return "Best"
        }
    }
    
    @MainActor func localizedTitle(languageManager: TR_LanguageManager) -> String {
        switch self {
        case .optimized: return languageManager.localized("optimized")
        case .balanced: return languageManager.localized("balanced")
        case .best: return languageManager.localized("best")
        }
    }
}

enum PhotoTimeOption: Identifiable, Equatable {
    case s2
    case s4
    case s6
    case custom(Double)
    
    var id: String {
        switch self {
        case .s2: return "2s"
        case .s4: return "4s"
        case .s6: return "6s"
        case .custom: return "custom"
        }
    }
    
    var seconds: Double {
        switch self {
        case .s2: return 2.0
        case .s4: return 4.0
        case .s6: return 6.0
        case .custom(let val): return min(59.0, max(1.0, val))
        }
    }
    
    var title: String {
        switch self {
        case .s2: return "2s"
        case .s4: return "4s"
        case .s6: return "6s"
        case .custom: return "Custom"
        }
    }
    
    static func == (lhs: PhotoTimeOption, rhs: PhotoTimeOption) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - External TR_TV Photo Display View (For AirPlay Screen / External Monitor)
struct ExternalTVPhotoView: View {
    let image: UIImage?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let image = image {
                // Atmospheric blurred background
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 50)
                    .opacity(0.35)
                    .ignoresSafeArea()
                
                // Crisp centered full-res image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            }
        }
    }
}

struct PhotoCastPlayerView: View {
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
    @State private var currentImage: UIImage?
    @State private var isPlaying: Bool = false
    @State private var selectedQuality: PhotoQualityOption = .optimized
    @State private var selectedTime: PhotoTimeOption = .s4
    
    // Dropdown Popups State
    @State private var showTimerMenu: Bool = false
    @State private var showQualityMenu: Bool = false
    
    // Custom Time Modal State
    @State private var customSeconds: Int = 4
    @State private var totalCustomSeconds: Double = 4.0
    @State private var showCustomTimeSheet: Bool = false
    @State private var timerCancellable: AnyCancellable?
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { horizontalSizeClass == .regular }
    
    init(
        initialAsset: PHAsset? = nil,
        initialIndex: Int = 0,
        samplePreviewImage: UIImage? = nil,
        startWithCustomPopup: Bool = false,
        onBack: @escaping () -> Void,
        onCastTapped: @escaping () -> Void
    ) {
        self.initialAsset = initialAsset
        let resolvedIndex: Int
        if let initial = initialAsset,
           let idx = PhotoGalleryManager.shared.photoAssets.firstIndex(where: { $0.localIdentifier == initial.localIdentifier }) {
            resolvedIndex = idx
        } else {
            resolvedIndex = max(0, initialIndex)
        }
        self.initialIndex = resolvedIndex
        self.samplePreviewImage = samplePreviewImage
        self.onBack = onBack
        self.onCastTapped = onCastTapped
        _currentIndex = State(initialValue: resolvedIndex)
        _showCustomTimeSheet = State(initialValue: startWithCustomPopup)
        if let sample = samplePreviewImage {
            _currentImage = State(initialValue: sample)
        }
    }
    
    private var timerFormattedString: String {
        switch selectedTime {
        case .s2: return "00:00:02"
        case .s4: return "00:00:04"
        case .s6: return "00:00:06"
        case .custom(let val):
            let secs = Int(val)
            let hours = secs / 3600
            let minutes = (secs % 3600) / 60
            let s = secs % 60
            return String(format: "%02d:%02d:%02d", hours, minutes, s)
        }
    }
    
    private var isCustomSelected: Bool {
        if case .custom = selectedTime { return true }
        return false
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let screenHeight = geometry.size.height
            
            ZStack {
                // 0. Backdrop dismiss tap for dropdown menus (Behind Main Content)
                if showTimerMenu || showQualityMenu {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                showTimerMenu = false
                                showQualityMenu = false
                            }
                        }
                        .zIndex(5)
                }
                
                // Main Content View
                VStack(spacing: 0) {
                    // 1. Top Navigation Bar
                    navigationHeader(isIPad: isIPad)
                        .padding(.horizontal, isIPad ? 32 : 16)
                        .padding(.top, isIPad ? 24 : 12)
                        .padding(.bottom, isIPad ? 12 : 4)
                    
                    if isIPad {
                        // iPad layout
                        VStack(spacing: 16) {
                            photoContainerView(screenSize: geometry.size, isIPad: true, isLandscape: isLandscape)
                                .padding(.top, 8)
                            
                            playbackControlsView(isIPad: true)
                                .padding(.vertical, 4)
                            
                            settingCardsRow(isIPad: true)
                                .padding(.horizontal, isLandscape ? 60 : 32)
                                .zIndex(100)
                            
                            Spacer(minLength: 0)
                            
                            bottomThumbnailsStrip(isIPad: true)
                                .padding(.bottom, 20)
                                .zIndex(1)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Spacer(minLength: 0)
                    } else {
                        // iPhone: Adaptive Non-scrolling Layout with compact, tight Figma-exact spacing
                        VStack(spacing: screenHeight < 700 ? 10 : 14) {
                            // 2. Main Photo Container
                            photoContainerView(screenSize: geometry.size, isIPad: false, isLandscape: isLandscape)
                                .padding(.top, 4)
                            
                            // 3. Slideshow Playback Controls
                            playbackControlsView(isIPad: false)
                                .padding(.vertical, 2)
                            
                            // 4. Timer & Quality Setting Cards
                            settingCardsRow(isIPad: false)
                                .padding(.horizontal, 16)
                                .zIndex(100)
                            
                            Spacer(minLength: 4)
                            
                            // 5. Bottom Horizontal Thumbnails Strip
                            bottomThumbnailsStrip(isIPad: false)
                                .padding(.bottom, screenHeight < 700 ? 8 : 16)
                                .zIndex(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(10)
                .blur(radius: showCustomTimeSheet ? 4 : 0)
                .disabled(showCustomTimeSheet)
                
                // 5. "Set a Timer" Custom Time Bottom Modal Sheet
                if showCustomTimeSheet {
                    customTimeModalOverlay(isIPad: isIPad)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(200)
                }
                
                // 6. Connect to TV Full Screen
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
                    .zIndex(301)
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
                dismissExternalDisplay()
                stopSlideshow()
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
            if samplePreviewImage == nil {
                let targetIndex = setupInitialIndex()
                loadCurrentImage(index: targetIndex)
            } else {
                updateExternalDisplay()
            }
        }
        .onChange(of: currentImage) { _ in
            updateExternalDisplay()
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
                dismissExternalDisplay()
                stopSlideshow()
                onBack()
            }
        }
        .onDisappear {
            dismissExternalDisplay()
            stopSlideshow()
            let isMirroring = deviceManager.isMirroringActive 
                || UIScreen.main.isCaptured 
                || (UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") == true)
                || TR_MirroringServerManager.shared.isMirroringActive
            if !isMirroring {
                TR_DeviceConnectivityViewModel.shared.stopMediaCasting()
            }
        }
    }
    
    // MARK: - 1. Top Navigation Bar (Figma Exact)
    @ViewBuilder
    private func navigationHeader(isIPad: Bool) -> some View {
        HStack(alignment: .center) {
            // Back Button
            GlassBackButton(isIPad: isIPad) {
                stopSlideshow()
                onBack()
            }
            
            Spacer()
            
            // Title
            Text(languageManager.localized("photos"))
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
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
        }
    }
    
    // MARK: - 2. Photo Display Container
    @ViewBuilder
    private func photoContainerView(screenSize: CGSize, isIPad: Bool, isLandscape: Bool) -> some View {
        let cardWidth = isIPad ? (isLandscape ? 520 : 460) : min(screenSize.width - 32, 360)
        let availableHeight = screenSize.height - (isIPad ? 360 : 310)
        let cardHeight = isIPad ? (isLandscape ? 380 : 340) : min(max(availableHeight, 220), min(screenSize.width - 32, 330))
        
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.85))
            
            if let image = currentImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
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
        .gesture(
            DragGesture(minimumDistance: 25)
                .onEnded { value in
                    if value.translation.width < -30 {
                        HapticFeedback.generate(.light)
                        nextPhoto()
                    } else if value.translation.width > 30 {
                        HapticFeedback.generate(.light)
                        previousPhoto()
                    }
                }
        )
    }
    
    // MARK: - 3. Playback Controls (Prev, Play/Pause, Next)
    @ViewBuilder
    private func playbackControlsView(isIPad: Bool) -> some View {
        let btnSize: CGFloat = isIPad ? 52 : 44
        let playBtnSize: CGFloat = isIPad ? 72 : 62
        
        HStack(spacing: isIPad ? 36 : 28) {
            // Previous Button
            Button(action: previousPhoto) {
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
                .contentShape(Rectangle())
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
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
            
            // Play / Pause Button (Theme Gradient Filled)
            Button(action: togglePlayPause) {
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
                        .shadow(color: Color(hex: "8E03A1").opacity(0.35), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: isIPad ? 26 : 22, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: isPlaying ? 0 : 1.5)
                }
                .frame(width: playBtnSize, height: playBtnSize)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.90))
            
            // Next Button
            Button(action: nextPhoto) {
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
                .contentShape(Rectangle())
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
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
        }
    }
    
    // MARK: - 4. Side-by-Side Setting Cards (Timer & Quality with Dropdown Menus)
    @ViewBuilder
    private func settingCardsRow(isIPad: Bool) -> some View {
        HStack(spacing: isIPad ? 14 : 10) {
            // Timer Card with Dropdown Menu
            Button(action: {
                HapticFeedback.generate(.light)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    showTimerMenu.toggle()
                    showQualityMenu = false
                }
            }) {
                HStack(spacing: isIPad ? 10 : 8) {
                    Image("img_Time")
                        .resizable()
                        .scaledToFit()
                        .frame(width: isIPad ? 40 : 34, height: isIPad ? 40 : 34)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(languageManager.localized("timer"))
                            .font(.inter(.medium, size: isIPad ? 13 : 11, autoScaleForPad: false))
                            .foregroundColor(Color(hex: "6B7280"))
                            .lineLimit(1)
                        
                        Text(timerFormattedString)
                            .font(.inter(.bold, size: isIPad ? 15 : 13, autoScaleForPad: false))
                            .foregroundColor(Color(hex: "111827"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    
                    Spacer(minLength: 2)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: isIPad ? 13 : 11, weight: .semibold))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
                .padding(.horizontal, isIPad ? 14 : 10)
                .padding(.vertical, isIPad ? 12 : 9)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .glassCard(cornerRadius: isIPad ? 18 : 14)
                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.96))
            .overlay(alignment: .topLeading) {
                if showTimerMenu {
                    timerDropdownMenu(isIPad: isIPad)
                        .offset(y: isIPad ? 64 : 54)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
                }
            }
            .zIndex(showTimerMenu ? 150 : 1)
            
            // Quality Card with Dropdown Menu
            Button(action: {
                HapticFeedback.generate(.light)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    showQualityMenu.toggle()
                    showTimerMenu = false
                }
            }) {
                HStack(spacing: isIPad ? 10 : 8) {
                    Image("img_HD")
                        .resizable()
                        .scaledToFit()
                        .frame(width: isIPad ? 40 : 34, height: isIPad ? 40 : 34)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(languageManager.localized("quality"))
                            .font(.inter(.medium, size: isIPad ? 13 : 11, autoScaleForPad: false))
                            .foregroundColor(Color(hex: "6B7280"))
                            .lineLimit(1)
                        
                        Text(selectedQuality.localizedTitle(languageManager: languageManager))
                            .font(.inter(.bold, size: isIPad ? 15 : 13, autoScaleForPad: false))
                            .foregroundColor(Color(hex: "111827"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    
                    Spacer(minLength: 2)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: isIPad ? 13 : 11, weight: .semibold))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
                .padding(.horizontal, isIPad ? 14 : 10)
                .padding(.vertical, isIPad ? 12 : 9)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .glassCard(cornerRadius: isIPad ? 18 : 14)
                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.96))
            .overlay(alignment: .topLeading) {
                if showQualityMenu {
                    qualityDropdownMenu(isIPad: isIPad)
                        .offset(y: isIPad ? 64 : 54)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
                }
            }
            .zIndex(showQualityMenu ? 150 : 1)
        }
    }
    
    // MARK: - Timer Dropdown Menu
    @ViewBuilder
    private func timerDropdownMenu(isIPad: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            timerMenuItem(title: "2s", isSelected: selectedTime == .s2) {
                let changed = selectedTime != .s2
                selectedTime = .s2
                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) { showTimerMenu = false }
                if changed && isPlaying { restartSlideshow() }
            }
            
            Divider().opacity(0.15)
            
            timerMenuItem(title: "4s", isSelected: selectedTime == .s4) {
                let changed = selectedTime != .s4
                selectedTime = .s4
                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) { showTimerMenu = false }
                if changed && isPlaying { restartSlideshow() }
            }
            
            Divider().opacity(0.15)
            
            timerMenuItem(title: "6s", isSelected: selectedTime == .s6) {
                let changed = selectedTime != .s6
                selectedTime = .s6
                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) { showTimerMenu = false }
                if changed && isPlaying { restartSlideshow() }
            }
            
            Divider().opacity(0.15)
            
            timerMenuItem(title: languageManager.localized("custom"), isSelected: isCustomSelected) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) { showTimerMenu = false }
                let total = min(59, max(1, Int(totalCustomSeconds)))
                customSeconds = total
                withAnimation(.easeInOut(duration: 0.25)) {
                    showCustomTimeSheet = true
                }
            }
        }
        .frame(width: isIPad ? 175 : 142)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.80), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 8)
    }
    
    @ViewBuilder
    private func timerMenuItem(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticFeedback.generate(.light)
            action()
        }) {
            HStack {
                Text(title)
                    .font(.inter(isSelected ? .semiBold : .regular, size: 14, autoScaleForPad: false))
                    .foregroundColor(isSelected ? Color(hex: "8E03A1") : Color(hex: "111827"))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "E25F89"))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Quality Dropdown Menu
    @ViewBuilder
    private func qualityDropdownMenu(isIPad: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            qualityMenuItem(title: languageManager.localized("optimized"), isSelected: selectedQuality == .optimized) {
                let changed = selectedQuality != .optimized
                selectedQuality = .optimized
                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) { showQualityMenu = false }
                if changed {
                    loadCurrentImage(index: currentIndex)
                }
            }
            
            Divider().opacity(0.15)
            
            qualityMenuItem(title: languageManager.localized("balanced"), isSelected: selectedQuality == .balanced) {
                let changed = selectedQuality != .balanced
                selectedQuality = .balanced
                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) { showQualityMenu = false }
                if changed {
                    loadCurrentImage(index: currentIndex)
                }
            }
            
            Divider().opacity(0.15)
            
            qualityMenuItem(title: languageManager.localized("best"), isSelected: selectedQuality == .best) {
                let changed = selectedQuality != .best
                selectedQuality = .best
                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) { showQualityMenu = false }
                if changed {
                    loadCurrentImage(index: currentIndex)
                }
            }
        }
        .frame(width: isIPad ? 175 : 142)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.80), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 8)
    }
    
    @ViewBuilder
    private func qualityMenuItem(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticFeedback.generate(.light)
            action()
        }) {
            HStack {
                Text(title)
                    .font(.inter(isSelected ? .semiBold : .regular, size: 14, autoScaleForPad: false))
                    .foregroundColor(isSelected ? Color(hex: "8E03A1") : Color(hex: "111827"))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "E25F89"))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 5. Bottom Horizontal Photo Thumbnails Strip
    @ViewBuilder
    private func bottomThumbnailsStrip(isIPad: Bool) -> some View {
        let thumbSize: CGFloat = isIPad ? 130 : 100
        let assets = galleryManager.photoAssets
        
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
                                    Image(systemName: "photo.fill")
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
                                loadCurrentImage(index: idx)
                            }) {
                                PhotoThumbnailCell(
                                    asset: asset,
                                    isVideo: false,
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
    
    // MARK: - 6. Figma Exact "Set a Timer" Modal Popup (Image 4)
    @ViewBuilder
    private func customTimeModalOverlay(isIPad: Bool) -> some View {
        ZStack(alignment: .bottom) {
            // Semi-transparent backdrop
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showCustomTimeSheet = false
                    }
                }
            
            // Modal Card (Bottom Sheet Style)
            VStack(spacing: isIPad ? 22 : 16) {
                // Header (Title, Subtitle, and Close X button)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(languageManager.localized("set_a_timer"))
                            .font(.inter(.bold, size: isIPad ? 22 : 18, autoScaleForPad: false))
                            .foregroundColor(Color(hex: "111827"))
                        
                        Text(languageManager.localized("set_custom_time"))
                            .font(.inter(.regular, size: isIPad ? 14 : 12, autoScaleForPad: false))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        HapticFeedback.generate(.light)
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showCustomTimeSheet = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: isIPad ? 16 : 12, weight: .bold))
                            .foregroundColor(Color(hex: "6B7280"))
                            .frame(width: isIPad ? 38 : 30, height: isIPad ? 38 : 30)
                            .background(Color.black.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
                }
                
                // Seconds Label
                Text(languageManager.localized("seconds"))
                    .font(.inter(.medium, size: isIPad ? 15 : 13, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "6B7280"))
                    .padding(.top, 2)
                
                // Scrollable Seconds Wheel Picker (1 to 59 Seconds Max)
                Picker("", selection: $customSeconds) {
                    ForEach(1...59, id: \.self) { sec in
                        Text(String(format: "%02d", sec))
                            .font(.inter(.bold, size: isIPad ? 42 : 36, autoScaleForPad: false))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .tag(sec)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: isIPad ? 180 : 150, height: isIPad ? 140 : 110)
                .clipped()
                
                // Done Gradient Button
                Button(action: {
                    HapticFeedback.generate(.medium)
                    let total = min(59.0, max(1.0, Double(customSeconds)))
                    totalCustomSeconds = total
                    selectedTime = .custom(totalCustomSeconds)
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showCustomTimeSheet = false
                    }
                    if isPlaying {
                        restartSlideshow()
                    }
                }) {
                    Text(languageManager.localized("done"))
                        .font(.inter(.bold, size: isIPad ? 18 : 16, autoScaleForPad: false))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: isIPad ? 56 : 48)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(isIPad ? 16 : 14)
                        .shadow(color: Color(hex: "8E03A1").opacity(0.35), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.96))
                .padding(.top, 6)
            }
            .padding(isIPad ? 28 : 20)
            .background(
                RoundedRectangle(cornerRadius: isIPad ? 30 : 24, style: .continuous)
                    .fill(Color.white.opacity(0.85))
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: isIPad ? 30 : 24, style: .continuous)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: isIPad ? 30 : 24, style: .continuous)
                    .stroke(Color.white.opacity(0.60), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: isIPad ? 30 : 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 8)
            .padding(.horizontal, isIPad ? 60 : 16)
            .padding(.bottom, isIPad ? 32 : 16)
            .frame(maxWidth: isIPad ? 520 : .infinity)
        }
    }
    
    // MARK: - Photo Actions & Logic
    private func setupInitialIndex() -> Int {
        if let initial = initialAsset,
           let idx = galleryManager.photoAssets.firstIndex(where: { $0.localIdentifier == initial.localIdentifier }) {
            currentIndex = idx
            return idx
        } else if currentIndex >= galleryManager.photoAssets.count {
            currentIndex = 0
            return 0
        }
        return currentIndex
    }
    
    private func loadCurrentImage(index: Int) {
        guard samplePreviewImage == nil else { return }
        guard !galleryManager.photoAssets.isEmpty else { return }
        let safeIndex = min(max(0, index), galleryManager.photoAssets.count - 1)
        self.currentIndex = safeIndex
        let asset = galleryManager.photoAssets[safeIndex]
        
        let smFetchDimensions: CGSize
        let qualityIdx: Int
        switch selectedQuality {
        case .optimized:
            smFetchDimensions = CGSize(width: 1280, height: 1280)
            qualityIdx = 0
        case .balanced:
            smFetchDimensions = CGSize(width: 1920, height: 1920)
            qualityIdx = 1
        case .best:
            smFetchDimensions = CGSize(width: 3840, height: 2160)
            qualityIdx = 2
        }
        
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: smFetchDimensions,
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            guard let image = image else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                self.currentImage = image
            }
            
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if !isDegraded {
                self.updateExternalDisplay()
                let isMirroring = DeviceConnectionManager.shared.isMirroringActive || UIScreen.main.isCaptured || (UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") == true)
                if !isMirroring {
                    // Immediately stream/cast this high-res photo to the connected Smart TR_TV or AirPlay
                    TR_DeviceConnectivityViewModel.shared.castUIImage(image, quality: qualityIdx)
                }
            }
        }
    }
    
    private static var sharedExternalWindow: UIWindow?
    
    static func dismissGlobalExternalDisplay() {
        sharedExternalWindow?.isHidden = true
        sharedExternalWindow?.rootViewController = nil
        sharedExternalWindow = nil
    }
    
    private func updateExternalDisplay() {
        guard let image = currentImage ?? samplePreviewImage else {
            dismissExternalDisplay()
            return
        }
        guard UIScreen.screens.count > 1, let externalScreen = UIScreen.screens.last else {
            dismissExternalDisplay()
            return
        }
        
        if PhotoCastPlayerView.sharedExternalWindow == nil || PhotoCastPlayerView.sharedExternalWindow?.screen != externalScreen {
            let window = UIWindow(frame: externalScreen.bounds)
            window.screen = externalScreen
            PhotoCastPlayerView.sharedExternalWindow = window
        }
        
        let hostingController = UIHostingController(rootView: ExternalTVPhotoView(image: image))
        hostingController.view.frame = externalScreen.bounds
        hostingController.view.backgroundColor = .black
        PhotoCastPlayerView.sharedExternalWindow?.rootViewController = hostingController
        PhotoCastPlayerView.sharedExternalWindow?.isHidden = false
    }
    
    private func dismissExternalDisplay() {
        PhotoCastPlayerView.dismissGlobalExternalDisplay()
    }
    
    private func nextPhoto() {
        guard !galleryManager.photoAssets.isEmpty else { return }
        HapticFeedback.generate(.light)
        currentIndex = (currentIndex + 1) % galleryManager.photoAssets.count
        loadCurrentImage(index: currentIndex)
    }
    
    private func previousPhoto() {
        guard !galleryManager.photoAssets.isEmpty else { return }
        HapticFeedback.generate(.light)
        currentIndex = currentIndex > 0 ? (currentIndex - 1) : (galleryManager.photoAssets.count - 1)
        loadCurrentImage(index: currentIndex)
    }
    
    private func togglePlayPause() {
        HapticFeedback.generate(.medium)
        if isPlaying {
            stopSlideshow()
        } else {
            startSlideshow()
        }
    }
    
    private func startSlideshow() {
        isPlaying = true
        let interval = selectedTime.seconds
        
        timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                nextPhoto()
            }
    }
    
    private func stopSlideshow() {
        isPlaying = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }
    
    private func restartSlideshow() {
        stopSlideshow()
        startSlideshow()
    }
}

// MARK: - Xcode SwiftUI Canvas Previews
struct PhotoCastPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoCastPlayerView(
            initialAsset: nil,
            initialIndex: 0,
            samplePreviewImage: UIImage(named: "img_casting") ?? UIImage(systemName: "photo.fill"),
            onBack: {},
            onCastTapped: {}
        )
    }
}
