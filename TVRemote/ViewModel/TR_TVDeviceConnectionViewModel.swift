//
//  ConnectSDKVM.swift
//  TV Remote
//

import Foundation
import Combine
import ConnectSDK
import UIKit

struct TR_CastDetail {
    var titleStr: String
    var subtitleStr: String
    var image: URL
}

class TR_TVDeviceConnectionViewModel: NSObject, ObservableObject {
    var discoveryManager: DiscoveryManager
    private var launchObject: MediaLaunchObject?
    private var launcher: Launcher!
    
    @Published var lgDevices: [ConnectableDevice] = []
    @Published var isConnectedToLG: Bool = false
    @Published var selectedLGDevice: ConnectableDevice? = nil
    @Published var showVideoControls: Bool = true
    let groupId = TR_AppStrings.groupID
    var superVC: UIViewController?
    var isShowPopup: Bool = false
    var onStartVideo: (() -> Void)?
    let SELECTED_TV = "SELECTED_TV"

    var castDetail: TR_CastDetail?
    
    @Published var deviceIpAddress: String? {
        didSet {
            TR_UserDefaultManager.shared.saveStandard(deviceIpAddress, forKey: TR_AppStrings.deviceIPKey)
        }
    }
    
    override init() {
        discoveryManager = DiscoveryManager.shared()
        super.init()
        
        if let savedIpAddress: String = TR_UserDefaultManager.shared.getStandard(forKey: TR_AppStrings.deviceIPKey) {
            self.deviceIpAddress = savedIpAddress
        }
    }
    
    // MARK: - Discovery Setup
    func stopDiscovery() {
        discoveryManager.stopDiscovery()
    }
    
    func connectToLGDevice(at index: Int) {
        guard lgDevices.indices.contains(index) else { return }
        let device = lgDevices[index]
        device.setPairingType(DeviceServicePairingTypePinCode)
        device.delegate = self
        device.connect()
        
        print("Connecting to LG device: \(device.friendlyName ?? "Unknown LG TR_Device")")
        
        if let ipAddress = device.address {
            self.deviceIpAddress = ipAddress
            print("TR_Device IP Address: \(ipAddress)")
            
            TR_UserDefaultManager.shared.saveShared(ipAddress, forKey: "ConnectedDeviceIP")
            print("IP Address saved to shared defaults: \(ipAddress)")
        }
    }
    
    func disconnectLGDevice() {
        selectedLGDevice?.disconnect()
        selectedLGDevice = nil
        isConnectedToLG = false
    }
    
    func LGMirroring(mediaURL: URL) {
        print("lg mirror \(mediaURL)")
        TR_SilentAudioManager.shared.start()
        if selectedLGDevice?.launcher() != nil {
            selectedLGDevice?.launcher().launchBrowser(mediaURL, success: { launchSession in
                print("Browser successfully launched.")
            }, failure: { error in
                if let error = error {
                    print("Failed to launch the browser: \(error.localizedDescription)")
                }
            })
        } else {
            print("Browser nil")
        }
    }
    
    @MainActor func getActiveLGDevice() -> ConnectableDevice? {
        if let dev = selectedLGDevice, dev.connected {
            return dev
        }
        if let dev = DeviceConnectionManager.shared.connectedDevice?.connectableDevice {
            selectedLGDevice = dev
            if !dev.connected { dev.connect() }
            return dev
        }
        if let lgMan = TR_RemoteViewModel.shared.currentTVManager as? TR_LGControlManager, let dev = lgMan.selectedDevice {
            selectedLGDevice = dev
            if !dev.connected { dev.connect() }
            return dev
        }
        if let dev = selectedLGDevice {
            if !dev.connected { dev.connect() }
            return dev
        }
        if let match = TR_RemoteViewModel.shared.discoveredDevices.first(where: { $0.connected }) ?? TR_RemoteViewModel.shared.discoveredDevices.first {
            selectedLGDevice = match
            if !match.connected { match.connect() }
            return match
        }
        return nil
    }
    
    @MainActor func sendMediaToLGTVWeb(mediaUrl: URL) {
        var finalURL = mediaUrl
        let urlStr = mediaUrl.absoluteString
        if urlStr.contains("/files/") && (urlStr.hasSuffix(".jpg") || urlStr.hasSuffix(".jpeg") || urlStr.hasSuffix(".png")) {
            if let viewURL = URL(string: urlStr.replacingOccurrences(of: "/files/", with: "/view/")) {
                finalURL = viewURL
            }
        }
        
        let targetDev = getActiveLGDevice()
        if let launcher = targetDev?.launcher() {
            DispatchQueue.main.async {
                launcher.launchBrowser(finalURL, success: { launchSession in
                    print("✅ LG WebOS Browser launched successfully with \(finalURL)")
                }, failure: { error in
                    print("❌ Failed to launch browser via ConnectSDK: \(error?.localizedDescription ?? "unknown error")")
                })
            }
            return
        }
        
        if let lgMan = TR_RemoteViewModel.shared.currentTVManager as? TR_LGControlManager {
            lgMan.launchBrowser(url: finalURL)
        } else {
            print("⚠️ sendMediaToLGTVWeb: no active LG WebOS device found")
        }
    }
    
    @MainActor func sendYouTubeToLGTV(videoID: String, webURL: URL? = nil) {
        let ytWebURL: URL
        if !videoID.isEmpty, let directURL = URL(string: "https://www.youtube.com/watch?v=\(videoID)") {
            ytWebURL = directURL
        } else if let webURL = webURL {
            ytWebURL = webURL
        } else {
            ytWebURL = URL(string: "https://www.youtube.com")!
        }
        
        sendMediaToLGTVWeb(mediaUrl: ytWebURL)
        onStartVideo?()
    }
    
    @MainActor func sendIPTVToLGTV(mediaUrl: URL, title: String) {
        if TR_CastingServerManager.shared.effectiveServerURL == nil {
            TR_CastingServerManager.shared.setupServer()
        }
        
        let targetDev = getActiveLGDevice()
        let encodedStream = mediaUrl.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? mediaUrl.absoluteString
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Live TR_TV"
        
        guard let base = TR_CastingServerManager.shared.effectiveServerURL ?? TR_CastingServerManager.shared.serverURL else {
            if let launcher = targetDev?.launcher() {
                launcher.launchBrowser(mediaUrl, success: nil, failure: nil)
            }
            return
        }
        
        if let playerURL = URL(string: "\(base.absoluteString)player?url=\(encodedStream)&title=\(encodedTitle)") {
            if let launcher = targetDev?.launcher() {
                launcher.launchBrowser(playerURL, success: { _ in
                    print("✅ IPTV Stream playing on LG TR_TV full-screen player: \(playerURL)")
                }, failure: { [weak self] error in
                    print("❌ Failed to launch player on LG TR_TV: \(error?.localizedDescription ?? ""), fallback to raw stream")
                    launcher.launchBrowser(mediaUrl, success: nil, failure: nil)
                })
            } else if let lgMan = TR_RemoteViewModel.shared.currentTVManager as? TR_LGControlManager {
                lgMan.launchBrowser(url: playerURL)
            }
        }
    }
    
    @MainActor func sendMediaToLGTVYT(mediaUrl: URL, mimeType: String) {
        let targetDev = getActiveLGDevice()
        if let launcher = targetDev?.launcher() {
            launcher.launchBrowser(mediaUrl, success: { [weak self] launchSession in
                print("Browser successfully launched.")
                self?.onStartVideo?()
            }, failure: { [weak self] error in
                if let error = error {
                    self?.onStartVideo?()
                    print("Failed to launch the browser: \(error.localizedDescription)")
                }
            })
        } else {
            print("Browser nil")
        }
    }
    
    @MainActor func sendAudioToLGTVWeb(audioUrl: URL, title: String, artist: String, posterURL: URL?) {
        if TR_CastingServerManager.shared.effectiveServerURL == nil {
            TR_CastingServerManager.shared.setupServer()
        }
        
        let encodedAudio = audioUrl.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? audioUrl.absoluteString
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Music"
        let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedPoster = posterURL?.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        guard let base = TR_CastingServerManager.shared.effectiveServerURL ?? TR_CastingServerManager.shared.serverURL else {
            sendMediaToLGTVWeb(mediaUrl: audioUrl)
            return
        }
        
        var comp = URLComponents(url: base.appendingPathComponent("audioplayer"), resolvingAgainstBaseURL: false)
        comp?.queryItems = [
            URLQueryItem(name: "url", value: encodedAudio),
            URLQueryItem(name: "title", value: encodedTitle),
            URLQueryItem(name: "artist", value: encodedArtist),
            URLQueryItem(name: "poster", value: encodedPoster)
        ]
        
        if let playerURL = comp?.url {
            let targetDev = getActiveLGDevice()
            if let launcher = targetDev?.launcher() {
                DispatchQueue.main.async {
                    launcher.launchBrowser(playerURL, success: { [weak self] _ in
                        self?.onStartVideo?()
                        print("✅ Audio player opened on LG TR_TV Browser with poster: \(playerURL)")
                    }, failure: { error in
                        print("❌ Failed to launch audio player browser: \(error?.localizedDescription ?? "")")
                    })
                }
                return
            }
            if let lgMan = TR_RemoteViewModel.shared.currentTVManager as? TR_LGControlManager {
                lgMan.launchBrowser(url: playerURL)
            }
        }
    }
    
    @MainActor func sendMediaToLGTV(mediaUrl: URL, mimeType: String, title: String?, des: String?, imgHei: Int, imgWid: Int, posterURL: URL? = nil) {
        if let userDefaults = UserDefaults(suiteName: TR_AppStrings.groupID) {
            if userDefaults.bool(forKey: "isBroadcasting") == true {
                return
            }
        }
        
        let targetDev = getActiveLGDevice()
        let targetTitle = title ?? TR_AppStrings.appName
        let targetDes = des ?? ""
        
        let lowerMime = mimeType.lowercased()
        let lowerUrl = mediaUrl.absoluteString.lowercased()
        
        // 1. Image Casting
        if lowerMime.contains("image") || lowerUrl.hasSuffix(".jpg") || lowerUrl.hasSuffix(".jpeg") || lowerUrl.hasSuffix(".png") {
            let imgMime = (lowerMime.contains("png") || lowerUrl.hasSuffix(".png")) ? "image/png" : "image/jpeg"
            let mediaInfo = MediaInfo(url: mediaUrl, mimeType: imgMime)
            mediaInfo?.title = targetTitle
            mediaInfo?.description = targetDes
            let imageInfo = ImageInfo(url: mediaUrl, type: .min)
            imageInfo?.height = imgHei > 0 ? imgHei : 1080
            imageInfo?.width = imgWid > 0 ? imgWid : 1920
            mediaInfo?.addImage(imageInfo)
            
            if let dlnaService = targetDev?.service(withName: "DLNA") as? DLNAService {
                dlnaService.mediaPlayer().displayImage(with: mediaInfo, success: { [weak self] launchSession in
                    self?.launchObject = launchSession
                    print("✅ Image sent to LG TR_TV via DLNA")
                }, failure: { [weak self] error in
                    print("⚠️ DLNA image failed: \(error?.localizedDescription ?? "unknown"), fallback to /view/ browser...")
                    self?.sendMediaToLGTVWeb(mediaUrl: mediaUrl)
                })
            } else {
                sendMediaToLGTVWeb(mediaUrl: mediaUrl)
            }
        }
        // 2. Audio Casting
        else if lowerMime.contains("audio") || lowerMime.contains("mp3") || lowerMime.contains("m4a") || lowerMime.contains("wav") || lowerUrl.hasSuffix(".mp3") || lowerUrl.hasSuffix(".m4a") || lowerUrl.hasSuffix(".wav") {
            let effectiveMime = lowerMime.contains("mp3") || lowerMime.contains("mpeg") || lowerUrl.hasSuffix(".mp3") ? "audio/mpeg" : (lowerMime.contains("wav") || lowerUrl.hasSuffix(".wav") ? "audio/wav" : (lowerMime.contains("aac") ? "audio/aac" : "audio/mp4"))
            let mediaInfo = MediaInfo(url: mediaUrl, mimeType: effectiveMime)
            mediaInfo?.title = targetTitle
            mediaInfo?.description = targetDes
            
            if let poster = posterURL {
                let imageInfo = ImageInfo(url: poster, type: .min)
                imageInfo?.height = imgHei > 0 ? imgHei : 1024
                imageInfo?.width = imgWid > 0 ? imgWid : 1024
                mediaInfo?.addImage(imageInfo)
            }
            
            if let dlnaService = targetDev?.service(withName: "DLNA") as? DLNAService {
                dlnaService.mediaPlayer().playMedia(with: mediaInfo, shouldLoop: false, success: { [weak self] launchSession in
                    self?.launchObject = launchSession
                    print("✅ Audio playing on LG TR_TV via DLNA with poster: \(posterURL?.absoluteString ?? "none")")
                }, failure: { [weak self] _ in
                    self?.sendAudioToLGTVWeb(audioUrl: mediaUrl, title: targetTitle, artist: targetDes, posterURL: posterURL)
                })
            } else {
                sendAudioToLGTVWeb(audioUrl: mediaUrl, title: targetTitle, artist: targetDes, posterURL: posterURL)
            }
        }
        // 3. IPTV / HLS Online Streams
        else if lowerMime.contains("m3u8") || lowerUrl.contains(".m3u8") || lowerMime.contains("mpegurl") || lowerMime.contains("ts") || lowerUrl.contains(".ts") || targetDes.lowercased().contains("iptv") || targetTitle.lowercased().contains("iptv") {
            sendIPTVToLGTV(mediaUrl: mediaUrl, title: targetTitle)
        }
        // 4. Local / Standard MP4 Video Casting
        else {
            let mediaInfo = MediaInfo(url: mediaUrl, mimeType: "video/mp4")
            mediaInfo?.title = targetTitle
            mediaInfo?.description = targetDes
            if let poster = posterURL {
                let imageInfo = ImageInfo(url: poster, type: .min)
                imageInfo?.height = imgHei > 0 ? imgHei : 1080
                imageInfo?.width = imgWid > 0 ? imgWid : 1920
                mediaInfo?.addImage(imageInfo)
            }
            
            if let dlnaService = targetDev?.service(withName: "DLNA") as? DLNAService {
                dlnaService.mediaPlayer().playMedia(with: mediaInfo, shouldLoop: false, success: { [weak self] launchSession in
                    DispatchQueue.main.async { self?.showVideoControls = true }
                    self?.launchObject = launchSession
                    print("✅ Video playing on LG TR_TV via DLNA")
                }, failure: { [weak self] error in
                    print("⚠️ DLNA video failed: \(error?.localizedDescription ?? "unknown"), routing through HTML5 player...")
                    self?.sendIPTVToLGTV(mediaUrl: mediaUrl, title: targetTitle)
                })
            } else {
                sendIPTVToLGTV(mediaUrl: mediaUrl, title: targetTitle)
            }
        }
    }
    
    func pauseMedia() {
        guard let mediaControl = launchObject?.mediaControl else {
            print("Media control is not available")
            return
        }
        
        mediaControl.pause(success: { _ in
            print("Media paused successfully")
        }, failure: { error in
            print("Failed to pause media: \(error?.localizedDescription ?? "Unknown error")")
        })
    }
    
    func playMedia() {
        guard let mediaControl = launchObject?.mediaControl else {
            print("Media control is not available")
            return
        }
        
        mediaControl.play(success: { _ in
            print("Media resumed successfully")
        }, failure: { error in
            print("Failed to play media: \(error?.localizedDescription ?? "Unknown error")")
        })
    }
    
    @MainActor func seekMedia(to seconds: TimeInterval) {
        var directMediaControl = launchObject?.mediaControl
        if directMediaControl == nil {
            directMediaControl = selectedLGDevice?.mediaControl()
        }
        if directMediaControl == nil {
            directMediaControl = DeviceConnectionManager.shared.connectedDevice?.connectableDevice?.mediaControl()
        }
        
        guard let mediaControl = directMediaControl else {
            print("Media control is not available")
            return
        }
        
        mediaControl.seek(seconds, success: { [weak mediaControl] _ in
            print("Media seeked to \(seconds) seconds successfully")
            mediaControl?.play(success: nil, failure: nil)
        }, failure: { error in
            print("Failed to seek media: \(error?.localizedDescription ?? "Unknown error")")
        })
    }
    
    func disconnectFromTV() {
        guard let mediaSession = launchObject?.session else {
            print("No active session to close during disconnect")
            return
        }
        
        mediaSession.close(success: { _ in
            print("Disconnected and closed media session successfully")
            self.launchObject = nil
        }, failure: { error in
            print("Failed to close media session during disconnect: \(error?.localizedDescription ?? "Unknown error")")
            self.launchObject = nil
        })
    }
    
    func getMediaDuration(completion: @escaping (TimeInterval?) -> Void) {
        guard let mediaControl = launchObject?.mediaControl else {
            print("Media control is not available")
            completion(nil)
            return
        }
        
        mediaControl.getDurationWithSuccess({ duration in
            completion(duration)
        }, failure: { error in
            print("Failed to get media duration: \(error?.localizedDescription ?? "Unknown error")")
            completion(nil)
        })
    }
    
    func getCurrentMediaPosition(completion: @escaping (TimeInterval?) -> Void) {
        guard let mediaControl = launchObject?.mediaControl else {
            print("Media control is not available")
            completion(nil)
            return
        }
        
        mediaControl.getPositionWithSuccess({ position in
            completion(position)
        }, failure: { error in
            print("Failed to get media position: \(error?.localizedDescription ?? "Unknown error")")
            completion(nil)
        })
    }
    
    func stopMediaCasting() {
        TR_SilentAudioManager.shared.stop()
        if let dlnaService = selectedLGDevice?.service(withName: "DLNA") as? DLNAService {
            dlnaService.mediaPlayer().closeMedia(launchObject?.session) { _ in
                print("Media casting stopped successfully")
            } failure: { error in
                print("Failed to stop media casting: \(error?.localizedDescription ?? "Unknown error")")
            }
            
            dlnaService.stop { _ in
                print("Media casting stopped successfully")
            } failure: { error in
                print("Failed to stop media casting: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
        guard let mediaSession = launchObject?.session else {
            print("No active media session to close")
            return
        }
        
        mediaSession.close(success: { _ in
            print("Media casting stopped successfully")
            self.launchObject = nil
        }, failure: { error in
            print("Failed to stop media casting: \(error?.localizedDescription ?? "Unknown error")")
        })
    }
    
    func isMediaPlaying(completion: @escaping (Bool) -> Void) {
        guard let mediaControl = launchObject?.mediaControl else {
            print("Media control is not available")
            completion(false)
            return
        }
        
        mediaControl.getPlayState(success: { playState in
            print("Play state received: \(playState.rawValue)")
            if playState == MediaControlPlayStatePlaying {
                print("Yes, playing video")
                completion(true)
            } else {
                print("Not playing video")
                completion(false)
            }
        }, failure: { error in
            print("Failed to get play state: \(error?.localizedDescription ?? "Unknown error")")
            completion(false)
        })
    }
}

// MARK: - DiscoveryManagerDelegate
extension TR_TVDeviceConnectionViewModel: DiscoveryManagerDelegate {
    func discoveryManager(_ manager: DiscoveryManager, didFind device: ConnectableDevice) {
        DispatchQueue.main.async {
            if !self.lgDevices.contains(where: { $0 == device }) {
                self.lgDevices.append(device)
                print("LG TR_TV : \(self.lgDevices)")
            }
        }
    }
    
    func discoveryManager(_ manager: DiscoveryManager, didLose device: ConnectableDevice) {
        DispatchQueue.main.async {
            self.lgDevices.removeAll { $0 == device }
            print("LG TR_TV : \(self.lgDevices)")
        }
    }
    
    func discoveryManager(_ manager: DiscoveryManager, didUpdate device: ConnectableDevice) {
        DispatchQueue.main.async {
            print("TR_Device updated: \(device.friendlyName ?? "Unknown TR_Device")")
            if !self.lgDevices.contains(where: { $0 == device }) {
                self.lgDevices.append(device)
                print("LG TR_TV : \(self.lgDevices)")
            }
        }
    }
    
    func discoveryManager(_ manager: DiscoveryManager, didFailWithError error: NSError) {
        print("Discovery failed with error: \(error.localizedDescription)")
    }
}

// MARK: - ConnectableDeviceDelegate
extension TR_TVDeviceConnectionViewModel: ConnectableDeviceDelegate {
    func connectableDeviceReady(_ device: ConnectableDevice) {
        DispatchQueue.main.async {
            if self.lgDevices.contains(device) {
                self.selectedLGDevice = device
                self.isConnectedToLG = true
                self.setSelectedTV(name: "LG-\(device.friendlyName ?? "LGTV")")
                selectedTvType = .LG
                print("LG device is ready: \(device.friendlyName ?? "Unknown LG TR_Device")")
            }
        }
    }
    
    func setSelectedTV(name: String) {
        UserDefaults().set(name, forKey: SELECTED_TV)
        UserDefaults().synchronize()
    }
    
    func connectableDeviceDisconnected(_ device: ConnectableDevice, withError error: Error?) {
        DispatchQueue.main.async {
            if device == self.selectedLGDevice {
                self.selectedLGDevice = nil
                self.isConnectedToLG = false
            }
            print("Disconnected from device: \(device.friendlyName ?? "Unknown TR_Device"), error: \(error?.localizedDescription ?? "No error info")")
        }
    }
    
    func connectableDeviceConnectionRequired(_ device: ConnectableDevice!, for service: DeviceService!) {
        print("LG device connectableDeviceConnectionRequired11")
    }
    
    func connectableDeviceConnectionSuccess(_ device: ConnectableDevice!, for service: DeviceService!) {
        print("LG device connectableDeviceConnectionSuccess2")
    }
    
    func connectableDevice(_ device: ConnectableDevice!, service: DeviceService!, disconnectedWithError error: (any Error)!) {
        disConntPairing()
        print("LG device disconnectedWithError- on cancel2")
    }
    
    func connectableDevice(_ device: ConnectableDevice!, service: DeviceService!, pairingRequiredOfType pairingType: Int32, withData pairingData: Any!) {
        print("LG device pairingRequiredOfType")
        disConntPairing()
    }
    
    func deviceService(_ service: DeviceService!, pairingFailedWithError error: (any Error)!) {
        disConntPairing()
        print("LG device pairingFailedWithError")
    }
    
    func disConntPairing() {
        self.selectedLGDevice = nil
        self.isConnectedToLG = false
    }
}
