//
//  PhotosGalleryView.swift
//  TV Remote
//

import SwiftUI
import Photos
import PhotosUI

enum MediaGalleryTab: Hashable {
    case photos
    case videos
    case audio
}

struct PhotosGalleryView: View {
    @ObservedObject var languageManager = TR_LanguageManager.shared
    @ObservedObject var galleryManager = PhotoGalleryManager.shared
    @ObservedObject var audioVM = AudioCastingViewModel.shared
    @ObservedObject var deviceManager = DeviceConnectionManager.shared
    @ObservedObject private var remoteVM = TR_RemoteViewModel.shared
    @ObservedObject private var commonVM = TR_DeviceConnectivityViewModel.shared
    @ObservedObject private var airPlayManager = TR_AirPlayManager.shared
    @ObservedObject private var imageCastAirPlayManager = TR_ImageCastAirPlayManager.shared
    @ObservedObject private var videoCastAirPlayManager = TR_CastVideoPlayerManager.shared
    @ObservedObject private var audioCastAirPlayManager = CastAudioPlayerManager.shared
    @EnvironmentObject var adVm: TR_AdCountViewModel
    @AppStorage(TR_SessionKeys.isPro) var isPro = false
    
    var initialTab: MediaGalleryTab
    var onBack: () -> Void
    var onCastTapped: () -> Void
    var onSelectPhoto: ((PHAsset, Int) -> Void)? = nil
    var onSelectVideo: ((PHAsset, Int) -> Void)? = nil
    var onSelectAudio: ((MusicItem, [MusicItem], Int) -> Void)? = nil
    
    @State private var selectedTab: MediaGalleryTab
    @State private var selectedPhotoAsset: PHAsset?
    @State private var selectedVideoAsset: PHAsset?
    @State private var selectedAudioItem: MusicItem?
    @State private var selectedAudioIndex: Int = 0
    @State private var lastViewedPhotoID: String? = nil
    @State private var lastViewedVideoID: String? = nil
    @State private var lastViewedAudioID: String? = nil
    @State private var showDocumentPicker: Bool = false
    @State private var showConnectToTVSheet: Bool = false
    @State private var showPremium: Bool = false
    @State private var showManageActionSheet: Bool = false
    @Namespace private var galleryNamespace
    @State private var dragOffset: CGFloat = 0.0
    @State private var isDragging: Bool = false
    @State private var lastHapticIndex: Int? = nil
    
    private var isAirPlayOnlyActive: Bool {
        airPlayManager.isAirPlayConnected
            || deviceManager.isAirPlayConnected
            || (remoteVM.connectedTVType == .AIRPLAY && remoteVM.isConnectedSuccessfully)
    }
    
    private var isTVOrAirPlayConnected: Bool {
        deviceManager.isActuallyConnected
    }
    
    init(
        initialTab: MediaGalleryTab = .photos,
        onBack: @escaping () -> Void,
        onCastTapped: @escaping () -> Void,
        onSelectPhoto: ((PHAsset, Int) -> Void)? = nil,
        onSelectVideo: ((PHAsset, Int) -> Void)? = nil,
        onSelectAudio: ((MusicItem, [MusicItem], Int) -> Void)? = nil
    ) {
        self.initialTab = initialTab
        self._selectedTab = State(initialValue: initialTab)
        self.onBack = onBack
        self.onCastTapped = onCastTapped
        self.onSelectPhoto = onSelectPhoto
        self.onSelectVideo = onSelectVideo
        self.onSelectAudio = onSelectAudio
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let isIPad = UIDevice.isIPad
            
            ZStack(alignment: .bottom) {
                // Main Content Area
                VStack(spacing: 0) {
                    // 1. Top Navigation Bar
                    navigationHeader(isIPad: isIPad, isLandscape: isLandscape)
                    
                    // 2. Media Content (Photos / Videos / Audio)
                    mediaContent(isIPad: isIPad, isLandscape: isLandscape, geometry: geometry)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .disabled(showConnectToTVSheet)
                
                // 4. Connect to TV Full Screen Overlay
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
                
                // 5. AirPlay Preparing / Casting Loader Overlay (ScreenNova Parity)
                if imageCastAirPlayManager.isCasting || videoCastAirPlayManager.isCasting || audioCastAirPlayManager.isCasting {
                    ZStack {
                        Color.black.opacity(0.45)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            
                            Text(videoCastAirPlayManager.isCasting ? "Preparing Video..." : (audioCastAirPlayManager.isCasting ? "Preparing Music..." : "Preparing Image..."))
                                .font(.inter(.semiBold, size: 16, autoScaleForPad: false))
                                .foregroundColor(.white)
                        }
                        .padding(28)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.black.opacity(0.85))
                        )
                    }
                    .zIndex(200)
                    .transition(.opacity)
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
        .ignoresSafeArea(edges: .bottom)
        .enableNativeSwipeBack()
        .animation(.easeInOut(duration: 0.28), value: showConnectToTVSheet)
        .fullScreenCover(item: $selectedPhotoAsset) { asset in
            let photoIndex = galleryManager.photoAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) ?? 0
            PhotoCastPlayerView(
                initialAsset: asset,
                initialIndex: photoIndex,
                onBack: {
                    selectedPhotoAsset = nil
                },
                onCastTapped: {
                    selectedPhotoAsset = nil
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        showConnectToTVSheet = true
                    }
                }
            )
            .transparentModalBackground()
        }
        .fullScreenCover(item: $selectedVideoAsset) { asset in
            let videoIndex = galleryManager.videoAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) ?? 0
            VideoCastPlayerView(
                initialAsset: asset,
                initialIndex: videoIndex,
                onBack: {
                    selectedVideoAsset = nil
                },
                onCastTapped: {
                    selectedVideoAsset = nil
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        showConnectToTVSheet = true
                    }
                }
            )
            .transparentModalBackground()
        }
        .fullScreenCover(item: $selectedAudioItem) { item in
            let audioIndex = audioVM.songs.firstIndex(where: { $0.id == item.id }) ?? selectedAudioIndex
            AudioCastPlayerView(
                initialTrack: item,
                tracks: audioVM.songs,
                initialIndex: audioIndex,
                onBack: {
                    selectedAudioItem = nil
                },
                onCastTapped: {
                    selectedAudioItem = nil
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        showConnectToTVSheet = true
                    }
                }
            )
            .transparentModalBackground()
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { urls in
                audioVM.importAudioFiles(from: urls)
            }
        }
        .onAppear {
            if selectedTab == .audio {
                if audioVM.songs.isEmpty {
                    audioVM.requestMusicAccessAndFetch()
                }
            } else {
                if galleryManager.photoAssets.isEmpty && galleryManager.videoAssets.isEmpty {
                    galleryManager.checkAuthorizationAndFetch()
                }
            }
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == .audio {
                if audioVM.songs.isEmpty {
                    audioVM.requestMusicAccessAndFetch()
                }
            } else {
                if galleryManager.photoAssets.isEmpty && galleryManager.videoAssets.isEmpty {
                    galleryManager.checkAuthorizationAndFetch()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if selectedTab == .audio {
                if audioVM.songs.isEmpty {
                    audioVM.requestMusicAccessAndFetch()
                }
            } else {
                if galleryManager.photoAssets.isEmpty && galleryManager.videoAssets.isEmpty {
                    galleryManager.checkAuthorizationAndFetch()
                }
            }
        }
        .alert(
            selectedTab == .videos ? languageManager.localized("video_access_needed") : languageManager.localized("photo_access_needed"),
            isPresented: $galleryManager.showPermissionAlert
        ) {
            Button(languageManager.localized("settings")) {
                galleryManager.openSettings()
            }
            Button(languageManager.localized("cancel"), role: .cancel) { }
        } message: {
            Text(selectedTab == .videos ? languageManager.localized("allow_video_access") : languageManager.localized("allow_photo_access"))
        }
        .alert(
            languageManager.localized("already_exists"),
            isPresented: $audioVM.showAlreadyExistsAlert
        ) {
            Button(languageManager.localized("ok"), role: .cancel) { }
        } message: {
            Text(audioVM.alreadyExistsMessage.isEmpty ? languageManager.localized("audio_already_exists") : audioVM.alreadyExistsMessage)
        }
        .confirmationDialog("", isPresented: $showManageActionSheet, titleVisibility: .hidden) {
            Button(languageManager.localized("select_more_photos_or_videos")) {
                galleryManager.presentLimitedLibraryPicker()
            }
            Button(languageManager.localized("change_settings")) {
                galleryManager.openSettings()
            }
            Button(languageManager.localized("cancel"), role: .cancel) { }
        }
    }
    
    // MARK: - 1. Top Navigation Bar
    @ViewBuilder
    private func navigationHeader(isIPad: Bool, isLandscape: Bool) -> some View {
        let horizontalPadding: CGFloat = isIPad ? (isLandscape ? 44 : 32) : 16
        HStack(alignment: .center) {
            // Back Button
            GlassBackButton(isIPad: isIPad, action: onBack)
            
            Spacer()
            
            // Title
            Text(currentTitle)
                .font(.inter(.bold, size: isIPad ? 22 : 18, autoScaleForPad: false))
                .foregroundColor(Color(hex: "111827"))
            
            Spacer()
            
            HStack(spacing: isIPad ? 12 : 8) {
                // If in Audio tab: Add button to select .mp3 files from Files app
                if selectedTab == .audio && !audioVM.musicPermissionDenied {
                    Button(action: {
                        HapticFeedback.generate(.light)
                        showDocumentPicker = true
                    }) {
                        ZStack {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: isIPad ? 19 : 16, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
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
        .padding(.horizontal, horizontalPadding)
        .padding(.top, isIPad ? 16 : 8)
        .padding(.bottom, 10)
    }
    
    private var currentTitle: String {
        switch selectedTab {
        case .photos: return languageManager.localized("photos")
        case .videos: return languageManager.localized("videos")
        case .audio: return languageManager.localized("audio")
        }
    }
    
    // MARK: - 2. Media Content (Photos / Videos / Audio)
    @ViewBuilder
    private func mediaContent(isIPad: Bool, isLandscape: Bool, geometry: GeometryProxy) -> some View {
        Group {
            switch selectedTab {
            case .photos:
                photosGridView(isIPad: isIPad, isLandscape: isLandscape, geometry: geometry)
            case .videos:
                videosGridView(isIPad: isIPad, isLandscape: isLandscape, geometry: geometry)
            case .audio:
                audioListView(isIPad: isIPad, isLandscape: isLandscape)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id("\(isLandscape ? "landscape" : "portrait")_\(selectedTab)")
    }
    
    // 3-Column Photos Grid (Paginated 50 at a time with strict cell bounds)
    @ViewBuilder
    private func photosGridView(isIPad: Bool, isLandscape: Bool, geometry: GeometryProxy) -> some View {
        let columnsCount = isIPad ? (isLandscape ? 5 : 4) : 3
        let spacing: CGFloat = isIPad ? 12 : 8
        let horizontalMargin: CGFloat = isIPad ? (isLandscape ? 44 : 32) : 16
        let availableWidth = geometry.size.width - (horizontalMargin * 2) - (spacing * CGFloat(columnsCount - 1))
        let cellWidth = availableWidth / CGFloat(columnsCount)
        let cellHeight = cellWidth * 1.30 // Exact Figma aspect ratio
        
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: spacing),
            count: columnsCount
        )
        
        ZStack {
            if galleryManager.isPermissionDenied || galleryManager.authorizationStatus == .denied || galleryManager.authorizationStatus == .restricted {
                VStack(spacing: 0) {
                    limitedAccessBanner(isIPad: isIPad, isLandscape: isLandscape)
                    photoPermissionBanner(isIPad: isIPad, isVideo: false)
                }
            } else if galleryManager.isLoading {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .tint(Color(hex: "2B44EA"))
                        .scaleEffect(1.3)
                    Text(languageManager.localized("fetching_photos"))
                        .font(.inter(.medium, size: 15))
                        .foregroundColor(Color(hex: "8E8E93"))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 100)
            } else {
                ScrollView(showsIndicators: false) {
                    ScrollViewReader { scrollProxy in
                        VStack(spacing: 0) {
                            limitedAccessBanner(isIPad: isIPad, isLandscape: isLandscape)
                            
                            if galleryManager.photoAssets.count > 0 {
                                LazyVGrid(columns: columns, spacing: spacing) {
                                    ForEach(Array(galleryManager.photoAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                        PhotoThumbnailCell(asset: asset, isVideo: false, cellHeight: cellHeight)
                                            .id(asset.localIdentifier)
                                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            .onTapGesture {
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                if !isTVOrAirPlayConnected {
                                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                                        showConnectToTVSheet = true
                                                    }
                                                    return
                                                }
                                                if isAirPlayOnlyActive {
                                                    imageCastAirPlayManager.playPHAssetImage(asset)
                                                    return
                                                }
                                                lastViewedPhotoID = asset.localIdentifier
                                                let photoIndex = galleryManager.photoAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) ?? index
                                                if let onSelectPhoto = onSelectPhoto {
                                                    onSelectPhoto(asset, photoIndex)
                                                } else {
                                                    selectedPhotoAsset = asset
                                                }
                                            }
                                            .onAppear {
                                                galleryManager.loadMorePhotosIfNeeded(currentItemIndex: index)
                                            }
                                    }
                                }
                                .padding(.horizontal, horizontalMargin)
                                .padding(.top, 6)
                                .padding(.bottom, 110)
                            } else {
                                VStack(spacing: 14) {
                                    Spacer()
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: isIPad ? 56 : 46))
                                        .foregroundColor(Color(hex: "9CA3AF"))
                                    Text(languageManager.localized("no_photos_found"))
                                        .font(.inter(.semiBold, size: isIPad ? 18 : 15))
                                        .foregroundColor(Color(hex: "6B7280"))
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, minHeight: 360)
                                .padding(.bottom, 100)
                            }
                        }
                        .onAppear {
                            if let id = lastViewedPhotoID {
                                scrollProxy.scrollTo(id, anchor: .center)
                            }
                        }
                        .onChange(of: selectedPhotoAsset) { asset in
                            if asset == nil, let id = lastViewedPhotoID {
                                scrollProxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 3-Column Videos Grid (Paginated 50 at a time with strict cell bounds)
    @ViewBuilder
    private func videosGridView(isIPad: Bool, isLandscape: Bool, geometry: GeometryProxy) -> some View {
        let columnsCount = isIPad ? (isLandscape ? 5 : 4) : 3
        let spacing: CGFloat = isIPad ? 12 : 8
        let horizontalMargin: CGFloat = isIPad ? (isLandscape ? 44 : 32) : 16
        let availableWidth = geometry.size.width - (horizontalMargin * 2) - (spacing * CGFloat(columnsCount - 1))
        let cellWidth = availableWidth / CGFloat(columnsCount)
        let cellHeight = cellWidth * 1.30 // Exact Figma aspect ratio
        
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: spacing),
            count: columnsCount
        )
        
        ZStack {
            if galleryManager.isPermissionDenied || galleryManager.authorizationStatus == .denied || galleryManager.authorizationStatus == .restricted {
                VStack(spacing: 0) {
                    limitedAccessBanner(isIPad: isIPad, isLandscape: isLandscape)
                    photoPermissionBanner(isIPad: isIPad, isVideo: true)
                }
            } else if galleryManager.isLoading {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .tint(Color(hex: "2B44EA"))
                        .scaleEffect(1.3)
                    Text(languageManager.localized("fetching_videos"))
                        .font(.inter(.medium, size: 15))
                        .foregroundColor(Color(hex: "8E8E93"))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 100)
            } else {
                ScrollView(showsIndicators: false) {
                    ScrollViewReader { scrollProxy in
                        VStack(spacing: 0) {
                            limitedAccessBanner(isIPad: isIPad, isLandscape: isLandscape)
                            
                            if galleryManager.videoAssets.count > 0 {
                                LazyVGrid(columns: columns, spacing: spacing) {
                                    ForEach(Array(galleryManager.videoAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                        PhotoThumbnailCell(asset: asset, isVideo: true, cellHeight: cellHeight)
                                            .id(asset.localIdentifier)
                                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            .onTapGesture {
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                if !isTVOrAirPlayConnected {
                                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                                        showConnectToTVSheet = true
                                                    }
                                                    return
                                                }
                                                if isAirPlayOnlyActive {
                                                    videoCastAirPlayManager.playPHAssetVideo(asset)
                                                    return
                                                }
                                                lastViewedVideoID = asset.localIdentifier
                                                let videoIndex = galleryManager.videoAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) ?? index
                                                if let onSelectVideo = onSelectVideo {
                                                    onSelectVideo(asset, videoIndex)
                                                } else {
                                                    selectedVideoAsset = asset
                                                }
                                            }
                                            .onAppear {
                                                galleryManager.loadMoreVideosIfNeeded(currentItemIndex: index)
                                            }
                                    }
                                }
                                .padding(.horizontal, horizontalMargin)
                                .padding(.top, 6)
                                .padding(.bottom, 110)
                            } else {
                                VStack(spacing: 14) {
                                    Spacer()
                                    Image(systemName: "video.badge.plus")
                                        .font(.system(size: isIPad ? 56 : 46))
                                        .foregroundColor(Color(hex: "9CA3AF"))
                                    Text(languageManager.localized("no_videos_found"))
                                        .font(.inter(.semiBold, size: isIPad ? 18 : 15))
                                        .foregroundColor(Color(hex: "6B7280"))
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, minHeight: 360)
                                .padding(.bottom, 100)
                            }
                        }
                        .onAppear {
                            if let id = lastViewedVideoID {
                                scrollProxy.scrollTo(id, anchor: .center)
                            }
                        }
                        .onChange(of: selectedVideoAsset) { asset in
                            if asset == nil, let id = lastViewedVideoID {
                                scrollProxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Audio List View (Exact Reference Logic & Figma Glass Card UI)
    @ViewBuilder
    private func audioListView(isIPad: Bool, isLandscape: Bool) -> some View {
        let horizontalMargin: CGFloat = isIPad ? (isLandscape ? 44 : 32) : 16
        ZStack {
            if audioVM.musicPermissionDenied {
                // Permission Denied View
                permissionBanner(isIPad: isIPad)
            } else {
                    if audioVM.isLoadings {
                    // Loading View
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView()
                            .tint(Color(hex: "8E03A1"))
                            .scaleEffect(1.3)
                        Text(languageManager.localized("fetching_music"))
                            .font(.inter(.medium, size: 15))
                            .foregroundColor(Color(hex: "8E8E93"))
                        Spacer()
                    }
                    .padding(.bottom, 24)
                } else {
                    if audioVM.songs.isEmpty {
                        // Empty State View with Direct Action to Pick from Files App
                        VStack(spacing: isIPad ? 16 : 12) {
                            Spacer()
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: isIPad ? 56 : 46))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text(languageManager.localized("no_music_found"))
                                .font(.inter(.bold, size: isIPad ? 22 : 18, autoScaleForPad: false))
                                .foregroundColor(Color(hex: "111827"))
                            
                            Text(languageManager.localized("select_mp3_subtitle"))
                                .font(.inter(.regular, size: isIPad ? 16 : 14, autoScaleForPad: false))
                                .foregroundColor(Color(hex: "8E8E93"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, isIPad ? 80 : 32)
                            
                            Button(action: {
                                HapticFeedback.generate(.light)
                                showDocumentPicker = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "folder.fill")
                                    Text(languageManager.localized("select_from_files"))
                                }
                                .font(.inter(.bold, size: isIPad ? 17 : 15, autoScaleForPad: false))
                                .foregroundColor(.white)
                                .frame(maxWidth: isIPad ? 320 : 260)
                                .frame(height: isIPad ? 52 : 46)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(isIPad ? 16 : 12)
                                .shadow(color: Color(hex: "8E03A1").opacity(0.35), radius: 8, x: 0, y: 3)
                            }
                            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
                            .padding(.top, 8)
                            
                            Spacer()
                        }
                        .padding(.bottom, 24)
                    } else {
                        // Music Listing with GlassCard
                        ScrollView(showsIndicators: false) {
                            ScrollViewReader { scrollProxy in
                                VStack(spacing: 0) {
                                    VStack(spacing: isIPad ? 14 : 10) {
                                        ForEach(Array(audioVM.songs.enumerated()), id: \.element.id) { index, item in
                                             musicRowCard(item: item, isIPad: isIPad)
                                                .id(item.id)
                                                .onTapGesture {
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    if !isTVOrAirPlayConnected {
                                                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                                            showConnectToTVSheet = true
                                                        }
                                                        return
                                                    }
                                                    lastViewedAudioID = item.id
                                                    if let onSelectAudio = onSelectAudio {
                                                        onSelectAudio(item, audioVM.songs, index)
                                                    } else {
                                                        selectedAudioIndex = index
                                                        selectedAudioItem = item
                                                    }
                                                }
                                        }
                                    }
                                    .padding(.horizontal, horizontalMargin)
                                    .padding(.top, 6)
                                    .padding(.bottom, 24)
                                }
                                .onAppear {
                                    if let id = lastViewedAudioID {
                                        scrollProxy.scrollTo(id, anchor: .center)
                                    }
                                }
                                .onChange(of: selectedAudioItem) { item in
                                    if item == nil, let id = lastViewedAudioID {
                                        scrollProxy.scrollTo(id, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Permission Banner (Matching Reference Code)
    @ViewBuilder
    private func permissionBanner(isIPad: Bool) -> some View {
        VStack(spacing: isIPad ? 16 : 12) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .font(.system(size: isIPad ? 56 : 46))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(languageManager.localized("music_access_needed"))
                .font(.inter(.bold, size: isIPad ? 22 : 18, autoScaleForPad: false))
                .foregroundColor(Color(hex: "111827"))
            
            Text(languageManager.localized("allow_music_access"))
                .font(.inter(.regular, size: isIPad ? 16 : 14, autoScaleForPad: false))
                .foregroundColor(Color(hex: "8E8E93"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, isIPad ? 80 : 32)
            
            Button(action: {
                audioVM.openSettings()
            }) {
                Text(languageManager.localized("open_settings"))
                    .font(.inter(.bold, size: isIPad ? 17 : 15, autoScaleForPad: false))
                    .foregroundColor(.white)
                    .frame(maxWidth: isIPad ? 320 : 260)
                    .frame(height: isIPad ? 52 : 46)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(isIPad ? 16 : 12)
                    .shadow(color: Color(hex: "8E03A1").opacity(0.35), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 24)
    }
    
    // MARK: - Limited Access Top Banner (Screen Mirror Limited Photo Access)
    @ViewBuilder
    private func limitedAccessBanner(isIPad: Bool, isLandscape: Bool) -> some View {
        if galleryManager.isLimitedAccess {
            let horizontalMargin: CGFloat = isIPad ? (isLandscape ? 44 : 32) : 16
            
            HStack(alignment: .center, spacing: 12) {
                Text(languageManager.localized("limited_photos_banner_text"))
                    .font(.inter(.regular, size: isIPad ? 14 : 12, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "1F2937"))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer(minLength: 6)
                
                Button(action: {
                    showManageActionSheet = true
                }) {
                    Text(languageManager.localized("manage"))
                        .font(.inter(.semiBold, size: isIPad ? 16 : 14, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "007AFF"))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, isIPad ? 16 : 12)
            .padding(.vertical, isIPad ? 12 : 10)
            .background(
                RoundedRectangle(cornerRadius: isIPad ? 14 : 10, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: isIPad ? 14 : 10, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            .padding(.horizontal, horizontalMargin)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
    }
    
    // Photo / Video Permission Banner
    @ViewBuilder
    private func photoPermissionBanner(isIPad: Bool, isVideo: Bool) -> some View {
        VStack(spacing: isIPad ? 16 : 12) {
            Spacer()
            
            Image(systemName: isVideo ? "video.badge.plus" : "photo.on.rectangle.angled")
                .font(.system(size: isIPad ? 56 : 46))
                .foregroundColor(Color(hex: "2B44EA"))
            
            Text(isVideo ? languageManager.localized("video_access_needed") : languageManager.localized("photo_access_needed"))
                .font(.inter(.bold, size: isIPad ? 22 : 18, autoScaleForPad: false))
                .foregroundColor(Color(hex: "111827"))
            
            Text(isVideo ? languageManager.localized("allow_video_access") : languageManager.localized("allow_photo_access"))
                .font(.inter(.regular, size: isIPad ? 16 : 14, autoScaleForPad: false))
                .foregroundColor(Color(hex: "8E8E93"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, isIPad ? 80 : 32)
            
            Button(action: {
                galleryManager.openSettings()
            }) {
                Text(languageManager.localized("open_settings"))
                    .font(.inter(.bold, size: isIPad ? 17 : 15, autoScaleForPad: false))
                    .foregroundColor(.white)
                    .frame(maxWidth: isIPad ? 320 : 260)
                    .frame(height: isIPad ? 52 : 46)
                    .background(
                        LinearGradient(
                            stops: [
                                .init(color: Color(hex: "C5ADFD"), location: 0.0),
                                .init(color: Color(hex: "2B44EA"), location: 0.90)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(isIPad ? 16 : 12)
                    .shadow(color: Color(hex: "2B44EA").opacity(0.35), radius: 8, x: 0, y: 3)
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .padding(.bottom, 100)
    }
    
    // Music Row Card with Album Artwork and Glass Effect
    @ViewBuilder
    private func musicRowCard(item: MusicItem, isIPad: Bool) -> some View {
        let isCurrent = audioVM.currentlyPlaying?.id == item.id
        
        HStack(spacing: isIPad ? 16 : 12) {
            // Artwork Thumbnail
            if let artwork = item.artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: isIPad ? 52 : 44, height: isIPad ? 52 : 44)
                    .clipShape(RoundedRectangle(cornerRadius: isIPad ? 14 : 10, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: isIPad ? 50 : 42, height: isIPad ? 50 : 42)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: isIPad ? 19 : 15, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            
            // Title & Artist / Size
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.inter(.bold, size: isIPad ? 16 : 14, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "111827"))
                    .lineLimit(1)
                
                Text("\(item.artist) • \(item.size)")
                    .font(.inter(.regular, size: isIPad ? 13 : 11, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Duration
            Text(item.durationString)
                .font(.inter(.regular, size: isIPad ? 14 : 12, autoScaleForPad: false))
                .foregroundColor(Color(hex: "8E8E93"))
                .padding(.trailing, 2)
            
            // Circular Play / Pause Action Button with App Gradient
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: isIPad ? 40 : 34, height: isIPad ? 40 : 34)
                    .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1)
                
                Image(systemName: isCurrent && audioVM.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: isIPad ? 16 : 13, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .offset(x: (isCurrent && audioVM.isPlaying) ? 0 : 1.5)
            }
        }
        .padding(.horizontal, isIPad ? 18 : 14)
        .padding(.vertical, isIPad ? 13 : 10)
        .glassCard(cornerRadius: isIPad ? 18 : 14)
        .overlay(
            RoundedRectangle(cornerRadius: isIPad ? 18 : 14, style: .continuous)
                .stroke(
                    isCurrent ? LinearGradient(colors: [Color(hex: "8E03A1").opacity(0.8), Color(hex: "E25F89").opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - 3. Floating Bottom Media Selector Pill (Live Finger Tracking & Spring Snap)
    @ViewBuilder
    private func floatingMediaSelector(isIPad: Bool) -> some View {
        let slotWidth: CGFloat = isIPad ? 140 : 100
        let barHeight: CGFloat = isIPad ? 54 : 42
        let pillHeight: CGFloat = isIPad ? 44 : 34
        let pillWidth: CGFloat = slotWidth - (isIPad ? 8 : 4)
        let totalWidth = slotWidth * 3
        
        let selectedIndex: Int = selectedTab == .photos ? 0 : (selectedTab == .videos ? 1 : 2)
        let baseOffset = CGFloat(selectedIndex - 1) * slotWidth
        let currentOffset = isDragging ? (baseOffset + dragOffset) : baseOffset
        let minOffset = -slotWidth - 10
        let maxOffset = slotWidth + 10
        let clampedOffset = max(minOffset, min(maxOffset, currentOffset))
        
        ZStack {
            // 1. Sliding Active Gradient Capsule Pill (Real-Time Live Drag Tracking)
            Capsule()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "C5ADFD"), location: 0.0),
                            .init(color: Color(hex: "2B44EA"), location: 0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: pillWidth, height: pillHeight)
                .shadow(color: Color(hex: "2B44EA").opacity(0.40), radius: 8, x: 0, y: 2)
                .offset(x: clampedOffset)
                .scaleEffect(isDragging ? 1.05 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.72), value: selectedTab)
                .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.82), value: dragOffset)
                .animation(.spring(response: 0.25, dampingFraction: 0.70), value: isDragging)
            
            // 2. TR_Tab Items Row
            HStack(spacing: 0) {
                // Photos
                mediaTabButton(
                    tab: .photos,
                    title: languageManager.localized("photos"),
                    activeIcon: "ic_photo_selected_Memories",
                    inactiveIcon: "ic_photo_Memories",
                    isSelected: selectedTab == .photos,
                    slotWidth: slotWidth,
                    isIPad: isIPad
                )
                
                // Videos
                mediaTabButton(
                    tab: .videos,
                    title: languageManager.localized("videos"),
                    activeIcon: "ic_video_selected_Memories",
                    inactiveIcon: "ic_video_Memories",
                    isSelected: selectedTab == .videos,
                    slotWidth: slotWidth,
                    isIPad: isIPad
                )
                
                // Audio
                mediaTabButton(
                    tab: .audio,
                    title: languageManager.localized("audio"),
                    activeIcon: "ic_music_selected_Memories",
                    inactiveIcon: "ic_music__Memories",
                    isSelected: selectedTab == .audio,
                    slotWidth: slotWidth,
                    isIPad: isIPad
                )
            }
        }
        .frame(width: totalWidth, height: barHeight)
        .padding(isIPad ? 6 : 4)
        .glassTabBarModifier(cornerRadius: barHeight / 2)
        .shadow(color: Color.black.opacity(0.08), radius: isIPad ? 20 : 16, x: 0, y: 5)
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        lastHapticIndex = selectedIndex
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    dragOffset = value.translation.width
                    
                    let liveX = (CGFloat(selectedIndex - 1) * slotWidth) + dragOffset
                    let hoverIndex = max(0, min(2, Int(round((liveX / slotWidth) + 1.0))))
                    if hoverIndex != lastHapticIndex {
                        lastHapticIndex = hoverIndex
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
                .onEnded { value in
                    let finalX = (CGFloat(selectedIndex - 1) * slotWidth) + dragOffset + (value.predictedEndTranslation.width * 0.25)
                    let finalIndex = max(0, min(2, Int(round((finalX / slotWidth) + 1.0))))
                    let tabs: [MediaGalleryTab] = [.photos, .videos, .audio]
                    let targetTab = tabs[finalIndex]
                    
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                        selectedTab = targetTab
                        dragOffset = 0
                        isDragging = false
                    }
                    lastHapticIndex = nil
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
        )
        .padding(.bottom, isIPad ? 70 : 50)
    }
    
    @ViewBuilder
    private func mediaTabButton(
        tab: MediaGalleryTab,
        title: String,
        activeIcon: String,
        inactiveIcon: String,
        isSelected: Bool,
        slotWidth: CGFloat,
        isIPad: Bool
    ) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                selectedTab = tab
            }
        }) {
            HStack(spacing: isIPad ? 8 : 5) {
                Image(isSelected ? activeIcon : inactiveIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: isIPad ? 24 : 17, height: isIPad ? 24 : 17)
                
                Text(title)
                    .font(.inter(isSelected ? .bold : .medium, size: isIPad ? 16 : 12, autoScaleForPad: false))
                    .foregroundColor(isSelected ? .white : Color(hex: "8E8E93"))
            }
            .frame(width: slotWidth, height: isIPad ? 54 : 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// Extension to make PHAsset Identifiable for SwiftUI sheet
extension PHAsset: @retroactive Identifiable {
    public var id: String { localIdentifier }
}

// Fullscreen Photo/Video Viewer with Cast Integration
struct FullScreenMediaViewer: View {
    let asset: PHAsset
    let isVideo: Bool
    var onCast: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var fullImage: UIImage?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                        onCast()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "airplayvideo")
                            Text("Cast to TR_TV")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "2B44EA"))
                        .clipShape(Capsule())
                    }
                }
                .padding()
                
                Spacer()
                
                // Full Media Image / Video
                if let image = fullImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .tint(.white)
                }
                
                Spacer()
            }
        }
        .onAppear {
            loadFullMedia()
        }
    }
    
    private func loadFullMedia() {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    self.fullImage = image
                }
            }
        }
    }
}

// MARK: - SwiftUI Preview Provider
