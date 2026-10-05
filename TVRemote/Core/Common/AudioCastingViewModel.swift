//
//  AudioCastingViewModel.swift
//  TV Remote
//
//  Created by Himanshu Parmar on 20/08/26.
//

import Foundation
import SwiftUI
import AVFAudio
import MediaPlayer
import AVFoundation
import Combine

struct MusicItem: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let size: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let assetURL: URL?
    let artwork: UIImage?
    let mediaItem: MPMediaItem?

    var durationString: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Equatable & Hashable
    static func == (lhs: MusicItem, rhs: MusicItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
class AudioCastingViewModel: NSObject, ObservableObject {
    static let shared = AudioCastingViewModel()
    
    // MARK: - Published Properties
    @Published var songs: [MusicItem] = []
    @Published var playlistMusics: [MusicItem] = []
    @Published var favorites: [MusicItem] = []
    @Published var currentlyPlaying: MusicItem?
    @Published var isPlaying = false
    @Published var isShuffled = false
    @Published var isRepeat = false
    @Published var refreshID = UUID()
    @Published var currentIndex: Int = 0
    @Published var playbackProgress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var isLoadings = false
    @Published var musicPermissionDenied = false
    @Published var showAlreadyExistsAlert = false
    @Published var alreadyExistsMessage: String = ""

    private var originalSongs: [MusicItem] = []
    private var shuffledSongs: [MusicItem] = []
    @Published var favoriteIDs: Set<String> = []

    var favoriteSongs: [MusicItem] {
        songs.filter { favoriteIDs.contains($0.id) }
    }

    func toggleFavorite(_ item: MusicItem) {
        if favoriteIDs.contains(item.id) {
            favoriteIDs.remove(item.id)
        } else {
            favoriteIDs.insert(item.id)
        }
    }

    // MARK: - New Music Player
    private lazy var musicPlayer = MPMusicPlayerController.applicationMusicPlayer
    private var isMusicPlayerSetup = false
    private var progressTimer: Timer?

    override init() {
        super.init()
        setupMediaLibraryObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        progressTimer?.invalidate()
    }

    // MARK: - Setup
    private func setupMusicPlayerIfNeeded() {
        guard !isMusicPlayerSetup else { return }
        isMusicPlayerSetup = true
        musicPlayer.beginGeneratingPlaybackNotifications()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStateDidChange),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayer
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingItemDidChange),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: musicPlayer
        )

        print("✅ Music player setup complete")
    }

    private func setupMediaLibraryObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mediaLibraryDidChange),
            name: .MPMediaLibraryDidChange,
            object: nil
        )
    }

    @objc private func mediaLibraryDidChange() {
        print("📀 Media library changed — refetching songs")
        fetchSongs()
    }

    // MARK: - Authorization & Fetch
    func requestMusicAccessAndFetch() {
        let currentStatus = MPMediaLibrary.authorizationStatus()

        // Already authorized - Direct fetch like ScreenNova
        if currentStatus == .authorized {
            self.musicPermissionDenied = false
            if self.songs.isEmpty {
                self.fetchSongs()
            }
            return
        }

        self.isLoadings = true
        MPMediaLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch status {
                case .authorized:
                    self.musicPermissionDenied = false
                    self.isLoadings = true
                    MPMediaLibrary.default().beginGeneratingLibraryChangeNotifications()

                    // Small delay so library becomes available instantly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.fetchSongs()
                    }

                case .denied, .restricted:
                    self.musicPermissionDenied = true
                    self.songs = []
                    self.isLoadings = false

                case .notDetermined:
                    break

                @unknown default:
                    self.musicPermissionDenied = true
                    self.isLoadings = false
                }
            }
        }
    }

    // Import audio files selected from native iOS Files App
    func importAudioFiles(from urls: [URL]) {
        self.isLoadings = true
        let currentSongs = self.songs
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fileManager = FileManager.default
            guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                Task { @MainActor in
                    self.isLoadings = false
                }
                return
            }
            
            var duplicateFound = false
            var duplicateNames: [String] = []
            var newFilesCopied = false
            
            for url in urls {
                let shouldStopAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if shouldStopAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                let smAudioFileName = url.lastPathComponent
                let cleanFileName = url.deletingPathExtension().lastPathComponent
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                
                let destURL = docsURL.appendingPathComponent(smAudioFileName)
                
                // 1. Check if file already exists in app Documents directory
                let fileExistsInDocs = fileManager.fileExists(atPath: destURL.path)
                
                // 2. Check if song already exists in current songs list (by filename or title)
                let existsInSongsList = currentSongs.contains { song in
                    let songTitle = song.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let songFileName = song.assetURL?.lastPathComponent.lowercased() ?? ""
                    return songTitle == cleanFileName || songFileName == smAudioFileName.lowercased()
                }
                
                if fileExistsInDocs || existsInSongsList {
                    duplicateFound = true
                    duplicateNames.append(url.deletingPathExtension().lastPathComponent)
                    continue
                }
                
                do {
                    try fileManager.copyItem(at: url, to: destURL)
                    newFilesCopied = true
                } catch {
                    print("❌ Error copying audio file: \(error.localizedDescription)")
                }
            }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if newFilesCopied {
                    self.fetchSongs()
                } else {
                    self.isLoadings = false
                }
                
                if duplicateFound {
                    // Small delay to allow the document picker sheet to dismiss cleanly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        if duplicateNames.count == 1 {
                            self.alreadyExistsMessage = "\"\(duplicateNames[0])\" \(TR_LanguageManager.shared.localized("audio_already_exists"))"
                        } else {
                            self.alreadyExistsMessage = TR_LanguageManager.shared.localized("audio_already_exists")
                        }
                        self.showAlreadyExistsAlert = true
                    }
                }
            }
        }
    }

    // MARK: - Format Time
    var currentTimeString: String {
        let minutes = Int(currentTime) / 60
        let seconds = Int(currentTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Shuffle / Repeat
    func toggleShuffle() {
        isShuffled.toggle()
        if isShuffled {
            shuffledSongs = playlistMusics.shuffled()
            if let current = currentlyPlaying,
               let index = shuffledSongs.firstIndex(where: { $0.id == current.id }) {
                currentIndex = index
            } else { currentIndex = 0 }
            print("🔀 Shuffle enabled")
        } else {
            if let current = currentlyPlaying,
               let index = originalSongs.firstIndex(where: { $0.id == current.id }) {
                currentIndex = index
            } else { currentIndex = 0 }
            print("🔀 Shuffle disabled")
        }
        refreshID = UUID()
    }

    func toggleRepeat() {
        isRepeat.toggle()
        musicPlayer.repeatMode = isRepeat ? .one : .none
        print("🔁 Repeat \(isRepeat ? "enabled" : "disabled")")
    }

    // MARK: - Set Playlist
    func setMusics(_ musics: [MusicItem], startIndex: Int) {
        self.originalSongs = musics
        self.playlistMusics = musics
        self.currentIndex = startIndex
        playAtCurrentIndex()
    }

    private func playAtCurrentIndex() {
        let currentQueue = isShuffled ? shuffledSongs : playlistMusics
        guard currentQueue.indices.contains(currentIndex) else { return }
        play(song: currentQueue[currentIndex])
    }

    // MARK: - Fetch Songs
    func fetchSongs() {
        self.isLoadings = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var fetchedSongs: [MusicItem] = []
            
            // 1. Fetch from MPMediaQuery (Music Library) ONLY if authorized
            if MPMediaLibrary.authorizationStatus() == .authorized {
                let mediaQuery = MPMediaQuery.songs()
                if let items = mediaQuery.items, !items.isEmpty {
                    fetchedSongs = items.compactMap { item -> MusicItem? in
                        guard let title = item.title else {
                            return nil
                        }

                        let sizeString = Self.extractFileSize(from: item)
                        var artwork = item.artwork?.image(at: CGSize(width: 600, height: 600))
                        
                        if artwork == nil, let url = item.assetURL {
                            let asset = AVURLAsset(url: url)
                            for meta in asset.commonMetadata {
                                if meta.commonKey == .commonKeyArtwork, let data = meta.dataValue, let img = UIImage(data: data) {
                                    artwork = img
                                    break
                                }
                            }
                        }
                        
                        return MusicItem(
                            id: "\(item.persistentID)",
                            title: title,
                            size: sizeString,
                            artist: item.artist ?? "Unknown Artist",
                            album: item.albumTitle ?? "Unknown Album",
                            duration: item.playbackDuration,
                            assetURL: item.assetURL,
                            artwork: artwork,
                            mediaItem: item
                        )
                    }
                }
            }
            
            // 2. Also fetch any .mp3 audio files from device Files directory
            let diskSongs = FileManagerAudioService.shared.fetchAudioFilesFromDisk()
            for fileSong in diskSongs {
                if !fetchedSongs.contains(where: { $0.id == fileSong.id || $0.title == fileSong.title }) {
                    fetchedSongs.append(fileSong)
                }
            }
            
            let sortedSongs = fetchedSongs.sorted { $0.title < $1.title }

            DispatchQueue.main.async {
                self.originalSongs = sortedSongs
                self.songs = sortedSongs
                self.playlistMusics = sortedSongs
                self.isLoadings = false
                print("🎵 Loaded \(sortedSongs.count) songs")
            }
        }
    }

    // MARK: - Playback Controls
    func play(song: MusicItem) {
        guard let mediaItem = song.mediaItem else {
            print("❌ No MPMediaItem for \(song.title)")
            return
        }

        setupMusicPlayerIfNeeded()
        musicPlayer.setQueue(with: MPMediaItemCollection(items: [mediaItem]))
        musicPlayer.play()
        currentlyPlaying = song
        isPlaying = true
        startProgressTimer()
        print("▶️ Playing: \(song.title)")
    }

    func playNext() {
        let currentQueue = isShuffled ? shuffledSongs : playlistMusics
        guard !currentQueue.isEmpty else { return }

        if isRepeat {
            playAtCurrentIndex()
        } else {
            currentIndex = (currentIndex + 1) % currentQueue.count
            playAtCurrentIndex()
        }
    }

    func playPrevious() {
        let currentQueue = isShuffled ? shuffledSongs : playlistMusics
        guard !currentQueue.isEmpty else { return }
        currentIndex = (currentIndex - 1 + currentQueue.count) % currentQueue.count
        playAtCurrentIndex()
    }

    func pause() {
        musicPlayer.pause()
        isPlaying = false
        stopProgressTimer()
        print("⏸️ Paused")
    }

    func resume() {
        musicPlayer.play()
        isPlaying = true
        startProgressTimer()
        print("▶️ Resumed")
    }

    func stop() {
        musicPlayer.stop()
        isPlaying = false
        currentlyPlaying = nil
        playbackProgress = 0
        currentTime = 0
        stopProgressTimer()
        print("⏹️ Stopped")
    }

    func seek(to progress: Double) {
        guard let item = musicPlayer.nowPlayingItem else { return }
        let newTime = progress * item.playbackDuration
        musicPlayer.currentPlaybackTime = newTime
        currentTime = newTime
        playbackProgress = progress
    }

    func togglePlayPause(for song: MusicItem) {
        if currentlyPlaying?.id == song.id {
            if isPlaying {
                pause()
            } else {
                resume()
            }
        } else {
            play(song: song)
        }
    }

    // MARK: - Timer for progress
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateProgress()
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        guard let item = musicPlayer.nowPlayingItem else { return }
        currentTime = musicPlayer.currentPlaybackTime
        playbackProgress = item.playbackDuration > 0
        ? currentTime / item.playbackDuration
        : 0
    }

    // MARK: - Notifications
    @objc private func playbackStateDidChange() {
        switch musicPlayer.playbackState {
        case .playing:
            isPlaying = true
            startProgressTimer()
        case .paused, .stopped, .interrupted:
            isPlaying = false
            stopProgressTimer()
        default:
            break
        }
    }

    @objc private func nowPlayingItemDidChange() {
        if let currentItem = musicPlayer.nowPlayingItem {
            currentlyPlaying = songs.first { $0.title == currentItem.title }
        } else {
            currentlyPlaying = nil
        }
    }

    // MARK: - File Size
    private nonisolated static func extractFileSize(from item: MPMediaItem) -> String {
        guard let assetURL = item.assetURL else {
            return "Unknown"
        }

        do {
            let values = try assetURL.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = values.fileSize {
                let mbSize = Double(fileSize) / (1024 * 1024)
                return String(format: "%.1f MB", mbSize)
            }
        } catch {
            print(error.localizedDescription)
        }

        return "Unknown"
    }

    // MARK: - Open Settings
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
