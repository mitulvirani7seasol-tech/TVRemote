//
//  CommonCastConnectSDKViewModel.swift
//  ClarioMirror
//
//  Created by Vivek Rakholiya on 06/05/26.
//

import Foundation
import Combine
import AVFoundation
import MediaPlayer
import GoogleCast
import ConnectSDK

class TR_DeviceConnectivityViewModel: ObservableObject {
    static let shared = TR_DeviceConnectivityViewModel()
    
    @Published var castViewModel: TR_TVStreamingViewModel
    @Published var connectSDKDiscoveryModel: TR_TVDeviceConnectionViewModel
    
    @Published var connectedTvType: TR_TelevisionType?
    @Published var tvName: String?
    
    @Published var selectedQuality = 0
    @Published var isLoading = true
    @Published var isUploading = false
    
    @Published var isPlaying: Bool = false
    @Published var duration: Float = 0.0
    @Published var playbackPosition: Float = 0.0
    @Published var volume: Float = 0.5
    @Published var isSeeking = false
    @Published var playbackTimer: Timer?
    var tvRemoteViewModel: TR_RemoteViewModel { TR_RemoteViewModel.shared }
    @Published var showVideoControls: Bool = true
    
    private var currentExportSession: AVAssetExportSession?
    
    private var cancellables = Set<AnyCancellable>()
    private let volumeController = GCKUIDeviceVolumeController()
    
    init() {
        self.castViewModel = TR_TVStreamingViewModel.shared
        self.connectSDKDiscoveryModel = TR_TVDeviceConnectionViewModel()
        
        observeAllTvManagersChanges()
    }
    
    private func observeAllTvManagersChanges() {
        castViewModel.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
        
        
        connectSDKDiscoveryModel.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }
    
    
    func setConnectedTv(tvType: TR_TelevisionType) {
        self.connectedTvType = tvType
        self.isDeviceConnected = true
        if tvType == .LG {
            connectSDKDiscoveryModel.isConnectedToLG = true
        }
        configureConnection(for: tvType)
    }
    
    
    @MainActor func disconnectTv() {
        self.connectedTvType = nil
        tvName = nil
        self.isDeviceConnected = false
        castViewModel.disconnectFromDevice()
        connectSDKDiscoveryModel.disconnectFromTV()
        connectSDKDiscoveryModel.disconnectLGDevice()
        
        if let defaults = UserDefaults(suiteName: TR_AppStrings.groupID) {
            defaults.set(false, forKey: "isBroadcasting")
            defaults.set(true, forKey: "shouldStopBroadcast")
            defaults.synchronize()
        }
        TR_MirroringServerManager.shared.stopServer()
        TR_SilentAudioManager.shared.forceStop()
        DeviceConnectionManager.shared.checkMirroringStatus()
    }
    
    
    func getConnectedTvType() -> TR_TelevisionType? {
        if let type = connectedTvType, type != .NONETV { return type }
        if let remoteType = TR_RemoteViewModel.shared.connectedTVType, remoteType != .NONETV { return remoteType }
        if isAirPlayConnected() { return .AIRPLAY }
        if Thread.isMainThread {
            let result: TR_TelevisionType? = MainActor.assumeIsolated {
                if DeviceConnectionManager.shared.isAirPlayConnected { return .AIRPLAY }
                if let dev = DeviceConnectionManager.shared.connectedDevice {
                    if dev.isAirPlay { return .AIRPLAY }
                    if let cDev = dev.connectableDevice {
                        return TR_RemoteViewModel.shared.identifyTVType(from: cDev)
                    }
                }
                return nil
            }
            if let result = result, result != .NONETV { return result }
        }
        return nil
    }
    
    @Published var isDeviceConnected = false
    
    private func configureConnection(for tvType: TR_TelevisionType) {
        switch tvType {
        case .ANDROID:
            connectedTvType = .ANDROID
        case .LG:
            connectedTvType = .LG
        case .AIRPLAY:
            connectedTvType = .AIRPLAY
        case .NONETV:
            break
        case .ROKU:
            connectedTvType = .ROKU
        case .SAMSUNG:
            connectedTvType = .SAMSUNG
        case .FIRE:
            connectedTvType = .FIRE
        }
    }
    
    
    @MainActor func StopCasting() {
        if connectedTvType == .ANDROID || connectedTvType == .SAMSUNG {
            castViewModel.stopCastingSession()
        } else if connectedTvType == .LG {
            connectSDKDiscoveryModel.stopMediaCasting()
        }
    }
    
    
    // MARK: - Start Playback
    func startPlaybackUpdates() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard !self.isSeeking else { return }
            self.updatePlayback()
        }
    }
    
    
    // MARK: - Stop Playback
    func stopPlaybackUpdates() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    
    // MARK: - Update Playback
    func updatePlayback() {
        if castViewModel.selectedDevice != nil {
            guard let remoteMediaClient = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient else {
                return
            }
            
            if let mediaStatus = remoteMediaClient.mediaStatus {
                self.isPlaying = mediaStatus.playerState == .playing
                let newTime = Float(mediaStatus.streamPosition)
                if !isSeeking {
                    self.playbackPosition = newTime
                }
                self.playbackPosition = Float(remoteMediaClient.approximateStreamPosition())
                self.duration = Float(mediaStatus.mediaInformation?.streamDuration ?? 0)
            }
        } else if connectSDKDiscoveryModel.selectedLGDevice != nil {
            connectSDKDiscoveryModel.getCurrentMediaPosition(completion: { position in
                if let position = position {
                    self.playbackPosition = Float(position)
                }
            })
            
            connectSDKDiscoveryModel.getMediaDuration(completion: { duration in
                if let duration = duration {
                    self.duration = Float(duration)
                }
            })
            
            connectSDKDiscoveryModel.isMediaPlaying { isPlaying in
                if isPlaying {
                    self.isPlaying = isPlaying
                }
            }
        }
    }
    
    
    // MARK: - Seek Media
    @MainActor func seek(to time: Float) {
        guard !time.isNaN && !time.isInfinite && time >= 0 else { return }
        let tvType = getConnectedTvType()
        
        let isGCKActive = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient != nil ||
                          castViewModel.isCastingSessionGoing() ||
                          (castViewModel.selectedDevice != nil && castViewModel.isConnected)
        
        // 1. Google Cast (Android TV / Cast-enabled Samsung / Active GCK Session)
        // CRITICAL: Return immediately to avoid sending competing ConnectSDK/UPnP commands which kill GCK session
        if isGCKActive || tvType == .ANDROID {
            castViewModel.seekMedia(to: time)
            isSeeking = false
            return
        }
        
        // 2. ConnectSDK MediaControl (LG, Roku, FireTV)
        if tvType == .LG || tvType == .ROKU || tvType == .FIRE {
            connectSDKDiscoveryModel.seekMedia(to: TimeInterval(time))
            connectSDKDiscoveryModel.selectedLGDevice?.mediaControl()?.seek(TimeInterval(time), success: nil, failure: nil)
            
            let connectedDev = DeviceConnectionManager.shared.connectedDevice
            connectedDev?.connectableDevice?.mediaControl()?.seek(TimeInterval(time), success: nil, failure: nil)
            isSeeking = false
            return
        }
        
        // 3. Samsung UPnP AVTransport Seek + Play (Ensures Samsung TVs play from dropped position)
        if tvType == .SAMSUNG {
            connectSDKDiscoveryModel.seekMedia(to: TimeInterval(time))
            let connectedDev = DeviceConnectionManager.shared.connectedDevice
            connectedDev?.connectableDevice?.mediaControl()?.seek(TimeInterval(time), success: nil, failure: nil)
            
            var targetIP = TR_RemoteViewModel.shared.connectingDeviceAddress
            if targetIP == nil { targetIP = connectedDev?.ipAddress }
            if targetIP == nil { targetIP = connectSDKDiscoveryModel.selectedLGDevice?.address }
            if targetIP == nil { targetIP = connectedDev?.connectableDevice?.address }
            
            if let ip = targetIP {
                SamsungUPnPCaster.shared.seek(tvIP: ip, seconds: TimeInterval(time)) { success in
                    SamsungUPnPCaster.shared.play(tvIP: ip)
                }
            }
            isSeeking = false
            return
        }
        
        // Fallback for generic devices
        connectSDKDiscoveryModel.seekMedia(to: TimeInterval(time))
        isSeeking = false
    }
    
    
    // MARK: - Set Media Volume
    @MainActor func setVolume(_ volume: Float) {
        self.volume = volume
        let tvType = getConnectedTvType()
        if (tvType == .ANDROID || tvType == .SAMSUNG) && castViewModel.selectedDevice != nil && castViewModel.isConnected {
            volumeController.setVolume(volume)
        }
        if tvType == .LG || tvType == .ROKU || tvType == .FIRE || tvType == .SAMSUNG {
            connectSDKDiscoveryModel.selectedLGDevice?.volumeControl()?.setVolume(volume, success: nil, failure: nil)
            DeviceConnectionManager.shared.connectedDevice?.connectableDevice?.volumeControl()?.setVolume(volume, success: nil, failure: nil)
        }
    }
    
    @MainActor func volumeUp() {
        let tvType = getConnectedTvType()
        if (tvType == .ANDROID || tvType == .SAMSUNG) && castViewModel.selectedDevice != nil && castViewModel.isConnected {
            let newVol = min(1.0, volume + 0.01)
            setVolume(newVol)
        } else if connectSDKDiscoveryModel.selectedLGDevice != nil || DeviceConnectionManager.shared.connectedDevice != nil {
            connectSDKDiscoveryModel.selectedLGDevice?.volumeControl()?.volumeUp(success: nil, failure: nil)
            DeviceConnectionManager.shared.connectedDevice?.connectableDevice?.volumeControl()?.volumeUp(success: nil, failure: nil)
        }
    }
    
    @MainActor func volumeDown() {
        let tvType = getConnectedTvType()
        if (tvType == .ANDROID || tvType == .SAMSUNG) && castViewModel.selectedDevice != nil && castViewModel.isConnected {
            let newVol = max(0.0, volume - 0.01)
            setVolume(newVol)
        } else if connectSDKDiscoveryModel.selectedLGDevice != nil || DeviceConnectionManager.shared.connectedDevice != nil {
            connectSDKDiscoveryModel.selectedLGDevice?.volumeControl()?.volumeDown(success: nil, failure: nil)
            DeviceConnectionManager.shared.connectedDevice?.connectableDevice?.volumeControl()?.volumeDown(success: nil, failure: nil)
        }
    }
    
    
    // MARK: - Formate SeekBar Timer
    func formatTime(_ time: Float) -> String {
        guard !time.isNaN, time.isFinite, time >= 0 else { return "00:00" }
        
        let total = Int(time)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    
    // MARK: - Toggle Pause & Resume
    func togglePauseResume() {
        if castViewModel.selectedDevice != nil {
            guard let remoteMediaClient = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient else {
                return
            }
            if isPlaying {
                isPlaying = false
                remoteMediaClient.pause()
            } else {
                isPlaying = true
                remoteMediaClient.play()
            }
        } else if connectSDKDiscoveryModel.selectedLGDevice != nil {
            if isPlaying {
                isPlaying = false
                connectSDKDiscoveryModel.pauseMedia()
            } else {
                isPlaying = true
                connectSDKDiscoveryModel.playMedia()
            }
        }
    }
    
    @MainActor func CastMedia(url: URL, mediaType: String, title: String, des: String, imgHei: Int, imgWid: Int, mediaURL: URL? = nil) {
        // Auto-assign connected ConnectableDevice if needed
        if connectSDKDiscoveryModel.selectedLGDevice == nil {
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    if let dev = DeviceConnectionManager.shared.connectedDevice?.connectableDevice {
                        self.connectSDKDiscoveryModel.selectedLGDevice = dev
                    }
                }
            }
            if connectSDKDiscoveryModel.selectedLGDevice == nil {
                if let lgMan = TR_RemoteViewModel.shared.currentTVManager as? TR_LGControlManager, let dev = lgMan.selectedDevice {
                    connectSDKDiscoveryModel.selectedLGDevice = dev
                } else if let match = TR_RemoteViewModel.shared.discoveredDevices.first {
                    connectSDKDiscoveryModel.selectedLGDevice = match
                }
            }
        }
        
        let tvType = getConnectedTvType()
        print("📺 CastMedia called for TR_TV: \(String(describing: tvType)), media: \(url)")
        
        // Auto-assign Google Cast device ONLY IF connected TR_TV is ANDROID or Cast-based SAMSUNG
        if (tvType == .ANDROID || tvType == .SAMSUNG) && castViewModel.selectedDevice == nil {
            if let targetIP = connectSDKDiscoveryModel.selectedLGDevice?.address,
               let match = gcastDevice.first(where: { $0.ipAddress == targetIP }) {
                castViewModel.selectedDevice = match
            } else if tvType == .ANDROID, let first = gcastDevice.first {
                castViewModel.selectedDevice = first
            }
        }
        
        switch tvType {
        case .ANDROID:
            if castViewModel.selectedDevice != nil || !gcastDevice.isEmpty {
                castViewModel.castMedia(url, mediaType: mediaType, title: title, des: des, mediaURL: mediaURL)
            } else {
                connectSDKDiscoveryModel.sendMediaToLGTV(mediaUrl: url, mimeType: mediaType, title: title, des: des, imgHei: imgHei, imgWid: imgWid, posterURL: mediaURL)
            }
        case .LG, .ROKU, .FIRE:
            connectSDKDiscoveryModel.sendMediaToLGTV(mediaUrl: url, mimeType: mediaType, title: title, des: des, imgHei: imgHei, imgWid: imgWid, posterURL: mediaURL)
        case .SAMSUNG:
            if castViewModel.selectedDevice != nil && castViewModel.isConnected {
                castViewModel.castMedia(url, mediaType: mediaType, title: title, des: des, mediaURL: mediaURL)
            } else {
                connectSDKDiscoveryModel.sendMediaToLGTV(mediaUrl: url, mimeType: mediaType, title: title, des: des, imgHei: imgHei, imgWid: imgWid, posterURL: mediaURL)
            }
        case .AIRPLAY:
            break
        case .NONETV, .none:
            // Comprehensive fallback attempt only for DLNA / Cast devices
            if connectSDKDiscoveryModel.selectedLGDevice != nil {
                connectSDKDiscoveryModel.sendMediaToLGTV(mediaUrl: url, mimeType: mediaType, title: title, des: des, imgHei: imgHei, imgWid: imgWid, posterURL: mediaURL)
            } else if castViewModel.selectedDevice != nil && castViewModel.isConnected {
                castViewModel.castMedia(url, mediaType: mediaType, title: title, des: des, mediaURL: mediaURL)
            } else {
                print("❌ No TR_TV device connected for casting")
            }
        }
    }
    
    // MARK: - Direct Image Casting
    func castUIImage(_ image: UIImage, quality: Int = 1, title: String = TR_AppStrings.appName) {
        var isAirPlay = isAirPlayConnected()
        if !isAirPlay && Thread.isMainThread {
            isAirPlay = MainActor.assumeIsolated { DeviceConnectionManager.shared.isAirPlayConnected }
        }
        if isAirPlay {
            TR_ImageCastAirPlayManager.shared.playUIImageImage(image)
            return
        }
        
        if TR_CastingServerManager.shared.effectiveServerURL == nil {
            TR_CastingServerManager.shared.setupServer()
        }
        
        guard let serverBaseURL = TR_CastingServerManager.shared.effectiveServerURL ?? TR_CastingServerManager.shared.serverURL else {
            print("❌ Invalid server URL for casting image")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let compressionQuality: CGFloat
            switch quality {
            case 0: compressionQuality = 0.5
            case 1: compressionQuality = 0.75
            case 2: compressionQuality = 0.95
            default: compressionQuality = 0.75
            }
            
            guard let data = image.jpegData(compressionQuality: compressionQuality) else { return }
            let smDirectPhotoFileName = "photo_" + UUID().uuidString + ".jpg"
            let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(smDirectPhotoFileName)
            
            do {
                try data.write(to: destinationURL)
                let mediaUrl = serverBaseURL.appendingPathComponent("files/\(smDirectPhotoFileName)")
                print("📺 Direct photo prepared at: \(mediaUrl)")
                DispatchQueue.main.async {
                    self.CastMedia(
                        url: mediaUrl,
                        mediaType: "image/jpeg",
                        title: title,
                        des: "",
                        imgHei: Int(image.size.height),
                        imgWid: Int(image.size.width)
                    )
                }
            } catch {
                print("❌ Failed to write photo data: \(error)")
            }
        }
    }
    
    @MainActor func IPTVCast(mediaUrl: URL, title: String, des: String) {
        let tvType = getConnectedTvType()
        if tvType == .LG {
            connectSDKDiscoveryModel.sendIPTVToLGTV(mediaUrl: mediaUrl, title: title)
            return
        }
        
        let urlLower = mediaUrl.absoluteString.lowercased()
        let mimeType: String
        if urlLower.contains(".m3u8") || urlLower.contains("m3u8") {
            mimeType = "application/x-mpegURL"
        } else if urlLower.contains(".mpd") {
            mimeType = "application/dash+xml"
        } else if urlLower.contains(".ts") {
            mimeType = "video/mp2t"
        } else {
            mimeType = "video/mp4"
        }
        
        CastMedia(url: mediaUrl, mediaType: mimeType, title: title, des: des, imgHei: 1080, imgWid: 1920)
    }
    
    @MainActor func WebCasting(mediaUrl: URL, title: String, des: String){
        if getConnectedTvType() == .ANDROID || getConnectedTvType() == .SAMSUNG {
            CastMedia(url: mediaUrl, mediaType: "video/mp4", title: title, des: des, imgHei: 1024, imgWid: 1024)
        } else {
            connectSDKDiscoveryModel.sendMediaToLGTVWeb(mediaUrl: mediaUrl)
        }
    }
    
    func stopRemoteMediaClient() {
        if getConnectedTvType() == .ANDROID {
            castViewModel.StopRemoteMediaCleint()
        }
    }
    
    @MainActor func stopMediaCasting() {
        let isMirroring = DeviceConnectionManager.shared.isMirroringActive
            || UIScreen.main.isCaptured
            || (UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") == true)
            || TR_MirroringServerManager.shared.isMirroringActive
            
        if isMirroring {
            print("🛡️ TV Remote is active - preserving mirroring session and skipping media placeholder")
            return
        }
        
        let isAirPlay = isAirPlayConnected() || DeviceConnectionManager.shared.isAirPlayConnected || getConnectedTvType() == .AIRPLAY
        if isAirPlay {
            isPlaying = false
            stopPlaybackUpdates()
            return
        }
        
        let currentType = getConnectedTvType() ?? connectedTvType ?? .ANDROID
        switch currentType {
        case .ANDROID:
            castViewModel.StopRemoteMediaCleint()
        case .LG:
            connectSDKDiscoveryModel.stopMediaCasting()
        case .AIRPLAY:
            break
        case .NONETV:
            break
        case .ROKU:
            break
        case .SAMSUNG:
            castViewModel.StopRemoteMediaCleint()
            break
        case .FIRE:
            break
        }
        
        isPlaying = false
        stopPlaybackUpdates()
        setTVPlaceHolder(connectedTvType: currentType)
    }
    
    func resetMediaControl() {
        duration = 0.0
        playbackPosition = 0.0
        volume = 0.0
    }
    
    func uploadFile(_ url: URL, mediaType: String, title: String, des: String, imgHei: Int, imgWid: Int) {
        if TR_CastingServerManager.shared.effectiveServerURL == nil {
            TR_CastingServerManager.shared.setupServer()
        }
        
        guard let serverBaseURL = TR_CastingServerManager.shared.effectiveServerURL ?? TR_CastingServerManager.shared.serverURL else {
            print("❌ Invalid server URL - GCDWebServer not running")
            DispatchQueue.main.async { self.isUploading = false }
            return
        }
        
        // Fast path: Copy file directly into NSTemporaryDirectory() so GCDWebServer serves immediately via /files/
        let ext = url.pathExtension.isEmpty ? (mediaType.contains("image") ? "jpg" : "mp4") : url.pathExtension
        let smUploadFileName = UUID().uuidString + "." + ext
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(smUploadFileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: url, to: destinationURL)
            let mediaUrl = serverBaseURL.appendingPathComponent("files/\(smUploadFileName)")
            print("📺 Media prepared locally at: \(mediaUrl)")
            DispatchQueue.main.async {
                self.isUploading = false
                self.CastMedia(url: mediaUrl, mediaType: mediaType, title: title, des: des, imgHei: imgHei, imgWid: imgWid)
            }
            return
        } catch {
            print("⚠️ Direct file copy failed, falling back to HTTP POST: \(error)")
        }
        
        let uploadEndpoint = serverBaseURL.appendingPathComponent("upload")
        var request = URLRequest(url: uploadEndpoint)
        request.httpMethod = "POST"
        request.setValue(mediaType, forHTTPHeaderField: "Content-Type")
        
        DispatchQueue.main.async {
            do {
                let fileData = try Data(contentsOf: url)
                self.isUploading = true
                
                let smUploadTask = URLSession.shared.uploadTask(with: request, from: fileData) { data, response, error in
                    DispatchQueue.main.async { self.isUploading = false }
                    
                    if let error = error {
                        print("Upload error: \(error)")
                        return
                    }
                    
                    guard
                        let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                        let data = data,
                        let responseUrl = String(data: data, encoding: .utf8),
                        let mediaUrl = URL(string: responseUrl)
                    else {
                        print("Invalid response")
                        return
                    }
                    print("📺 Connected TR_TV Type:", self.getConnectedTvType() as Any)
                    print("Media uploaded to: \(mediaUrl)")
                    DispatchQueue.main.async {
                        self.CastMedia(url: mediaUrl, mediaType: mediaType, title: title, des: des, imgHei: imgHei, imgWid: imgWid)
                    }
                }
                
                smUploadTask.resume()
            } catch {
                print("Error reading file data: \(error)")
                DispatchQueue.main.async { self.isUploading = false }
            }
        }
    }
    
    // Serve local video file directly from disk
    func castLocalVideoFile(_ url: URL, title: String = TR_AppStrings.appName, des: String = "", imgHei: Int = 0, imgWid: Int = 0) {
        if TR_CastingServerManager.shared.effectiveServerURL == nil {
            TR_CastingServerManager.shared.setupServer()
        }
        
        guard let baseURL = TR_CastingServerManager.shared.effectiveServerURL ?? TR_CastingServerManager.shared.serverURL else {
            print("❌ Server URL not ready")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
            let smLocalVideoFileName = "video_" + UUID().uuidString + "." + ext
            let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(smLocalVideoFileName)
            
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(atPath: destinationURL.path)
            }
            
            if (try? FileManager.default.copyItem(at: url, to: destinationURL)) != nil {
                let mediaUrl = baseURL.appendingPathComponent("files/\(smLocalVideoFileName)")
                print("📺 Media serving instantly from local copy at: \(mediaUrl)")
                DispatchQueue.main.async {
                    self.CastMedia(url: mediaUrl, mediaType: "video/mp4", title: title, des: des, imgHei: imgHei, imgWid: imgWid)
                }
            } else {
                TR_CastingServerManager.shared.setLocalVideoToServe(url.path)
                let cacheBuster = UUID().uuidString
                let mediaUrl = baseURL.appendingPathComponent("localvideo/\(cacheBuster).mp4")
                print("📺 Media serving from direct path at: \(mediaUrl)")
                DispatchQueue.main.async {
                    self.CastMedia(url: mediaUrl, mediaType: "video/mp4", title: title, des: des, imgHei: imgHei, imgWid: imgWid)
                }
            }
        }
    }
    
    // MARK: - Photo casting
    func compressAndUploadImage(from url: URL, mediaType: String, title: String, des: String, imgHei : Int, imgWid : Int,selectedQuality : Int) {
        guard let image = UIImage(contentsOfFile: url.path) else {
            print("Unable to load image from URL")
            return
        }
        
        let smTargetPhotoSize: CGSize
        switch selectedQuality {
        case 0:
            smTargetPhotoSize = CGSize(width: 1280, height: 720)
        case 1:
            smTargetPhotoSize = CGSize(width: 1920, height: 1080)
        case 2:
            smTargetPhotoSize = CGSize(width: 3840, height: 2160)
        default:
            smTargetPhotoSize = CGSize(width: 1280, height: 720)
        }
        
        let compressionQuality: CGFloat
        switch selectedQuality {
        case 0:
            compressionQuality = 0.2
        case 1:
            compressionQuality = 0.6
        case 2:
            compressionQuality = 1.0
        default:
            compressionQuality = 0.6
        }
        
        let smResizedPhoto = smScalePhotoToTargetSize(image: image, targetSize: smTargetPhotoSize)
        if let compressedImageData = smResizedPhoto.jpegData(compressionQuality: compressionQuality) {
            let compressedURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("compressed_image_\(UUID().uuidString).jpg")
            do {
                try compressedImageData.write(to: compressedURL)
                uploadFile(compressedURL, mediaType: mediaType, title: title, des: des, imgHei: imgHei, imgWid: imgWid)
            } catch {
                print("Error writing compressed image to temporary URL: \(error)")
            }
        } else {
            print("Failed to compress image")
        }
    }
    
    // MARK: - Video casting
    func compressAndUploadVideo(_ url: URL) {
            
            // ✅ FIX 1: Agar pehle se koi export chal raha hai to usse cancel karo
            // Isse concurrent heavy 4K exports stack hone se bachte hain (crash ki asli wajah)
            currentExportSession?.cancelExport()
            currentExportSession = nil
            
            let asset = AVAsset(url: url)
            let presetName: String
            
            switch selectedQuality {
            case 0:
                presetName = AVAssetExportPreset1280x720
            case 1:
                presetName = AVAssetExportPreset1920x1080
            case 2:
                presetName = AVAssetExportPreset3840x2160
            default:
                presetName = AVAssetExportPreset1280x720
            }
            
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: presetName) else {
                print("Failed to create export session")
                DispatchQueue.main.async {
                    self.isUploading = false
                }
                return
            }
            
            // ✅ FIX 2: Disk space check — bade 4K video export ke liye kaafi free space chahiye
            // Warna disk-full hone par crash / silent failure hota hai
            let requiredSpaceMB: Int64 = 1024  // ~1GB buffer, apni need ke hisaab se adjust karo
            if let freeSpaceMB = availableDiskSpaceInMB(), freeSpaceMB < requiredSpaceMB {
                print("❌ Not enough disk space to compress video: \(freeSpaceMB) MB free")
                DispatchQueue.main.async {
                    self.isUploading = false
                }
                return
            }
            
            let compressedURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            
            // ✅ FIX 3: Defensive cleanup — agar galti se file exist karti ho to hata do
            try? FileManager.default.removeItem(at: compressedURL)
            
            exportSession.outputURL = compressedURL
            exportSession.outputFileType = .mp4
            
            // ✅ current session ko track karo taaki agla call ise cancel kar sake
            currentExportSession = exportSession
            
            DispatchQueue.main.async {
                self.isUploading = true
            }
            
            exportSession.exportAsynchronously { [weak self] in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    
                    // Cleanup reference
                    if self.currentExportSession === exportSession {
                        self.currentExportSession = nil
                    }
                    
                    switch exportSession.status {
                    case .completed:
                        print("Video compressed successfully")
                        self.uploadFile(
                            compressedURL,
                            mediaType: "video/mp4",
                            title: TR_AppStrings.appName,
                            des: "",
                            imgHei: 1024,
                            imgWid: 1024
                        )
                        
                        // ✅ FIX 4: Upload ke baad temp file delete karo (disk fill hone se bachao)
                        // Agar uploadFile async hai to isse thoda delay karke ya uploadFile ke completion mein call karo
                        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                            try? FileManager.default.removeItem(at: compressedURL)
                        }
                        
                    case .failed:
                        self.isUploading = false
                        if let error = exportSession.error {
                            print("Video compression failed: \(error.localizedDescription)")
                        }
                        try? FileManager.default.removeItem(at: compressedURL)
                        
                    case .cancelled:
                        self.isUploading = false
                        print("Video compression cancelled")
                        try? FileManager.default.removeItem(at: compressedURL)
                        
                    default:
                        break
                    }
                }
            }
        }
        
        // ✅ Helper: available disk space nikalne ke liye
        private func availableDiskSpaceInMB() -> Int64? {
            do {
                let systemAttributes = try FileManager.default.attributesOfFileSystem(
                    forPath: NSHomeDirectory()
                )
                if let freeSpace = systemAttributes[.systemFreeSize] as? Int64 {
                    return freeSpace / (1024 * 1024)
                }
            } catch {
                print("❌ Error checking disk space: \(error.localizedDescription)")
            }
            return nil
        }
    
    // MARK: - Video Casting with Thumbnail
    @MainActor func uploadVideoWithThumbnail(videoURL: URL, thumbnail: UIImage?, title: String) {
        if TR_CastingServerManager.shared.effectiveServerURL == nil {
            TR_CastingServerManager.shared.setupServer()
        }
        
        guard let serverBaseURL = TR_CastingServerManager.shared.effectiveServerURL ?? TR_CastingServerManager.shared.serverURL else {
            print("❌ Invalid server URL for video")
            return
        }
        
        let ext = videoURL.pathExtension.isEmpty ? "mp4" : videoURL.pathExtension
        let smPreparedVideoFileName = "video_" + UUID().uuidString + "." + ext
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(smPreparedVideoFileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(atPath: destinationURL.path)
            }
            try FileManager.default.copyItem(at: videoURL, to: destinationURL)
            let mediaUrl = serverBaseURL.appendingPathComponent("files/\(smPreparedVideoFileName)")
            print("📺 Video prepared locally at: \(mediaUrl)")
            
            DispatchQueue.main.async {
                if self.getConnectedTvType() != .NONETV {
                    if let thumb = thumbnail {
                        self.uploadThumbnailAsset(named: thumb) { thumbURL in
                            self.CastMedia(url: mediaUrl, mediaType: "video/mp4", title: title, des: "", imgHei: 1080, imgWid: 1920, mediaURL: thumbURL)
                        }
                    } else {
                        self.CastMedia(url: mediaUrl, mediaType: "video/mp4", title: title, des: "", imgHei: 1080, imgWid: 1920)
                    }
                }
            }
        } catch {
            print("❌ Failed to copy video file to server temp dir: \(error)")
            let mediaUrl = serverBaseURL.appendingPathComponent("files/\(videoURL.lastPathComponent)")
            if let thumb = thumbnail {
                self.uploadThumbnailAsset(named: thumb) { thumbURL in
                    self.CastMedia(url: mediaUrl, mediaType: "video/mp4", title: title, des: "", imgHei: 1080, imgWid: 1920, mediaURL: thumbURL)
                }
            } else {
                self.CastMedia(url: mediaUrl, mediaType: "video/mp4", title: title, des: "", imgHei: 1080, imgWid: 1920)
            }
        }
    }
    
    // MARK: - Audio casting
    func compressAndUploadAudio(_ url: URL, selectedQuality: Int, title: String, des: String, itemImage: UIImage) {
        // If file exists locally (mp3, m4a, wav), serve it directly with accurate MIME type
        if FileManager.default.fileExists(atPath: url.path) {
            let ext = url.pathExtension.lowercased()
            let mimeType: String
            if ext == "mp3" {
                mimeType = "audio/mpeg"
            } else if ext == "wav" {
                mimeType = "audio/wav"
            } else if ext == "mp4" || ext == "m4a" {
                mimeType = "audio/mp4"
            } else {
                mimeType = "audio/mp4"
            }
            uploadMusicFile(url, mediaType: mimeType, title: title, des: des, itemImage: itemImage, imgHei: 1024, imgWid: 1024)
            return
        }
        
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        exportMusic(from: url, to: destinationURL) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.uploadMusicFile(destinationURL, mediaType: "audio/mp4", title: title, des: des, itemImage: itemImage, imgHei: 1024, imgWid: 1024)
                } else {
                    self?.isUploading = false
                    print("Audio export failed")
                }
            }
        }
    }
    
    // MARK: - Audio casting function
    private func exportMusic(from url: URL, to destinationURL: URL, completion: @escaping (Bool) -> Void) {
        let asset = AVAsset(url: url)
        guard let assetExportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            print("Failed to create export session")
            completion(false)
            return
        }
        
        assetExportSession.outputURL = destinationURL
        assetExportSession.outputFileType = .m4a
        
        assetExportSession.exportAsynchronously {
            switch assetExportSession.status {
            case .completed:
                completion(true)
            case .failed:
                print("Failed to export asset: \(String(describing: assetExportSession.error))")
                completion(false)
            default:
                print("Export session status: \(assetExportSession.status)")
                completion(false)
            }
        }
    }
    
    // MARK: - Photo resizing to the quality selected
    func smScalePhotoToTargetSize(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        var newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        let rect = CGRect(origin: .zero, size: newSize)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
    
    // MARK: - upload to local server and then serve the tv
    func uploadMusicFile(_ url: URL, mediaType: String, title: String, des: String, itemImage: UIImage, imgHei: Int, imgWid: Int) {
        if TR_CastingServerManager.shared.effectiveServerURL == nil {
            TR_CastingServerManager.shared.setupServer()
        }
        
        guard let serverBaseURL = TR_CastingServerManager.shared.effectiveServerURL ?? TR_CastingServerManager.shared.serverURL else {
            print("❌ Invalid server URL for audio")
            DispatchQueue.main.async { self.isUploading = false }
            return
        }
        
        let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
        let smAudioUploadFileName = "audio_" + UUID().uuidString + "." + ext
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(smAudioUploadFileName)
        let destinationPath = destinationURL.path
        
        do {
            if FileManager.default.fileExists(atPath: destinationPath) {
                try? FileManager.default.removeItem(atPath: destinationPath)
            }
            try FileManager.default.copyItem(at: url, to: destinationURL)
            let mediaUrl = serverBaseURL.appendingPathComponent("files/\(smAudioUploadFileName)")
            print("📺 Audio prepared locally at: \(mediaUrl)")
            
            DispatchQueue.main.async {
                self.isUploading = false
                if self.getConnectedTvType() != .NONETV {
                    self.uploadThumbnailAsset(named: itemImage) { thumbURL in
                        if let imgUrl = thumbURL {
                            self.CastMedia(url: mediaUrl, mediaType: mediaType, title: title, des: des, imgHei: imgHei, imgWid: imgWid, mediaURL: imgUrl)
                        } else {
                            self.CastMedia(url: mediaUrl, mediaType: mediaType, title: title, des: des, imgHei: imgHei, imgWid: imgWid)
                        }
                    }
                } else {
                    print("❌ No device connected, skipping cast")
                }
            }
            return
        } catch {
            print("⚠️ Direct audio copy failed, falling back to HTTP POST: \(error)")
        }
        
        let uploadEndpoint = serverBaseURL.appendingPathComponent("upload")
        var request = URLRequest(url: uploadEndpoint)
        request.httpMethod = "POST"
        request.setValue(mediaType, forHTTPHeaderField: "Content-Type")
        
        DispatchQueue.main.async {
            do {
                let fileData = try Data(contentsOf: url)
                self.isUploading = true
                
                let smAudioUploadTask = URLSession.shared.uploadTask(with: request, from: fileData) { data, response, error in
                    DispatchQueue.main.async { self.isUploading = false }
                    
                    if let error = error {
                        print("Upload error: \(error)")
                        return
                    }
                    
                    guard
                        let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                        let data = data,
                        let responseUrl = String(data: data, encoding: .utf8),
                        let mediaUrl = URL(string: responseUrl)
                    else {
                        print("Invalid response")
                        return
                    }
                    print("📺 Connected TR_TV Type:", self.getConnectedTvType() as Any)
                    print("Media uploaded to: \(mediaUrl)")
                    DispatchQueue.main.async {
                        if self.getConnectedTvType() != .NONETV {
                            self.uploadThumbnailAsset(named: itemImage) { thumbURL in
                                if let imgUrl = thumbURL {
                                    self.CastMedia(url: mediaUrl, mediaType: mediaType, title: title, des: des, imgHei: imgHei, imgWid: imgWid, mediaURL: imgUrl)
                                } else {
                                    self.CastMedia(url: mediaUrl, mediaType: mediaType, title: title, des: des, imgHei: imgHei, imgWid: imgWid)
                                }
                            }
                        } else {
                            print("❌ No device connected, skipping cast")
                        }
                    }
                }
                smAudioUploadTask.resume()
            } catch {
                print("Error reading file data: \(error)")
                DispatchQueue.main.async { self.isUploading = false }
            }
        }
    }
//    func uploadMusicFile(_ url: URL, mediaType: String, title: String, des: String, itemImage : UIImage,imgHei : Int, imgWid : Int) {
//        guard var serverUrl = TR_CastingServerManager.shared.serverURL else {
//            print("Invalid server URL")
//            DispatchQueue.main.async { self.isUploading = false }
//            return
//        }
//        
//        serverUrl.appendPathComponent("upload")
//        
//        var request = URLRequest(url: serverUrl)
//        request.httpMethod = "POST"
//        request.setValue(mediaType, forHTTPHeaderField: "Content-Type")
//        DispatchQueue.main.async {
//            do {
//                let fileData = try Data(contentsOf: url)
//                
//                // Ensure UI update
//                DispatchQueue.main.async { self.isUploading = true }
//                
//                let task = URLSession.shared.uploadTask(with: request, from: fileData) { data, response, error in
//                    DispatchQueue.main.async { self.isUploading = false }
//                    
//                    if let error = error {
//                        print("Upload error: \(error)")
//                        return
//                    }
//                    
//                    guard
//                        let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
//                        let data = data,
//                        let responseUrl = String(data: data, encoding: .utf8),
//                        let mediaUrl = URL(string: responseUrl)
//                    else {
//                        print("Invalid response")
//                        return
//                    }
//                    print("📺 Connected TR_TV Type:", self.getConnectedTvType() as Any)
//                    print("Media uploaded to: \(mediaUrl)")
//                    DispatchQueue.main.async {
//                        if self.getConnectedTvType() != .NONETV {
//                            self.uploadThumbnailAsset(named: itemImage) { thumbURL in
//                                if let imgUrl = thumbURL{
//                                    self.CastMedia(url: mediaUrl, mediaType: mediaType, title: title, des: des, imgHei: imgHei, imgWid: imgWid, mediaURL: imgUrl)
//                                }else{
//                                    self.CastMedia(url: mediaUrl, mediaType: mediaType, title: title, des: des, imgHei: imgHei, imgWid: imgWid)
//                                }
//                            }
//                        } else {
//                            print("❌ No device connected, skipping cast")
//                        }
//                    }
//                }
//                
//                task.resume()
//            } catch {
//                print("Error reading file data: \(error)")
//                DispatchQueue.main.async { self.isUploading = false }
//            }
//        }
//    }
    
    func uploadThumbnailAsset(named assetName: UIImage, completion: @escaping (URL?) -> Void) {
        guard let imageData = assetName.jpegData(compressionQuality: 0.85) ?? assetName.pngData() else {
            print("Failed to convert asset to JPEG/PNG data")
            completion(nil)
            return
        }
        
        let smThumbFileName = "thumb_" + UUID().uuidString + ".jpg"
        let destURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(smThumbFileName)
        do {
            try imageData.write(to: destURL)
            if TR_CastingServerManager.shared.effectiveServerURL == nil {
                TR_CastingServerManager.shared.setupServer()
            }
            guard let serverBaseURL = TR_CastingServerManager.shared.effectiveServerURL ?? TR_CastingServerManager.shared.serverURL else {
                print("❌ Invalid server URL for thumbnail")
                completion(nil)
                return
            }
            let mediaUrl = serverBaseURL.appendingPathComponent("files/\(smThumbFileName)")
            print("📺 Thumbnail prepared directly at: \(mediaUrl)")
            completion(mediaUrl)
        } catch {
            print("Failed to write thumbnail: \(error)")
            completion(nil)
        }
    }
    
    private func uploadThumbnailFile(_ url: URL, mediaType: String, completion: @escaping (URL?) -> Void) {
        if TR_CastingServerManager.shared.effectiveServerURL == nil {
            TR_CastingServerManager.shared.setupServer()
        }
        
        guard let serverBaseURL = TR_CastingServerManager.shared.effectiveServerURL ?? TR_CastingServerManager.shared.serverURL else {
            print("❌ Invalid server URL for thumbnail")
            completion(nil)
            return
        }
        
        let ext = (mediaType == "image/jpeg" || mediaType == "image/jpg") ? "jpg" : "png"
        let smThumbFileWithExt = "thumb_" + UUID().uuidString + ".\(ext)"
        let destPath = NSTemporaryDirectory().appending(smThumbFileWithExt)
        let destURL = URL(fileURLWithPath: destPath)
        
        do {
            if FileManager.default.fileExists(atPath: destPath) {
                try? FileManager.default.removeItem(atPath: destPath)
            }
            try FileManager.default.copyItem(at: url, to: destURL)
            let mediaUrl = serverBaseURL.appendingPathComponent("files/\(smThumbFileWithExt)")
            print("📺 Thumbnail prepared locally at: \(mediaUrl)")
            completion(mediaUrl)
            return
        } catch {
            print("Direct copy for thumbnail failed: \(error)")
        }
        
        let uploadEndpoint = serverBaseURL.appendingPathComponent("upload")
        var request = URLRequest(url: uploadEndpoint)
        request.httpMethod = "POST"
        request.setValue(mediaType, forHTTPHeaderField: "Content-Type")
        
        do {
            let fileData = try Data(contentsOf: url)
            let smThumbTask = URLSession.shared.uploadTask(with: request, from: fileData) { data, response, error in
                if let error = error {
                    print("Thumbnail upload error: \(error)")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                guard
                    let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                    let data = data,
                    let responseUrl = String(data: data, encoding: .utf8),
                    let thumbnailUrl = URL(string: responseUrl)
                else {
                    print("Invalid thumbnail upload response")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                print("Thumbnail uploaded to: \(thumbnailUrl)")
                DispatchQueue.main.async { completion(thumbnailUrl) }
            }
            smThumbTask.resume()
        } catch {
            print("Error reading thumbnail file data: \(error)")
            DispatchQueue.main.async { completion(nil) }
        }
    }
//    func uploadThumbnailAsset(named assetName: UIImage, completion: @escaping (URL?) -> Void) {
//        
//        guard let imageData = assetName.pngData() else {
//            print("Failed to convert asset to PNG data")
//            completion(nil)
//            return
//        }
//        // Write to a temp file so we have a URL, matching what uploadFile(_:) expects elsewhere
//        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(assetName).png")
//        do {
//            try imageData.write(to: tempURL)
//        } catch {
//            print("Failed to write temp thumbnail file: \(error)")
//            completion(nil)
//            return
//        }
//        uploadThumbnailFile(tempURL, mediaType: "image/png", completion: completion)
//    }
//    
//    private func uploadThumbnailFile(_ url: URL, mediaType: String, completion: @escaping (URL?) -> Void) {
//        guard var serverUrl = TR_CastingServerManager.shared.serverURL else {
//            print("Invalid server URL")
//            completion(nil)
//            return
//        }
//        
//        serverUrl.appendPathComponent("upload")
//        
//        var request = URLRequest(url: serverUrl)
//        request.httpMethod = "POST"
//        request.setValue(mediaType, forHTTPHeaderField: "Content-Type")
//        
//        do {
//            let fileData = try Data(contentsOf: url)
//            
//            let task = URLSession.shared.uploadTask(with: request, from: fileData) { data, response, error in
//                if let error = error {
//                    print("Thumbnail upload error: \(error)")
//                    DispatchQueue.main.async { completion(nil) }
//                    return
//                }
//                
//                guard
//                    let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
//                    let data = data,
//                    let responseUrl = String(data: data, encoding: .utf8),
//                    let thumbnailUrl = URL(string: responseUrl)
//                else {
//                    print("Invalid thumbnail upload response")
//                    DispatchQueue.main.async { completion(nil) }
//                    return
//                }
//                
//                print("Thumbnail uploaded to: \(thumbnailUrl)")
//                DispatchQueue.main.async { completion(thumbnailUrl) }
//            }
//            
//            task.resume()
//        } catch {
//            print("Error reading thumbnail file data: \(error)")
//            DispatchQueue.main.async { completion(nil) }
//        }
//    }
    
    
    func isAirPlayConnected() -> Bool {
        if TR_AirPlayManager.shared.isAirPlayConnected { return true }
        if Thread.isMainThread {
            let dmConnected = MainActor.assumeIsolated { DeviceConnectionManager.shared.isAirPlayConnected }
            if dmConnected { return true }
        }
        return false
    }
    
    @MainActor func isTVConnected() -> Bool {
        return DeviceConnectionManager.shared.isActuallyConnected
    }
    
    @MainActor func isConnected() -> Bool {
        return isTVConnected()
    }
    
    @MainActor func isAnyDeviceConnected() -> Bool {
        return isTVConnected()
    }
}

//extension TR_DeviceConnectivityViewModel {
//    @MainActor func setTVPlaceHolder(connectedTvType: TR_TelevisionType) {
//        if isAirPlayConnected() || DeviceConnectionManager.shared.isAirPlayConnected || connectedTvType == .AIRPLAY {
//            return
//        }
//        if let asset = UIImage(named: "TVBanner") {
//            castUIImage(asset, quality: 2, title: TR_AppStrings.appName)
//        } else if let bannerURL = URL(string: androidBannerUrl) {
//            CastMedia(url: bannerURL, mediaType: "image/jpeg", title: TR_AppStrings.appName, des: "", imgHei: 1080, imgWid: 1920)
//        }
//    }
//}
extension TR_DeviceConnectivityViewModel {
    @MainActor func setTVPlaceHolder(connectedTvType: TR_TelevisionType){
        if connectedTvType == .ANDROID || connectedTvType == .SAMSUNG || connectedTvType == .FIRE || connectedTvType == .ROKU {
            CastMedia(url: URL(string: androidBannerUrl)!, mediaType: "image/jpeg",title: "", des: "", imgHei: 4096, imgWid: 2280)
        }
        else if connectedTvType == .LG {
            guard let asset = UIImage(named: "TVBanner") else { return }
            if let imageData = asset.jpegData(compressionQuality: 1.0) {
                let tempDirectory = FileManager.default.temporaryDirectory
                let smSplashBannerFileName = "loading bar" + ".jpg"
                let fileURL = tempDirectory.appendingPathComponent(smSplashBannerFileName)
                do {
                    try imageData.write(to: fileURL)
                    print("✅ Image saved temporarily at: \(fileURL)")
                    compressAndUploadImage(from: fileURL, mediaType: "image/jpeg", title: "", des: "", imgHei: 4096, imgWid: 2280, selectedQuality: 2)
                } catch {
                    print("❌ Failed to save image to temp file: \(error)")
                }
            }
        }
    }
}

