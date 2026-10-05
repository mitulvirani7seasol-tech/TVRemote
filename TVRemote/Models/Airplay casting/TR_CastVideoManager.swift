//
//  CastVideoManager.swift
//  KaiRemote
//
//  Created by Parthiv Akbari on 04/06/26.
//

import Foundation
import Combine
import AVFoundation
import AVKit
import Photos

final class TR_CastVideoPlayerManager: NSObject, ObservableObject {
    static let shared = TR_CastVideoPlayerManager()
    
    @Published var isCasting: Bool = false
    
    private var player: AVPlayer?
    private var playerViewController: AVPlayerViewController?
    
    func playPHAssetVideo(_ asset: PHAsset) {
        
        DispatchQueue.main.async {
            self.isCasting = true
        }
        
        let options = PHVideoRequestOptions()
        options.version = .original
        options.isNetworkAccessAllowed = true   // ✅ iCloud-only videos ke liye zaroori
        options.deliveryMode = .highQualityFormat
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { [weak self] avAsset, _, _ in
            guard let self else { return }
            
            guard let urlAsset = avAsset as? AVURLAsset else {
                print("Unable to get video URL")
                DispatchQueue.main.async {
                    self.isCasting = false
                }
                return
            }
            
            DispatchQueue.main.async {
                self.prepareVideoForHTTPServer(localVideoURL: urlAsset.url)
            }
        }
    }
    
    // ✅ UPDATED: ab koi copy nahi hota, koi Data(contentsOf:) load nahi hota.
    // Server ko sirf bataya jaata hai ki kaunsi file (jahan hai wahin se) serve karni hai.
    private func prepareVideoForHTTPServer(localVideoURL: URL) {
        
        TR_CastingServerManager.shared.setLocalVideoToServe(localVideoURL.path)
        
        guard let baseURL = TR_CastingServerManager.shared.serverURL else {
            print("❌ Server URL not ready")
            DispatchQueue.main.async {
                self.isCasting = false
            }
            return
        }
        
        // ✅ Cache-buster taaki har naye video ke liye Apple TR_TV/AVPlayer purana cached response na use kare
        let cacheBuster = UUID().uuidString
        let httpVideoURL = baseURL.appendingPathComponent("localvideo/\(cacheBuster).mp4")
        
        DispatchQueue.main.async {
            self.startPlayback(url: httpVideoURL)
        }
    }
    
    private func startPlayback(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        
        let newPlayer = AVPlayer(playerItem: playerItem)
        self.player = newPlayer
        
        let playerVC = AVPlayerViewController()
        playerVC.modalPresentationStyle = .fullScreen
        playerVC.player = newPlayer
        playerVC.allowsPictureInPicturePlayback = false
        playerVC.updatesNowPlayingInfoCenter = false
        self.playerViewController = playerVC
        
        configurePlayerForAirPlay()
        
        if let topVC = UIApplication.shared.keyWindowPresentedController {
            topVC.present(playerVC, animated: true) {
                DispatchQueue.main.async {
                    self.isCasting = false
                }
                newPlayer.play()
            }
        } else {
            DispatchQueue.main.async {
                self.isCasting = false
            }
        }
    }
    
    private func configurePlayerForAirPlay() {
        guard let player = player else { return }
        
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        player.audiovisualBackgroundPlaybackPolicy = .automatic
        
        // 🔥 IMPORTANT: Prevent audio-only fallback
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }
        
        switch reason {
        case .oldDeviceUnavailable:
            print("AirPlay device disconnected.")
        case .newDeviceAvailable:
            print("AirPlay device connected.")
        default:
            break
        }
    }
    
    func stopPlayback() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerViewController = nil
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
    }
}
