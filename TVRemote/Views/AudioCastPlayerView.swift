 //
//  AudioCastPlayerView.swift
//  TV Remote
//

import SwiftUI
import AVFoundation
import AVKit
import MediaPlayer
import Combine
import ConnectSDK

// MARK: - External TR_TV Music Display View (For AirPlay Screen / External Monitor)
struct ExternalTVMusicView: View {
    let track: MusicItem?
    let artwork: UIImage
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Blurred background artwork
            Image(uiImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 60)
                .opacity(0.45)
                .ignoresSafeArea()
            
            VStack(spacing: 36) {
                Spacer()
                
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 480, maxHeight: 480)
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.6), radius: 24, x: 0, y: 12)
                
                VStack(spacing: 12) {
                    Text(track?.title ?? "")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(track?.artist ?? "")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(48)
        }
    }
}

@MainActor
final class AudioPlaybackController: NSObject, ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0.0
    @Published var totalDuration: Double = 0.0
    @Published var isDraggingSeeker: Bool = false
    
    private var avPlayer: AVPlayer?
    private var timeObserverToken: Any?
    private var endObserverToken: NSObjectProtocol?
    private var playerItemStatusObserver: NSKeyValueObservation?
    private var musicPlayer = MPMusicPlayerController.applicationMusicPlayer
    private var timerCancellable: AnyCancellable?
    private var isStopped: Bool = false
    private var isSeeking: Bool = false
    private static var sharedExternalWindow: UIWindow?
    
    private var screenConnectObserver: NSObjectProtocol?
    private var screenDisconnectObserver: NSObjectProtocol?
    private var currentTrackItem: MusicItem?
    private var currentArtwork: UIImage?
    
    static func dismissGlobalExternalDisplay() {
        sharedExternalWindow?.isHidden = true
        sharedExternalWindow?.rootViewController = nil
        sharedExternalWindow = nil
    }
    
    var onTrackEnded: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?
    
    override init() {
        super.init()
        setupScreenObservers()
    }
    
    private func setupScreenObservers() {
        screenConnectObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, let track = self.currentTrackItem, let artwork = self.currentArtwork else { return }
            self.updateExternalDisplay(track: track, artwork: artwork)
        }
        
        screenDisconnectObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.dismissExternalDisplay()
        }
    }
    
    func configureAudioSession() {
        TR_AirPlayManager.shared.configureAudioSession()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setActive(true)
            print("✅ Audio session configured for AirPlay / Playback")
        } catch {
            print("❌ Audio session error: \(error)")
        }
    }
    
    func playTrack(
        _ track: MusicItem,
        volume: Float,
        isSmartTVConnected: Bool,
        artwork: UIImage
    ) {
        isStopped = false
        isSeeking = false
        currentTrackItem = track
        currentArtwork = artwork
        stopPlayerOnly()
        configureAudioSession()
        setupRemoteCommands()
        
        totalDuration = track.duration > 0 ? track.duration : 0
        currentTime = 0
        
        let isAirPlay = TR_AirPlayManager.shared.isAirPlayConnected || DeviceConnectionManager.shared.isAirPlayConnected || TR_DeviceConnectivityViewModel.shared.isAirPlayConnected()
        
        if let assetURL = track.assetURL, assetURL.isFileURL {
            if isAirPlay {
                TR_ImageToVideoConverter.createMusicVideoWithAudio(artwork: artwork, audioURL: assetURL, duration: track.duration) { [weak self] result in
                    guard let self = self, !self.isStopped else { return }
                    switch result {
                    case .success(let videoURL):
                        self.playDirectURL(videoURL, track: track, volume: volume, isSmartTVConnected: isSmartTVConnected, artwork: artwork)
                    case .failure:
                        self.playDirectURL(assetURL, track: track, volume: volume, isSmartTVConnected: isSmartTVConnected, artwork: artwork)
                    }
                }
            } else {
                playDirectURL(assetURL, track: track, volume: volume, isSmartTVConnected: isSmartTVConnected, artwork: artwork)
            }
        } else if let mediaItem = track.mediaItem {
            if let url = mediaItem.assetURL, url.isFileURL {
                if isAirPlay {
                    TR_ImageToVideoConverter.createMusicVideoWithAudio(artwork: artwork, audioURL: url, duration: track.duration) { [weak self] result in
                        guard let self = self, !self.isStopped else { return }
                        switch result {
                        case .success(let videoURL):
                            self.playDirectURL(videoURL, track: track, volume: volume, isSmartTVConnected: isSmartTVConnected, artwork: artwork)
                        case .failure:
                            self.playDirectURL(url, track: track, volume: volume, isSmartTVConnected: isSmartTVConnected, artwork: artwork)
                        }
                    }
                } else {
                    playDirectURL(url, track: track, volume: volume, isSmartTVConnected: isSmartTVConnected, artwork: artwork)
                }
            } else if let url = mediaItem.assetURL, url.scheme == "ipod-library" {
                exportAndPlayMediaItem(mediaItem: mediaItem, track: track, volume: volume, isSmartTVConnected: isSmartTVConnected, artwork: artwork, isAirPlay: isAirPlay)
            } else if let url = track.assetURL {
                playDirectURL(url, track: track, volume: volume, isSmartTVConnected: isSmartTVConnected, artwork: artwork)
            } else {
                playViaMusicPlayer(track: track, artwork: artwork)
            }
        } else if let url = track.assetURL {
            playDirectURL(url, track: track, volume: volume, isSmartTVConnected: isSmartTVConnected, artwork: artwork)
        }
    }
    
    private func exportAndPlayMediaItem(mediaItem: MPMediaItem, track: MusicItem, volume: Float, isSmartTVConnected: Bool, artwork: UIImage, isAirPlay: Bool) {
        guard let assetURL = mediaItem.assetURL else {
            self.playViaMusicPlayer(track: track, artwork: artwork)
            return
        }
        
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("exported_\(UUID().uuidString).m4a")
        
        let asset = AVAsset(url: assetURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            self.playViaMusicPlayer(track: track, artwork: artwork)
            return
        }
        
        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .m4a
        exportSession.exportAsynchronously { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, !self.isStopped else { return }
                if exportSession.status == .completed {
                    if isAirPlay {
                        TR_ImageToVideoConverter.createMusicVideoWithAudio(artwork: artwork, audioURL: destinationURL, duration: track.duration) { [weak self] result in
                            guard let self = self, !self.isStopped else { return }
                            switch result {
                            case .success(let videoURL):
                                self.playDirectURL(videoURL, track: track, volume: volume, isSmartTVConnected: isSmartTVConnected, artwork: artwork)
                            case .failure:
                                self.playDirectURL(destinationURL, track: track, volume: volume, isSmartTVConnected: isSmartTVConnected, artwork: artwork)
                            }
                        }
                    } else {
                        self.playDirectURL(destinationURL, track: track, volume: volume, isSmartTVConnected: isSmartTVConnected, artwork: artwork)
                    }
                } else {
                    self.playViaMusicPlayer(track: track, artwork: artwork)
                }
            }
        }
    }
    
    private func playDirectURL(
        _ url: URL,
        track: MusicItem,
        volume: Float,
        isSmartTVConnected: Bool,
        artwork: UIImage
    ) {
        if TR_CastingServerManager.shared.effectiveServerURL == nil {
            TR_CastingServerManager.shared.setupServer()
        }
        
        var streamURL = url
        if url.isFileURL {
            TR_CastingServerManager.shared.setLocalVideoToServe(url.path)
            if let baseURL = TR_CastingServerManager.shared.effectiveServerURL ?? TR_CastingServerManager.shared.serverURL {
                let cacheBuster = UUID().uuidString
                let ext = url.pathExtension.isEmpty ? "mp3" : url.pathExtension
                streamURL = baseURL.appendingPathComponent("localvideo/\(cacheBuster).\(ext)")
            }
        }
        
        let playerItem = AVPlayerItem(url: streamURL)
        setupPlayerItemMetadata(playerItem: playerItem, track: track, artwork: artwork)
        
        let player = AVPlayer(playerItem: playerItem)
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        player.automaticallyWaitsToMinimizeStalling = false
        
        if isSmartTVConnected {
            player.isMuted = true
            player.volume = 0.0
        } else {
            player.isMuted = false
            let effectiveVolume = volume > 0.01 ? volume : Float(TVVolumeManager.shared.currentVolume)
            player.volume = effectiveVolume > 0.01 ? effectiveVolume : 0.8
        }
        self.avPlayer = player
        
        playerItemStatusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self = self, !self.isStopped else { return }
                switch item.status {
                case .readyToPlay:
                    print("✅ AVPlayerItem ready to play: \(track.title)")
                    self.avPlayer?.play()
                    self.isPlaying = true
                case .failed:
                    print("⚠️ AVPlayerItem failed: \(item.error?.localizedDescription ?? "unknown"), falling back to MPMusicPlayer...")
                    self.playViaMusicPlayer(track: track, artwork: artwork)
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
        
        if track.duration > 0 {
            self.totalDuration = track.duration
        } else {
            let asset = AVURLAsset(url: url)
            Task { [weak self] in
                if let dur = try? await asset.load(.duration) {
                    let sec = CMTimeGetSeconds(dur)
                    if !sec.isNaN && !sec.isInfinite && sec > 0 {
                        await MainActor.run {
                            self?.totalDuration = sec
                        }
                    }
                }
            }
        }
        
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, !self.isDraggingSeeker, !self.isSeeking else { return }
            let sec = CMTimeGetSeconds(time)
            if !sec.isNaN && !sec.isInfinite && sec >= 0 {
                self.currentTime = sec
            }
            if let dur = self.avPlayer?.currentItem?.duration.seconds, !dur.isNaN && !dur.isInfinite && dur > 0 {
                self.totalDuration = dur
            }
        }
        
        endObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.onTrackEnded?()
        }
        
        player.play()
        self.isPlaying = true
        self.setupNowPlayingInfo(track: track, artwork: artwork)
        self.updateExternalDisplay(track: track, artwork: artwork)
        print("▶️ Playing via AVPlayer (AirPlay ready): \(track.title)")
        
        if isSmartTVConnected {
            TR_DeviceConnectivityViewModel.shared.compressAndUploadAudio(
                url,
                selectedQuality: 1,
                title: track.title,
                des: track.artist,
                itemImage: artwork
            )
        }
    }
    
    private func playViaMusicPlayer(track: MusicItem, artwork: UIImage) {
        guard let mediaItem = track.mediaItem else { return }
        musicPlayer.setQueue(with: MPMediaItemCollection(items: [mediaItem]))
        musicPlayer.prepareToPlay { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self, !self.isStopped else { return }
                if let error = error {
                    print("❌ prepareToPlay failed: \(error.localizedDescription)")
                }
                self.musicPlayer.play()
                self.isPlaying = true
                
                self.timerCancellable?.cancel()
                self.timerCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        guard let self = self, !self.isDraggingSeeker, !self.isSeeking else { return }
                        let current = self.musicPlayer.currentPlaybackTime
                        if !current.isNaN && !current.isInfinite && current >= 0 {
                            self.currentTime = current
                        }
                        if let now = self.musicPlayer.nowPlayingItem, now.playbackDuration > 0 {
                            self.totalDuration = now.playbackDuration
                        }
                    }
                
                self.setupNowPlayingInfo(track: track, artwork: artwork)
                self.updateExternalDisplay(track: track, artwork: artwork)
                print("▶️ Playing via MPMusicPlayer: \(track.title)")
            }
        }
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if !self.isPlaying {
                self.togglePlayPause()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.isPlaying {
                self.togglePlayPause()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.togglePlayPause()
            return .success
        }
        
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.onNextTrack?()
            return .success
        }
        
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.onPreviousTrack?()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: positionEvent.positionTime)
            return .success
        }
    }
    
    private func tearDownRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
    }
    
    func togglePlayPause() {
        if isPlaying {
            avPlayer?.pause()
            musicPlayer.pause()
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
            configureAudioSession()
            avPlayer?.play()
            musicPlayer.play()
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
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        if var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }
    
    func seek(to seconds: Double) {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return }
        isSeeking = true
        currentTime = seconds
        if let player = avPlayer {
            let smSeekCMTime = CMTime(seconds: seconds, preferredTimescale: 600)
            player.seek(to: smSeekCMTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                Task { @MainActor in
                    self?.isSeeking = false
                }
            }
        } else {
            musicPlayer.currentPlaybackTime = seconds
            isSeeking = false
        }
        if var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = seconds
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
        
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
    
    func setVolume(_ volume: Float, isSmartTVConnected: Bool = false) {
        if isSmartTVConnected {
            avPlayer?.volume = 0.0
            avPlayer?.isMuted = true
        } else {
            avPlayer?.volume = volume
            avPlayer?.isMuted = false
        }
    }
    
    func updateExternalDisplay(track: MusicItem, artwork: UIImage) {
        guard UIScreen.screens.count > 1, let externalScreen = UIScreen.screens.last else {
            dismissExternalDisplay()
            return
        }
        
        if AudioPlaybackController.sharedExternalWindow == nil || AudioPlaybackController.sharedExternalWindow?.screen != externalScreen {
            let window = UIWindow(frame: externalScreen.bounds)
            window.screen = externalScreen
            AudioPlaybackController.sharedExternalWindow = window
        }
        
        let hostingController = UIHostingController(rootView: ExternalTVMusicView(track: track, artwork: artwork))
        hostingController.view.frame = externalScreen.bounds
        hostingController.view.backgroundColor = .black
        AudioPlaybackController.sharedExternalWindow?.rootViewController = hostingController
        AudioPlaybackController.sharedExternalWindow?.isHidden = false
    }
    
    func dismissExternalDisplay() {
        AudioPlaybackController.dismissGlobalExternalDisplay()
    }
    
    private func stopPlayerOnly() {
        if let token = timeObserverToken, let player = avPlayer {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let observer = endObserverToken {
            NotificationCenter.default.removeObserver(observer)
            endObserverToken = nil
        }
        playerItemStatusObserver?.invalidate()
        playerItemStatusObserver = nil
        timerCancellable?.cancel()
        timerCancellable = nil
        
        avPlayer?.pause()
        avPlayer?.replaceCurrentItem(with: nil)
        avPlayer = nil
        
        musicPlayer.pause()
        isPlaying = false
        dismissExternalDisplay()
    }
    
    func stopPlayback(stopCasting: Bool = true) {
        guard !isStopped else { return }
        isStopped = true
        
        tearDownRemoteCommands()
        stopPlayerOnly()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        if stopCasting {
            let isMirroring = DeviceConnectionManager.shared.isMirroringActive 
                || UIScreen.main.isCaptured 
                || (UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") == true)
                || TR_MirroringServerManager.shared.isMirroringActive
            let isAirPlay = DeviceConnectionManager.shared.isAirPlayConnected || TR_DeviceConnectivityViewModel.shared.isAirPlayConnected()
            if !isMirroring && !isAirPlay {
                TR_DeviceConnectivityViewModel.shared.stopMediaCasting()
            }
        }
    }
    
    private func setupPlayerItemMetadata(playerItem: AVPlayerItem, track: MusicItem, artwork: UIImage) {
        var metadata: [AVMetadataItem] = []
        
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.key = AVMetadataKey.commonKeyTitle as (NSCopying & NSObjectProtocol)?
        titleItem.keySpace = .common
        titleItem.value = track.title as NSString
        titleItem.extendedLanguageTag = "und"
        metadata.append(titleItem)
        
        let artistItem = AVMutableMetadataItem()
        artistItem.identifier = .commonIdentifierArtist
        artistItem.key = AVMetadataKey.commonKeyArtist as (NSCopying & NSObjectProtocol)?
        artistItem.keySpace = .common
        artistItem.value = track.artist as NSString
        artistItem.extendedLanguageTag = "und"
        metadata.append(artistItem)
        
        if !track.album.isEmpty {
            let albumItem = AVMutableMetadataItem()
            albumItem.identifier = .commonIdentifierAlbumName
            albumItem.key = AVMetadataKey.commonKeyAlbumName as (NSCopying & NSObjectProtocol)?
            albumItem.keySpace = .common
            albumItem.value = track.album as NSString
            albumItem.extendedLanguageTag = "und"
            metadata.append(albumItem)
        }
        
        if let data = artwork.jpegData(compressionQuality: 0.95) ?? artwork.pngData() {
            // 1. Common Artwork (Apple TR_TV / AirPlay 2)
            let artworkItem = AVMutableMetadataItem()
            artworkItem.identifier = .commonIdentifierArtwork
            artworkItem.key = AVMetadataKey.commonKeyArtwork as (NSCopying & NSObjectProtocol)?
            artworkItem.keySpace = .common
            artworkItem.value = data as NSData
            artworkItem.dataType = kCMMetadataBaseDataType_JPEG as String
            artworkItem.extendedLanguageTag = "und"
            metadata.append(artworkItem)
            
            // 2. iTunes Artwork (Essential for M4A / AAC AirPlay streaming)
            let iTunesArtwork = AVMutableMetadataItem()
            iTunesArtwork.identifier = .iTunesMetadataCoverArt
            iTunesArtwork.key = AVMetadataKey.iTunesMetadataKeyCoverArt as (NSCopying & NSObjectProtocol)?
            iTunesArtwork.keySpace = .iTunes
            iTunesArtwork.value = data as NSData
            iTunesArtwork.dataType = kCMMetadataBaseDataType_JPEG as String
            metadata.append(iTunesArtwork)
            
            // 3. QuickTime Artwork
            let quickTimeArtwork = AVMutableMetadataItem()
            quickTimeArtwork.identifier = .quickTimeMetadataArtwork
            quickTimeArtwork.key = AVMetadataKey.quickTimeMetadataKeyArtwork as (NSCopying & NSObjectProtocol)?
            quickTimeArtwork.keySpace = .quickTimeMetadata
            quickTimeArtwork.value = data as NSData
            quickTimeArtwork.dataType = kCMMetadataBaseDataType_JPEG as String
            metadata.append(quickTimeArtwork)
            
            // 4. ID3 Artwork (Essential for MP3 AirPlay streaming)
            let id3Artwork = AVMutableMetadataItem()
            id3Artwork.identifier = .id3MetadataAttachedPicture
            id3Artwork.key = AVMetadataKey.id3MetadataKeyAttachedPicture as (NSCopying & NSObjectProtocol)?
            id3Artwork.keySpace = .id3
            id3Artwork.value = data as NSData
            id3Artwork.dataType = kCMMetadataBaseDataType_JPEG as String
            metadata.append(id3Artwork)
        }
        
        playerItem.externalMetadata = metadata
    }
    
    private func setupNowPlayingInfo(track: MusicItem, artwork: UIImage) {
        let artworkSize = (artwork.size.width > 0 && artwork.size.height > 0) ? artwork.size : CGSize(width: 512, height: 512)
        let mediaArtwork = MPMediaItemArtwork(boundsSize: artworkSize) { _ in artwork }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyPlaybackDuration: totalDuration > 0 ? totalDuration : track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPMediaItemPropertyArtwork: mediaArtwork
        ]
        if !track.album.isEmpty {
            info[MPMediaItemPropertyAlbumTitle] = track.album
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }
    
    deinit {
        if let token = timeObserverToken, let player = avPlayer {
            player.removeTimeObserver(token)
        }
        if let observer = endObserverToken {
            NotificationCenter.default.removeObserver(observer)
        }
        timerCancellable?.cancel()
        avPlayer?.pause()
        Task { @MainActor in
            AudioPlaybackController.dismissGlobalExternalDisplay()
        }
    }
}

struct AudioCastPlayerView: View {
    let initialTrack: MusicItem?
    let tracks: [MusicItem]
    let initialIndex: Int
    var samplePreviewArtwork: UIImage? = nil
    var sampleNoArtwork: Bool = false
    let onBack: () -> Void
    let onCastTapped: () -> Void
    
    @StateObject private var playbackController = AudioPlaybackController()
    @State private var showConnectToTVSheet: Bool = false
    @ObservedObject private var deviceManager = DeviceConnectionManager.shared
    @ObservedObject private var languageManager = TR_LanguageManager.shared
    
    @State private var currentIndex: Int = 0
    @State private var dragSeekProgress: Double = 0.0
    @ObservedObject private var tvVolumeManager = TVVolumeManager.shared
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { horizontalSizeClass == .regular }
    
    init(
        initialTrack: MusicItem? = nil,
        tracks: [MusicItem] = [],
        initialIndex: Int = 0,
        samplePreviewArtwork: UIImage? = nil,
        sampleNoArtwork: Bool = false,
        onBack: @escaping () -> Void,
        onCastTapped: @escaping () -> Void
    ) {
        self.initialTrack = initialTrack
        let allTracks = tracks.isEmpty && initialTrack != nil ? [initialTrack!] : tracks
        self.tracks = allTracks
        let resolvedIndex: Int
        if let initial = initialTrack,
           let idx = allTracks.firstIndex(where: { $0.id == initial.id }) {
            resolvedIndex = idx
        } else {
            resolvedIndex = max(0, initialIndex)
        }
        self.initialIndex = resolvedIndex
        self.samplePreviewArtwork = samplePreviewArtwork
        self.sampleNoArtwork = sampleNoArtwork
        self.onBack = onBack
        self.onCastTapped = onCastTapped
        _currentIndex = State(initialValue: resolvedIndex)
    }
    
    private var currentTrack: MusicItem? {
        if tracks.indices.contains(currentIndex) {
            return tracks[currentIndex]
        }
        return initialTrack
    }
    
    var body: some View {
         GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let screenHeight = geometry.size.height
            let availableForCard = screenHeight - 310
            let cardSize = min(max(availableForCard, 175), min(geometry.size.width - 32, 358))
            
            ZStack {
                VStack(spacing: 0) {
                    // 1. Navigation Header (Figma Exact)
                    navigationHeader(isIPad: isIPad)
                        .padding(.horizontal, isIPad ? 32 : 16)
                        .padding(.top, isIPad ? 24 : 12)
                        .padding(.bottom, isIPad ? 12 : 4)
                    
                     if isIPad {
                        // iPad: Exact original design with scroll disabled
                        VStack(spacing: 24) {
                            artworkContainerView(screenSize: geometry.size, isIPad: true, isLandscape: isLandscape)
                                .padding(.top, 16)
                            
                            trackInfoView(isIPad: true, isLandscape: isLandscape)
                                .padding(.horizontal, isLandscape ? 60 : 36)
                                .padding(.top, 4)
                            
                            playbackSeekerView(isIPad: true)
                                .padding(.horizontal, isLandscape ? 60 : 36)
                                .padding(.top, 4)
                            
                            playbackControlsView(isIPad: true)
                                .padding(.vertical, 12)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Spacer(minLength: 0)
                    } else {
                        // iPhone: Adaptive non-scrolling layout
                        VStack(spacing: screenHeight < 700 ? 10 : 16) {
                            Spacer(minLength: 2)
                            
                            // 2. Large Album Artwork / img_empty_music Box
                            artworkContainerView(screenSize: geometry.size, isIPad: false, isLandscape: isLandscape)
                                .padding(.top, screenHeight < 700 ? 2 : 8)
                            
                            Spacer(minLength: 2)
                            
                            // 3. Track Title & Artist Metadata
                            trackInfoView(isIPad: false, isLandscape: isLandscape)
                                .padding(.horizontal, 20)
                            
                            Spacer(minLength: 2)
                            
                            // 4. Playback Progress Seeker Bar
                            playbackSeekerView(isIPad: false)
                                .padding(.horizontal, 20)
                            
                            Spacer(minLength: 4)
                            
                            // 5. Playback & Volume Controls Row [- ⏪ ⏯ ⏩ +]
                            playbackControlsView(isIPad: false)
                                .padding(.bottom, screenHeight < 700 ? 12 : 24)
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
            // Clean up any previous photo / video AirPlay session so TR_TV switches cleanly to Audio
            TR_ImageCastAirPlayManager.shared.stopPlayback()
            TR_CastVideoPlayerManager.shared.stopPlayback()
            
            let isMirroring = deviceManager.isMirroringActive || UIScreen.main.isCaptured || (UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") == true)
            let isAirPlay = TR_AirPlayManager.shared.isAirPlayConnected || deviceManager.isAirPlayConnected || TR_DeviceConnectivityViewModel.shared.isAirPlayConnected()
            guard deviceManager.isDeviceConnected || isAirPlay || isMirroring || samplePreviewArtwork != nil || sampleNoArtwork else {
                playbackController.stopPlayback(stopCasting: true)
                onBack()
                return
            }
            TR_CastingServerManager.shared.setupServer()
            let tvType = TR_DeviceConnectivityViewModel.shared.getConnectedTvType()
            if !isMirroring && !isAirPlay && (tvType == .ANDROID || (tvType == .SAMSUNG && TR_DeviceConnectivityViewModel.shared.castViewModel.selectedDevice != nil)) {
                TR_DeviceConnectivityViewModel.shared.castViewModel.startCastSession()
            }
            playbackController.configureAudioSession()
            playbackController.setVolume(Float(tvVolumeManager.currentVolume), isSmartTVConnected: isSmartTVConnected)
            playbackController.onTrackEnded = {
                nextTrack()
            }
            playbackController.onNextTrack = {
                nextTrack()
            }
            playbackController.onPreviousTrack = {
                previousTrack()
            }
            if samplePreviewArtwork == nil && !sampleNoArtwork {
                let targetIndex = setupInitialTrack()
                loadAndPlayCurrentTrack(index: targetIndex)
            } else {
                playbackController.totalDuration = 240 // Mock 04:00
                playbackController.currentTime = 90    // Mock 01:30
                playbackController.isPlaying = true
            }
        }
        .onChange(of: tvVolumeManager.currentVolume) { newVol in
            playbackController.setVolume(Float(newVol), isSmartTVConnected: isSmartTVConnected)
        }
        .onChange(of: deviceManager.isDeviceConnected) { isConnected in
            let isMirroring = deviceManager.isMirroringActive || UIScreen.main.isCaptured || (UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") == true)
            let isAirPlay = TR_AirPlayManager.shared.isAirPlayConnected || deviceManager.isAirPlayConnected || TR_DeviceConnectivityViewModel.shared.isAirPlayConnected()
            if !isConnected && !isAirPlay && !isMirroring && samplePreviewArtwork == nil && !sampleNoArtwork {
                playbackController.stopPlayback(stopCasting: true)
                onBack()
            }
        }
        .onDisappear {
            playbackController.stopPlayback(stopCasting: true)
            AudioPlaybackController.dismissGlobalExternalDisplay()
            let isMirroring = DeviceConnectionManager.shared.isMirroringActive 
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
                playbackController.stopPlayback(stopCasting: true)
                onBack()
            }
            
            Spacer()
            
            // Title
            Text(languageManager.localized("audio"))
                .font(.inter(.bold, size: isIPad ? 22 : 18, autoScaleForPad: false))
                .foregroundColor(Color(hex: "111827"))
            
            Spacer()
            
            // Cast Button with Liquid Glass Container
            Button(action: {
                HapticFeedback.generate(.light)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { showConnectToTVSheet = true }
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
    
    // MARK: - 2. Album Artwork / Empty Placeholder Box
    @ViewBuilder
    private func artworkContainerView(screenSize: CGSize, isIPad: Bool, isLandscape: Bool) -> some View {
        let hasArtwork = (sampleNoArtwork ? false : (samplePreviewArtwork != nil || currentTrack?.artwork != nil))
        
        Group {
            if hasArtwork {
                // With Real / Preview Album Artwork
                ZStack {
                    RoundedRectangle(cornerRadius: isIPad ? 28 : 22, style: .continuous)
                        .fill(Color.white.opacity(0.88))
                    
                    if let sample = samplePreviewArtwork {
                        Image(uiImage: sample)
                            .resizable()
                            .scaledToFit()
                            .clipped()
                    } else if let track = currentTrack, let artwork = track.artwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .scaledToFit()
                            .clipped()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: isIPad ? 28 : 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
            } else {
                // Without Artwork: Frosted Glass Card with Centered App Gradient Music Icon
                emptyArtworkGlassCard(isIPad: isIPad)
            }
        }
    }
    
    // Empty Music Artwork Frosted Glass Card (App Theme Liquid Glass)
    @ViewBuilder
    private func emptyArtworkGlassCard(isIPad: Bool) -> some View {
        ZStack {
            // Soft white translucent background
            RoundedRectangle(cornerRadius: isIPad ? 28 : 22, style: .continuous)
                .fill(Color.white.opacity(0.35))
                .glassCard(cornerRadius: isIPad ? 28 : 22, isInteractive: false)
            
            // Centered App Gradient Music Icon
            Image(systemName: "music.note")
                .font(.system(size: isIPad ? 100 : 76, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(hex: "8E03A1").opacity(0.30), radius: 12, x: 0, y: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: isIPad ? 28 : 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - 3. Track Info (Title & Artist)
    @ViewBuilder
    private func trackInfoView(isIPad: Bool, isLandscape: Bool) -> some View {
        let title = currentTrack?.title ?? "Aonmyway"
        let artist = currentTrack?.artist ?? "Audio File"
        let artistText = artist.lowercased().hasPrefix("by ") ? artist : "By \(artist)"
        
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.inter(.bold, size: isIPad ? 22 : 17, autoScaleForPad: false))
                .foregroundColor(Color(hex: "111827"))
                .lineLimit(1)
            
            Text(artistText)
                .font(.inter(.regular, size: isIPad ? 15 : 13, autoScaleForPad: false))
                .foregroundColor(Color(hex: "8E8E93"))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 4. Playback Progress Seeker
    @ViewBuilder
    private func playbackSeekerView(isIPad: Bool) -> some View {
        let total = max(1.0, playbackController.totalDuration)
        let current = max(0.0, min(total, playbackController.currentTime))
        let progress = playbackController.isDraggingSeeker ? dragSeekProgress : (current / total)
        let progressClamped = max(0.0, min(1.0, progress.isNaN ? 0.0 : progress))
        let displaySeconds = playbackController.isDraggingSeeker ? (progressClamped * total) : current
        
        HStack(spacing: 12) {
            // Current Time
            Text(formatTime(displaySeconds))
                .font(.inter(.medium, size: isIPad ? 15 : 13, autoScaleForPad: false))
                .foregroundColor(Color(hex: "8E8E93"))
                .frame(width: isIPad ? 50 : 42, alignment: .leading)
            
            // Draggable Progress Track with White Thumb
            GeometryReader { barGeo in
                let smAudioProgressTrackWidth = barGeo.size.width
                
                ZStack(alignment: .leading) {
                    // Background Track
                    Capsule()
                        .fill(Color(hex: "E2E8F0").opacity(0.85))
                        .frame(height: isIPad ? 5 : 4)
                    
                    // Filled Track (App Theme Gradient)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: smAudioProgressTrackWidth * progressClamped, height: isIPad ? 5 : 4)
                    
                    // Circular Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: isIPad ? 16 : 13, height: isIPad ? 16 : 13)
                        .shadow(color: Color.black.opacity(0.20), radius: 3, x: 0, y: 1)
                        .offset(x: max(0, min(smAudioProgressTrackWidth - (isIPad ? 16 : 13), smAudioProgressTrackWidth * progressClamped - (isIPad ? 8 : 6.5))))
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !playbackController.isDraggingSeeker {
                                HapticFeedback.selection()
                            }
                            playbackController.isDraggingSeeker = true
                            dragSeekProgress = max(0, min(1, value.location.x / smAudioProgressTrackWidth))
                        }
                        .onEnded { value in
                            let finalProgress = max(0, min(1, value.location.x / smAudioProgressTrackWidth))
                            dragSeekProgress = finalProgress
                            playbackController.isDraggingSeeker = false
                            HapticFeedback.generate(.light)
                            playbackController.seek(to: finalProgress * playbackController.totalDuration)
                        }
                )
            }
            .frame(height: 24)
            
            // Total Duration
            Text(formatTime(playbackController.totalDuration))
                .font(.inter(.medium, size: isIPad ? 15 : 13, autoScaleForPad: false))
                .foregroundColor(Color(hex: "8E8E93"))
                .frame(width: isIPad ? 50 : 42, alignment: .trailing)
        }
    }
    
    // MARK: - 5. Playback & Volume Controls Row [- ⏪ ⏯ ⏩ +]
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
            Button(action: previousTrack) {
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
            Button(action: {
                HapticFeedback.generate(.medium)
                playbackController.togglePlayPause()
            }) {
                ZStack {
                    Image(systemName: playbackController.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: isIPad ? 30 : 26, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .offset(x: playbackController.isPlaying ? 0 : 2)
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
            Button(action: nextTrack) {
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
    
    // MARK: - Audio Player Logic
    private var isSmartTVConnected: Bool {
        let isAirPlayOnly = (TR_AirPlayManager.shared.isAirPlayConnected || DeviceConnectionManager.shared.isAirPlayConnected) &&
                            (TR_DeviceConnectivityViewModel.shared.connectedTvType == .AIRPLAY || TR_DeviceConnectivityViewModel.shared.connectedTvType == nil) &&
                            (DeviceConnectionManager.shared.connectedDevice?.isAirPlay == true || DeviceConnectionManager.shared.connectedDevice == nil)
        if isAirPlayOnly {
            return false
        }
        let isConnected = (TR_DeviceConnectivityViewModel.shared.getConnectedTvType() != .NONETV &&
                           TR_DeviceConnectivityViewModel.shared.getConnectedTvType() != nil &&
                           TR_DeviceConnectivityViewModel.shared.getConnectedTvType() != .AIRPLAY) ||
                          (DeviceConnectionManager.shared.connectedDevice != nil && !DeviceConnectionManager.shared.connectedDevice!.isAirPlay) ||
                          (TR_RemoteViewModel.shared.connectedTVType != nil && TR_RemoteViewModel.shared.connectedTVType != .NONETV && TR_RemoteViewModel.shared.connectedTVType != .AIRPLAY && TR_RemoteViewModel.shared.isConnectedSuccessfully) ||
                          TR_DeviceConnectivityViewModel.shared.isDeviceConnected
        return isConnected
    }
    
    private func setupInitialTrack() -> Int {
        if let initial = initialTrack,
           let idx = tracks.firstIndex(where: { $0.id == initial.id }) {
            currentIndex = idx
            return idx
        } else if currentIndex >= tracks.count {
            currentIndex = 0
            return 0
        }
        return currentIndex
    }
    
    private func loadAndPlayCurrentTrack(index: Int? = nil) {
        if let idx = index {
            self.currentIndex = min(max(0, idx), max(0, tracks.count - 1))
        }
        guard let track = currentTrack else { return }
        
        let effectiveArtwork = getEffectiveArtwork(for: track)
        playbackController.playTrack(
            track,
            volume: Float(tvVolumeManager.currentVolume),
            isSmartTVConnected: self.isSmartTVConnected,
            artwork: effectiveArtwork
        )
    }
    
    private func getEffectiveArtwork(for track: MusicItem) -> UIImage {
        if let art = track.artwork {
            return art
        }
        if let mpArtwork = track.mediaItem?.artwork,
           let img = mpArtwork.image(at: CGSize(width: 600, height: 600)) {
            return img
        }
        if let url = track.assetURL ?? track.mediaItem?.assetURL {
            let asset = AVURLAsset(url: url)
            for meta in asset.commonMetadata {
                if meta.commonKey == .commonKeyArtwork, let data = meta.dataValue, let img = UIImage(data: data) {
                    return img
                }
            }
            for meta in asset.metadata {
                if let data = meta.dataValue, let img = UIImage(data: data) {
                    return img
                }
            }
        }
        if let placeholder = UIImage(named: "img_empty_music"), placeholder.size.width > 0 {
            return placeholder
        }
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cgContext = ctx.cgContext
            let colors = [UIColor.systemIndigo.cgColor, UIColor.systemPurple.cgColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
                cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            if let symbol = UIImage(systemName: "music.note")?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                let symbolRect = CGRect(x: 156, y: 156, width: 200, height: 200)
                symbol.draw(in: symbolRect)
            }
        }
    }
    
    private func nextTrack() {
        guard !tracks.isEmpty else { return }
        HapticFeedback.generate(.light)
        currentIndex = (currentIndex + 1) % tracks.count
        loadAndPlayCurrentTrack()
    }
    
    private func previousTrack() {
        guard !tracks.isEmpty else { return }
        HapticFeedback.generate(.light)
        currentIndex = currentIndex > 0 ? (currentIndex - 1) : (tracks.count - 1)
        loadAndPlayCurrentTrack()
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
}

// MARK: - Multi-State Xcode Canvas Previews
struct AudioCastPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleTrack = MusicItem(
            id: "preview_1",
            title: "Sample Audio Track",
            size: "4.8 MB",
            artist: "Sample Artist",
            album: "Sample Album",
            duration: 215,
            assetURL: nil,
            artwork: UIImage(named: "img_casting"),
            mediaItem: nil
        )
        AudioCastPlayerView(
            initialTrack: sampleTrack,
            tracks: [sampleTrack],
            initialIndex: 0,
            samplePreviewArtwork: UIImage(named: "img_casting"),
            onBack: {},
            onCastTapped: {}
        )
    }
}

