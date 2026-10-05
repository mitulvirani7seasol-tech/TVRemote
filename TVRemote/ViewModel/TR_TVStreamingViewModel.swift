//
//  TVCastViewModel.swift
//  ClarioMirror
//
//  Created by Vivek Rakholiya on 06/05/26.
//

import Foundation
import Combine
import GoogleCast
import ConnectSDK

var gcastDevice: [GCKDevice] = []
class TR_TVStreamingViewModel: NSObject, ObservableObject, GCKDiscoveryManagerListener  {
//    @Published var devices: [GCKDevice] = []
    @Published var selectedDevice: GCKDevice?
    @Published var isDiscovering: Bool = false
    @Published var isCastingInProgress = false
    @Published var isConnected = false
    let SELECTED_TV = "SELECTED_TV"
    static let shared = TR_TVStreamingViewModel()
    var superVC : UIViewController?
    var castDetail: TR_CastDetail?
    var onStartVideo: (() -> Void)?
    
    var discoveryManager: GCKDiscoveryManager?
    private var sessionCompletionHandler: ((Bool) -> Void)?
    private var pendingMediaToCast: (url: URL, mediaType: String)?
    
    
    override init() {
        super.init()
        GCKCastContext.sharedInstance().sessionManager.add(self)
        startDiscovery()
    }
    
    func startDiscovery() {
        isDiscovering = true
        
        discoveryManager?.stopDiscovery()
        let receiverAppID = kGCKDefaultMediaReceiverApplicationID
        let discoveryCriteria = GCKDiscoveryCriteria(applicationID: receiverAppID)
        let options = GCKCastOptions(discoveryCriteria: discoveryCriteria)
        options.suspendSessionsWhenBackgrounded = false
        GCKCastContext.setSharedInstanceWith(options)
        
        GCKLogger.sharedInstance().delegate = self
        
        discoveryManager = GCKCastContext.sharedInstance().discoveryManager
        discoveryManager?.add(self)
        discoveryManager?.passiveScan = false
        discoveryManager?.startDiscovery()
        print("CastViewModel Devices :-  \(discoveryManager?.deviceCount ?? 0) \(gcastDevice)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.isDiscovering = false
        }
    }
    
    func connectToDevice(_ device: GCKDevice, isShowPopup : Bool) {
        selectedDevice = device
        isConnected = true
        selectedTvType = .ANDROID
        startDefaultMediaPlayerSession(with: device)
        
        setSelectedTV(name: "Gcast-\(device.friendlyName ?? "GcastTV")")
        
        print("Connected to device: \(selectedDevice?.friendlyName ?? "Unknown")")
    }
    
    func setSelectedTV(name:String){
        UserDefaults().set(name, forKey: SELECTED_TV)
        UserDefaults().synchronize()
    }
    
    func disconnectFromDevice() {
        if let castSession = GCKCastContext.sharedInstance().sessionManager.currentCastSession {
            castSession.end(with: .stopCasting)
            selectedDevice = nil
            GCKCastContext.sharedInstance().sessionManager.remove(self)
            print("Disconnected from device")
        }
        selectedDevice = nil
        isConnected = false
    }
    
    func stopCastingSession() {
        if let castSession = GCKCastContext.sharedInstance().sessionManager.currentCastSession {
            castSession.end(with: .stopCasting)
            isCastingInProgress = false
            print("Disconnected from device")
        }
    }
    
    func isCastingSessionGoing() -> Bool {
        return GCKCastContext.sharedInstance().sessionManager.currentCastSession != nil
    }
    
    func setDefaultSessionOptions(for appID: String) {
        GCKCastContext.sharedInstance().sessionManager.setDefaultSessionOptions(
            ["gck_applicationID": NSString(string: appID)],
            forDeviceCategory: kGCKCastDeviceCategory
        )
    }
    
    func startDefaultMediaPlayerSession(with device: GCKDevice) {
        print("Starting default media session")
        setDefaultSessionOptions(for: kGCKDefaultMediaReceiverApplicationID)
        GCKCastContext.sharedInstance().sessionManager.startSession(with: device)
    }
    
    func startCustomReceiverSession(with device: GCKDevice) {
        setDefaultSessionOptions(for: TR_AppStrings.kCustomReceiverAppID)
        GCKCastContext.sharedInstance().sessionManager.startSession(with: device)
    }
    
    func StopRemoteMediaCleint() {
        guard let remoteMediaClient = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient else {
            return
        }
        remoteMediaClient.stop()
    }
    
    func startCastSession() {
        let connectedType = TR_DeviceConnectivityViewModel.shared.getConnectedTvType()
        if connectedType == .LG || connectedType == .ROKU || connectedType == .FIRE || connectedType == .AIRPLAY {
            print("⚠️ Skipping startCastSession because active TR_TV is \(String(describing: connectedType))")
            return
        }
        
        if selectedDevice == nil {
            if connectedType == .ANDROID || connectedType == .SAMSUNG {
                if let first = gcastDevice.first {
                    selectedDevice = first
                    print("✅ Auto-selected device:", first.friendlyName ?? "")
                }
            }
        }
        
        guard let device = selectedDevice else {
            print("❌ No Google Cast device to start session with")
            return
        }
        
        startDefaultMediaPlayerSession(with: device)
    }
    
    func castMedia(_ url: URL, mediaType: String, title: String, des: String, mediaURL : URL? = nil) {
        print("castMedia called")
        StopRemoteMediaCleint()
        pendingMediaToCast = (url, mediaType)
        
        if isCastingSessionGoing() {
            executeMediaCasting(url, mediaType: mediaType, title: title, des: des, mediaURL: mediaURL)
        } else {
            startCastSession()
        }
    }
    
    func youtubeCasting(videoId: String) {
        
        guard let remoteMediaClient = GCKCastContext.sharedInstance()
            .sessionManager.currentCastSession?.remoteMediaClient else {
            print("No active cast session")
            startCastSession()
            return
        }
        
        let youtubeURL = "https://www.youtube.com/watch?v=\(videoId)"
        
        let metadata = GCKMediaMetadata(metadataType: .movie)
        metadata.setString("YouTube", forKey: kGCKMetadataKeyTitle)
        
        let mediaInformation = GCKMediaInformation(
            contentID: youtubeURL,
            streamType: .buffered,
            contentType: "video/mp4",
            metadata: metadata,
            streamDuration: 0,
            mediaTracks: nil,
            textTrackStyle: nil,
            customData: nil
        )
        
        let options = GCKMediaLoadOptions()
        options.autoplay = true
        
        remoteMediaClient.loadMedia(mediaInformation, with: options)
        
        print("Casting YouTube video: \(videoId)")
    }
    
    private func executeMediaCasting(_ url: URL, mediaType: String, title: String, des: String,mediaURL : URL? = nil) {
            guard let remoteMediaClient = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient else {
                print("executeMediaCasting: No cast session found.")
                startCastSession()
                return
            }
    
            let isAudio = mediaType.contains("audio")
            let isPhoto = mediaType.contains("image")
            let isHLS = mediaType.contains("mpegurl") || mediaType.contains("m3u8") || url.absoluteString.lowercased().contains(".m3u8") || url.absoluteString.lowercased().contains("m3u8")
    
            if let mediaStatus = remoteMediaClient.mediaStatus, mediaStatus.playerState == .playing, !isPhoto {
                print("executeMediaCasting: Stopping previous video/audio before casting new media...")
                remoteMediaClient.stop()
            }
    
            print("executeMediaCasting: Casting media...")
            
            let metaData: GCKMediaMetadata
            if isPhoto {
                metaData = GCKMediaMetadata(metadataType: .photo)
                metaData.setString(title, forKey: kGCKMetadataKeyTitle)
                metaData.setString(des, forKey: kGCKMetadataKeySubtitle)
                metaData.addImage(GCKImage(url: url, width: 1920, height: 1080))
            } else if isAudio {
                metaData = GCKMediaMetadata(metadataType: .musicTrack)
                metaData.setString(title, forKey: kGCKMetadataKeyTitle)
                metaData.setString(des, forKey: kGCKMetadataKeyArtist)
                metaData.setString(des, forKey: kGCKMetadataKeyAlbumTitle)
                if let imgURL = mediaURL {
                    metaData.addImage(GCKImage(url: imgURL, width: 1024, height: 1024))
                }
            } else {
                metaData = GCKMediaMetadata(metadataType: isHLS ? .tvShow : .movie)
                metaData.setString(title, forKey: kGCKMetadataKeyTitle)
                metaData.setString(des, forKey: kGCKMetadataKeySubtitle)
                if let imgURL = mediaURL {
                    metaData.addImage(GCKImage(url: imgURL, width: 1024, height: 1024))
                }
            }
            
            let streamType: GCKMediaStreamType = isPhoto ? .none : (isHLS ? .live : .buffered)
            let effectiveContentType: String = isHLS ? "application/x-mpegURL" : mediaType
            
            let mediaInformation = GCKMediaInformation(
                contentID: url.absoluteString,
                streamType: streamType,
                contentType: effectiveContentType,
                metadata: metaData,
                streamDuration: isHLS ? 0 : 0,
                mediaTracks: nil,
                textTrackStyle: nil,
                customData: nil
            )

            let mediaLoadOptions = GCKMediaLoadOptions()
            mediaLoadOptions.autoplay = true

            remoteMediaClient.loadMedia(mediaInformation, with: mediaLoadOptions)

            DispatchQueue.main.async {
                self.isCastingInProgress = false
                print("executeMediaCasting: isCastingInProgress set to false")
            }
        }
    
    
    func seekMedia(to time: Float) {
        guard !time.isNaN && !time.isInfinite && time >= 0 else { return }
        guard let remoteMediaClient = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient else {
            print("❌ GCK seekMedia: No active remoteMediaClient found")
            return
        }
        
        let mediaSeekOptions = GCKMediaSeekOptions()
        mediaSeekOptions.interval = TimeInterval(max(0, time))
        mediaSeekOptions.resumeState = .play
        remoteMediaClient.seek(with: mediaSeekOptions)
        print("📺 GCK Cast seeked successfully to \(time)s")
    }
    
    // MARK: - GCKDiscoveryManagerListener
    
    func didUpdateDeviceList() {
        guard let discoveryManager = discoveryManager else { return }
        DispatchQueue.main.async {
            gcastDevice = (0..<discoveryManager.deviceCount).compactMap { discoveryManager.device(at: $0) }
            print("Google Cast TR_TV : \(gcastDevice)")
            gcastDevice.forEach {
                print("Google Cast TR_TV List update  : \($0.friendlyName ?? "")")
                
            }
        }
    }
    
    func didAddDevice(_ device: GCKDevice) {
        DispatchQueue.main.async {
            if !gcastDevice.contains(device) {
                gcastDevice.append(device)
                print("Google Cast TR_TV : \(gcastDevice)")
            }
            
            // Bridge directly into TR_RemoteViewModel for instant Smart TR_TV Sheet display
            let friendlyName = device.friendlyName ?? device.modelName ?? "Google TR_TV"
            let ip = device.ipAddress
            if !ip.isEmpty, isStrictlySmartTV(name: friendlyName) {
                if let desc = ServiceDescription(address: ip, uuid: "gcast-\(device.deviceID)") {
                    desc.friendlyName = friendlyName
                    desc.modelName = device.modelName ?? "Google TR_TV"
                    desc.serviceId = "DIALService"
                    desc.device = device
                    if let connectable = ConnectableDevice(description: desc) {
                        if !TR_RemoteViewModel.shared.discoveredDevices.contains(where: { $0.address == ip || $0.friendlyName == friendlyName }) {
                            TR_RemoteViewModel.shared.discoveredDevices.append(connectable)
                            DeviceConnectionManager.shared.syncDevice(from: connectable)
                            print("⚡ Instantly added Cast TR_TV to TR_RemoteViewModel: \(friendlyName) (\(ip))")
                        }
                    }
                }
            }
        }
    }
    
    func didRemoveDevice(_ device: GCKDevice) {
        DispatchQueue.main.async {
            gcastDevice.removeAll { $0 == device }
            print("Google Cast TR_TV : \(gcastDevice)")
        }
    }
    
    @MainActor private func attemptCastingPendingMedia(_ pendingMedia: (url: URL, mediaType: String), retries: Int, delay: TimeInterval, title: String, des: String) {
        guard retries > 0 else {
            print("executeMediaCasting: failed after retries, remoteMediaClient not ready -> Fallback to ConnectSDK ❌")
            TR_DeviceConnectivityViewModel.shared.connectSDKDiscoveryModel.sendMediaToLGTV(
                mediaUrl: pendingMedia.url,
                mimeType: pendingMedia.mediaType,
                title: title,
                des: des,
                imgHei: 1080,
                imgWid: 1920
            )
            self.pendingMediaToCast = nil
            return
        }
        
        if let remoteMediaClient = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient {
            print("executeMediaCasting: remoteMediaClient ready, casting ✅")
            self.executeMediaCasting(pendingMedia.url, mediaType: pendingMedia.mediaType, title: title, des: des)
            self.pendingMediaToCast = nil
        } else {
            print("executeMediaCasting: remoteMediaClient not ready, retrying...")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.attemptCastingPendingMedia(pendingMedia, retries: retries - 1, delay: delay, title: title, des: des)
            }
        }
    }
    
}

extension TR_TVStreamingViewModel: GCKLoggerDelegate {
    func logMessage(_ message: String, fromFunction function: String, location: String) {
        print("\(location): \(function) - \(message)")
    }
}


extension TR_TVStreamingViewModel: GCKSessionManagerListener {
    @MainActor func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKSession) {
        let appID = (session as? GCKCastSession)?.applicationMetadata?.applicationID
        print("TR_TVStreamingViewModel sessionManager: didStart session with app: \(appID ?? "nil")")
        self.isConnected = true
        self.isCastingInProgress = false
        
        // Only attempt casting media if this is the Default Media Receiver session
        if appID != TR_AppStrings.kCustomReceiverAppID {
            guard let pendingMedia = self.pendingMediaToCast else {
                print("sessionManager: no pending media to cast")
                return
            }
            attemptCastingPendingMedia(pendingMedia, retries: 5, delay: 0.8, title: TR_AppStrings.appName, des: "")
        }
    }
    
    @MainActor func sessionManager(_ sessionManager: GCKSessionManager, didResume session: GCKSession) {
        print("TR_TVStreamingViewModel sessionManager: didResume session")
        self.isConnected = true
        self.isCastingInProgress = false
    }
    
    @MainActor func sessionManager(_ sessionManager: GCKSessionManager, didFailToStart session: GCKSession, withError error: Error) {
        print("Failed to start session: \(error.localizedDescription) -> Fallback to ConnectSDK")
        self.isConnected = false
        self.isCastingInProgress = false
        if let pending = self.pendingMediaToCast {
            TR_DeviceConnectivityViewModel.shared.connectSDKDiscoveryModel.sendMediaToLGTV(
                mediaUrl: pending.url,
                mimeType: pending.mediaType,
                title: TR_AppStrings.appName,
                des: "",
                imgHei: 1080,
                imgWid: 1920
            )
            self.pendingMediaToCast = nil
        }
    }
    
    func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKSession, withError error: Error?) {
        print("Session ended: \(error?.localizedDescription ?? "No error")")
        DispatchQueue.main.async {
            self.isConnected = false
            self.isCastingInProgress = false
        }
    }
}

