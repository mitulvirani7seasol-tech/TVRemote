//
//  CastImageManager.swift
//  KaiRemote
//
//  Created by Parthiv Akbari on 04/06/26.
//

import Foundation
import UIKit
import AVFoundation
import SwiftUI
import AVKit
import Combine
import Photos

struct TR_VideoPlayerViewController: UIViewControllerRepresentable {
    let videoURL: URL
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let playerVC = AVPlayerViewController()
        let player = AVPlayer(url: videoURL)
        playerVC.player = player
        player.play()
        return playerVC
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

// MARK: - AirPlay Manager

final class TR_ImageCastAirPlayManager: NSObject, ObservableObject {
    static let shared = TR_ImageCastAirPlayManager()
    
    @Published var isCasting: Bool = false
    @Published var isPlayerPresented: Bool = false
    
    private var player: AVPlayer?
    private var playerViewController: AVPlayerViewController?
    private var endObserver: Any?
    
    // MARK: - Play PHAsset as AirPlay image
    func playPHAssetImage(_ asset: PHAsset) {
        DispatchQueue.main.async {
            self.isCasting = true
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        
        let smAirPlayTargetDimensions = CGSize(width: 1920, height: 1920)
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: smAirPlayTargetDimensions,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] image, info in
            guard let self = self else { return }
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if isDegraded { return }
            guard let newImage = image else {
                DispatchQueue.main.async {
                    self.isCasting = false
                }
                return
            }
            DispatchQueue.main.async {
                self.castImageDirectlyToAirPlay(image: newImage)
            }
        }
    }
    
    func playUIImageImage(_ image: UIImage) {
        DispatchQueue.main.async {
            self.isCasting = true
        }
        self.castImageDirectlyToAirPlay(image: image)
    }
    
    // MARK: - Convert image → video → upload → play
    private func castImageDirectlyToAirPlay(image: UIImage) {
        DispatchQueue.main.async {
            self.isCasting = true
        }
        
        let imageURL = saveImageToTemp(image: image)
        TR_ImageToVideoConverter.convertImageToVideo(imageURL: imageURL) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let videoURL):
                self.prepareVideoForHTTPServer(localVideoURL: videoURL)
            case .failure(let error):
                print("❌ Conversion error: \(error)")
                DispatchQueue.main.async {
                    self.isCasting = false
                }
            }
        }
    }
    
    private func saveImageToTemp(image: UIImage) -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: tempURL)
        }
        return tempURL
    }
    
    private func prepareVideoForHTTPServer(localVideoURL: URL) {
        if TR_CastingServerManager.shared.effectiveServerURL == nil {
            TR_CastingServerManager.shared.setupServer()
        }
        
        TR_CastingServerManager.shared.setLocalVideoToServe(localVideoURL.path)
        
        guard let baseURL = TR_CastingServerManager.shared.effectiveServerURL ?? TR_CastingServerManager.shared.serverURL else {
            print("❌ Server URL not ready for AirPlay image")
            DispatchQueue.main.async {
                self.isCasting = false
            }
            return
        }
        
        let cacheBuster = UUID().uuidString
        let httpVideoURL = baseURL.appendingPathComponent("localvideo/\(cacheBuster).mp4")
        
        DispatchQueue.main.async {
            self.startPlayback(url: httpVideoURL)
        }
    }
    
    private func startPlayback(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        
        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        
        // Loop playback when reaching end so image stays on TR_TV
        let loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
        self.endObserver = loopObserver
        
        if let player = self.player,
           let playerVC = self.playerViewController,
           playerVC.presentingViewController != nil {
            
            player.replaceCurrentItem(with: playerItem)
            player.play()
            self.isCasting = false
            self.isPlayerPresented = true
            return
        }
        
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.allowsExternalPlayback = true
        newPlayer.usesExternalPlaybackWhileExternalScreenIsActive = true
        newPlayer.audiovisualBackgroundPlaybackPolicy = .automatic
        
        self.player = newPlayer
        
        let playerVC = AVPlayerViewController()
        playerVC.modalPresentationStyle = .fullScreen
        playerVC.player = newPlayer
        playerVC.allowsPictureInPicturePlayback = false
        playerVC.updatesNowPlayingInfoCenter = false
        self.playerViewController = playerVC
        
        configurePlayerForAirPlay()
        
        guard let topVC = UIApplication.shared.keyWindowPresentedController else {
            print("❌ Unable to find top view controller")
            self.isCasting = false
            return
        }
        
        topVC.present(playerVC, animated: true) { [weak self, weak newPlayer] in
            newPlayer?.play()
            self?.isCasting = false
            self?.isPlayerPresented = true
        }
    }
    
    private func configurePlayerForAirPlay() {
        guard let player = player else { return }
        
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        player.audiovisualBackgroundPlaybackPolicy = .automatic
        
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
            stopPlayback()
        case .newDeviceAvailable:
            print("AirPlay device connected.")
        default:
            break
        }
    }
    
    func stopPlayback() {
        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        if let playerVC = playerViewController, playerVC.presentingViewController != nil {
            playerVC.dismiss(animated: true)
        }
        playerViewController = nil
        isPlayerPresented = false
        isCasting = false
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
    }
}

extension UIApplication {
    var keyWindowPresentedController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?
            .presentedController
    }
}

extension UIViewController {
    var presentedController: UIViewController {
        if let presented = self.presentedViewController {
            return presented.presentedController
        }
        return self
    }
}
