//
//  CastAudioManager.swift
//  TV Remote
//

import Foundation
import UIKit
import AVFoundation
import AVKit
import Combine
import MediaPlayer

final class CastAudioPlayerManager: NSObject, ObservableObject {
    static let shared = CastAudioPlayerManager()
    
    @Published var isCasting: Bool = false
    @Published var isPlayerPresented: Bool = false
    
    private var player: AVPlayer?
    private var playerViewController: AVPlayerViewController?
    
    func playMusicItem(_ track: MusicItem) {
        DispatchQueue.main.async {
            self.isCasting = true
        }
        
        let artworkImage = track.artwork ?? track.mediaItem?.artwork?.image(at: CGSize(width: 1080, height: 1080)) ?? UIImage(named: "img_empty_music") ?? UIImage(systemName: "music.note") ?? UIImage()
        
        if let assetURL = track.assetURL {
            self.prepareAudioForPlayback(audioURL: assetURL, artwork: artworkImage, track: track)
        } else if let mediaItem = track.mediaItem, let assetURL = mediaItem.assetURL {
            self.prepareAudioForPlayback(audioURL: assetURL, artwork: artworkImage, track: track)
        } else {
            // Fallback: convert artwork image into video
            let tempImageURL = TR_ImageToVideoConverter.saveImageToTemp(image: artworkImage)
            TR_ImageToVideoConverter.convertImageToVideo(imageURL: tempImageURL) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let videoURL):
                    DispatchQueue.main.async {
                        self.startPlayback(url: videoURL, track: track, artwork: artworkImage)
                    }
                case .failure(let error):
                    print("❌ Audio poster conversion error: \(error)")
                    DispatchQueue.main.async {
                        self.isCasting = false
                    }
                }
            }
        }
    }
    
    private func prepareAudioForPlayback(audioURL: URL, artwork: UIImage, track: MusicItem) {
        TR_CastingServerManager.shared.setLocalVideoToServe(audioURL.path)
        
        guard let baseURL = TR_CastingServerManager.shared.serverURL ?? TR_CastingServerManager.shared.effectiveServerURL else {
            self.startPlayback(url: audioURL, track: track, artwork: artwork)
            return
        }
        
        let cacheBuster = UUID().uuidString
        let ext = audioURL.pathExtension.isEmpty ? "mp3" : audioURL.pathExtension
        let httpAudioURL = baseURL.appendingPathComponent("localvideo/\(cacheBuster).\(ext)")
        
        self.startPlayback(url: httpAudioURL, track: track, artwork: artwork)
    }
    
    private func startPlayback(url: URL, track: MusicItem, artwork: UIImage) {
        let playerItem = AVPlayerItem(url: url)
        setupPlayerItemMetadata(playerItem: playerItem, track: track, artwork: artwork)
        
        let newPlayer = AVPlayer(playerItem: playerItem)
        self.player = newPlayer
        
        let playerVC = AVPlayerViewController()
        playerVC.modalPresentationStyle = .fullScreen
        playerVC.player = newPlayer
        playerVC.allowsPictureInPicturePlayback = false
        playerVC.updatesNowPlayingInfoCenter = true
        self.playerViewController = playerVC
        
        configurePlayerForAirPlay()
        
        if let topVC = UIApplication.shared.keyWindowPresentedController {
            topVC.present(playerVC, animated: true) {
                DispatchQueue.main.async {
                    self.isCasting = false
                    self.isPlayerPresented = true
                }
                newPlayer.play()
            }
        } else {
            DispatchQueue.main.async {
                self.isCasting = false
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
        
        if let data = artwork.jpegData(compressionQuality: 0.9) {
            let artworkItem = AVMutableMetadataItem()
            artworkItem.identifier = .commonIdentifierArtwork
            artworkItem.key = AVMetadataKey.commonKeyArtwork as (NSCopying & NSObjectProtocol)?
            artworkItem.keySpace = .common
            artworkItem.value = data as NSData
            artworkItem.dataType = kCMMetadataBaseDataType_JPEG as String
            artworkItem.extendedLanguageTag = "und"
            metadata.append(artworkItem)
        }
        
        playerItem.externalMetadata = metadata
    }
    
    private func configurePlayerForAirPlay() {
        guard let player = player else { return }
        
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        player.audiovisualBackgroundPlaybackPolicy = .automatic
        
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    func stopPlayback() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerViewController = nil
        isPlayerPresented = false
        isCasting = false
    }
}
