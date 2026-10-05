//
//  PhotoGalleryManager.swift
//  TV Remote
//

import SwiftUI
import Photos
import PhotosUI
import MediaPlayer
import AVFoundation
import Combine

// Audio File / Track Model with Embedded Artwork Thumbnail
struct AudioTrackItem: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let durationFormatted: String
    let dateFormatted: String
    let fileSizeFormatted: String
    let url: URL?
    let artwork: UIImage?
    let mediaItem: MPMediaItem?
    
    // Hashable conformance ignoring UIImage direct pointer
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AudioTrackItem, rhs: AudioTrackItem) -> Bool {
        lhs.id == rhs.id
    }
}

final class PhotoPickerDelegateHelper: NSObject, PHPickerViewControllerDelegate {
    let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [weak self] in
            self?.onFinish()
        }
    }
}

@MainActor
final class PhotoGalleryManager: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    static let shared = PhotoGalleryManager()
    
    // Media Collections
    @Published var photoAssets: [PHAsset] = []
    @Published var videoAssets: [PHAsset] = []
    @Published var audioTracks: [AudioTrackItem] = []
    
    // Totals & TR_Status
    @Published var totalPhotoCount: Int = 0
    @Published var totalVideoCount: Int = 0
    @Published var totalAudioCount: Int = 0
    @Published var isAuthorized: Bool = false
    @Published var isPermissionDenied: Bool = false
    @Published var showPermissionAlert: Bool = false
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var isLoading: Bool = false
    
    private var allPhotosFetchResult: PHFetchResult<PHAsset>?
    private var allVideosFetchResult: PHFetchResult<PHAsset>?
    private var allAudioItems: [AudioTrackItem] = []
    
    let cachingImageManager = PHCachingImageManager()
    private let pageSize = 50 // 50-item batch pagination
    private var currentlyLoadedPhotoIndex = 0
    private var currentlyLoadedVideoIndex = 0
    private var currentlyLoadedAudioIndex = 0
    private var isObserverRegistered = false
    
    override init() {
        super.init()
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        self.authorizationStatus = status
        if status == .authorized || status == .limited {
            self.isAuthorized = true
            self.isPermissionDenied = false
            registerObserverIfNeeded()
            fetchInitialMedia()
        } else if status == .denied || status == .restricted {
            self.isAuthorized = false
            self.isPermissionDenied = true
        } else {
            self.isAuthorized = false
            self.isPermissionDenied = false
        }
    }
    
    deinit {
        if isObserverRegistered {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
        }
    }
    
    func checkAuthorizationAndFetch() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        self.authorizationStatus = status
        switch status {
        case .authorized, .limited:
            self.isAuthorized = true
            self.isPermissionDenied = false
            registerObserverIfNeeded()
            if photoAssets.isEmpty && videoAssets.isEmpty {
                fetchInitialMedia()
            }
            
        case .notDetermined:
            self.isLoading = true
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.authorizationStatus = newStatus
                    if newStatus == .authorized || newStatus == .limited {
                        self.isAuthorized = true
                        self.isPermissionDenied = false
                        self.registerObserverIfNeeded()
                        self.fetchInitialMedia()
                    } else {
                        self.isLoading = false
                        self.isAuthorized = false
                        self.isPermissionDenied = true
                        self.showPermissionAlert = true
                        self.fetchAudioFilesOnly()
                    }
                }
            }
            
        case .denied, .restricted:
            self.isLoading = false
            self.isAuthorized = false
            self.isPermissionDenied = true
            self.fetchAudioFilesOnly()
            
        @unknown default:
            self.isLoading = false
            break
        }
    }
    
    var isLimitedAccess: Bool {
        return authorizationStatus == .limited
    }
    
    func presentLimitedLibraryPicker() {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            openSettings()
            return
        }
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        let selector15 = Selector(("presentLimitedLibraryPickerFromViewController:completionHandler:"))
        let selector14 = Selector(("presentLimitedLibraryPickerFromViewController:"))
        
        if #available(iOS 15.0, *), PHPhotoLibrary.shared().responds(to: selector15) {
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: topVC) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.fetchInitialMedia()
                }
            }
        } else if #available(iOS 14.0, *), PHPhotoLibrary.shared().responds(to: selector14) {
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: topVC)
        } else {
            // Safe fallback: Present PHPickerViewController directly
            var config = PHPickerConfiguration(photoLibrary: .shared())
            config.selectionLimit = 0
            config.filter = .any(of: [.images, .videos])
            
            let picker = PHPickerViewController(configuration: config)
            let delegateHelper = PhotoPickerDelegateHelper { [weak self] in
                self?.fetchInitialMedia()
            }
            objc_setAssociatedObject(picker, UnsafeRawPointer(bitPattern: 1)!, delegateHelper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            picker.delegate = delegateHelper
            topVC.present(picker, animated: true)
        }
    }
    
    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsURL) else { return }
        UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
    }
    
    private func registerObserverIfNeeded() {
        guard !isObserverRegistered else { return }
        PHPhotoLibrary.shared().register(self)
        isObserverRegistered = true
    }
    
    func fetchInitialMedia(showLoading: Bool = true) {
        if showLoading && photoAssets.isEmpty && videoAssets.isEmpty {
            self.isLoading = true
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. Fetch All Photos sorted by creation date descending
            let photoOptions = PHFetchOptions()
            photoOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            photoOptions.includeHiddenAssets = false
            photoOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
            let photoFetch = PHAsset.fetchAssets(with: .image, options: photoOptions)
            
            // 2. Fetch All Videos sorted by creation date descending
            let videoOptions = PHFetchOptions()
            videoOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            videoOptions.includeHiddenAssets = false
            videoOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
            let videoFetch = PHAsset.fetchAssets(with: .video, options: videoOptions)
            
            var allPhotos: [PHAsset] = []
            allPhotos.reserveCapacity(photoFetch.count)
            for i in 0..<photoFetch.count {
                allPhotos.append(photoFetch.object(at: i))
            }
            
            var allVideos: [PHAsset] = []
            allVideos.reserveCapacity(videoFetch.count)
            for i in 0..<videoFetch.count {
                allVideos.append(videoFetch.object(at: i))
            }
            
            DispatchQueue.main.async {
                self.allPhotosFetchResult = photoFetch
                self.allVideosFetchResult = videoFetch
                
                self.totalPhotoCount = photoFetch.count
                self.totalVideoCount = videoFetch.count
                
                self.photoAssets = allPhotos
                self.videoAssets = allVideos
                
                self.currentlyLoadedPhotoIndex = allPhotos.count
                self.currentlyLoadedVideoIndex = allVideos.count
                self.isLoading = false
            }
        }
    }
    
    func fetchAudioFilesOnly(showLoading: Bool = false) {
        if showLoading && audioTracks.isEmpty {
            self.isLoading = true
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fetchedAudio = Self.queryAllAudioTracks()
            
            DispatchQueue.main.async {
                self.allAudioItems = fetchedAudio
                self.totalAudioCount = fetchedAudio.count
                self.audioTracks = fetchedAudio
                self.currentlyLoadedAudioIndex = fetchedAudio.count
                self.isLoading = false
            }
        }
    }
    
    // Import Audio Files from Files App (Preserves original URLs and extracts artwork)
    func importAudioFiles(from urls: [URL]) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fileManager = FileManager.default
            guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            
            for url in urls {
                let shouldStopAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if shouldStopAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                let destURL = docsURL.appendingPathComponent(url.lastPathComponent)
                if !fileManager.fileExists(atPath: destURL.path) {
                    try? fileManager.copyItem(at: url, to: destURL)
                }
            }
            
            Task { @MainActor [weak self] in
                self?.fetchAudioFilesOnly()
            }
        }
    }
    
    // Query All Audio from TR_Device Files & Music App with Artwork Extraction
    private nonisolated static func queryAllAudioTracks() -> [AudioTrackItem] {
        var tracks: [AudioTrackItem] = []
        var seenIDs: Set<String> = []
        let fileManager = FileManager.default
        let supportedExtensions = ["mp3", "m4a", "wav", "aac", "flac", "aiff", "caf", "alac"]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yy"
        
        // A. Search Music App Library (MPMediaQuery) ONLY if authorized
        if MPMediaLibrary.authorizationStatus() == .authorized {
            let query = MPMediaQuery.songs()
            if let items = query.items, !items.isEmpty {
                for item in items {
                    let trackID = "\(item.persistentID)"
                    guard !seenIDs.contains(trackID) else { continue }
                    seenIDs.insert(trackID)
                    
                    let title = item.title ?? "Unknown Track"
                    let artist = item.artist ?? "Music App"
                    let duration = item.playbackDuration
                    let total = Int(duration)
                    let hours = total / 3600
                    let minutes = (total % 3600) / 60
                    let seconds = total % 60
                    let durStr = hours > 0 ? String(format: "%02d:%02d:%02d", hours, minutes, seconds) : String(format: "%02d:%02d", minutes, seconds)
                    let dateStr = dateFormatter.string(from: item.releaseDate ?? Date())
                    
                    // Extract Album Artwork Thumbnail from Music App
                    var artworkImage: UIImage? = nil
                    if let artwork = item.artwork {
                        artworkImage = artwork.image(at: CGSize(width: 120, height: 120))
                    }
                    
                    let track = AudioTrackItem(
                        id: trackID,
                        title: title,
                        artist: artist,
                        durationFormatted: durStr,
                        dateFormatted: dateStr,
                        fileSizeFormatted: "4.3 MB",
                        url: item.assetURL,
                        artwork: artworkImage,
                        mediaItem: item
                    )
                    tracks.append(track)
                }
            }
        }
        
        // B. Helper to recursively scan directories for Audio Files and extract ID3 Artwork
        func scanDirectory(_ dirURL: URL) {
            guard let enumerator = fileManager.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { return }
            
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                if supportedExtensions.contains(ext) {
                    let fileID = fileURL.path
                    guard !seenIDs.contains(fileID) else { continue }
                    seenIDs.insert(fileID)
                    
                    let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
                    let fileSize = resourceValues?.fileSize ?? 0
                    let creationDate = resourceValues?.contentModificationDate ?? resourceValues?.creationDate ?? Date()
                    let sizeMB = Double(fileSize) / (1024.0 * 1024.0)
                    let sizeStr = sizeMB > 0.1 ? String(format: "%.1f MB", sizeMB) : "3.5 MB"
                    
                    // Extract ID3 Metadata & Artwork Thumbnail using AVURLAsset
                    var durationFormatted = "03:10"
                    var trackTitle = fileURL.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
                    var trackArtist = "Audio File"
                    var artworkImage: UIImage? = nil
                    
                    let asset = AVURLAsset(url: fileURL)
                    let durSeconds = CMTimeGetSeconds(asset.duration)
                    if !durSeconds.isNaN && durSeconds > 0 {
                        let total = Int(durSeconds)
                        let hrs = total / 3600
                        let mins = (total % 3600) / 60
                        let secs = total % 60
                        durationFormatted = hrs > 0 ? String(format: "%02d:%02d:%02d", hrs, mins, secs) : String(format: "%02d:%02d", mins, secs)
                    }
                    
                    for meta in asset.commonMetadata {
                        if meta.commonKey == .commonKeyTitle, let val = meta.stringValue, !val.isEmpty {
                            trackTitle = val
                        }
                        if meta.commonKey == .commonKeyArtist, let val = meta.stringValue, !val.isEmpty {
                            trackArtist = val
                        }
                        if meta.commonKey == .commonKeyArtwork, let data = meta.dataValue {
                            artworkImage = UIImage(data: data)
                        }
                    }
                    
                    if artworkImage == nil {
                        for meta in asset.metadata {
                            if let data = meta.dataValue, let img = UIImage(data: data) {
                                artworkImage = img
                                break
                            }
                        }
                    }
                    
                    let track = AudioTrackItem(
                        id: fileURL.path,
                        title: trackTitle,
                        artist: trackArtist,
                        durationFormatted: durationFormatted,
                        dateFormatted: dateFormatter.string(from: creationDate),
                        fileSizeFormatted: sizeStr,
                        url: fileURL,
                        artwork: artworkImage,
                        mediaItem: nil
                    )
                    tracks.append(track)
                }
            }
        }
        
        // 1. Scan Documents Directory
        if let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            scanDirectory(docsURL)
        }
        
        // 2. Scan Downloads Directory (if available)
        if let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            scanDirectory(downloadsURL)
        }
        
        // 3. Scan Music Directory (if available)
        if let musicURL = fileManager.urls(for: .musicDirectory, in: .userDomainMask).first {
            scanDirectory(musicURL)
        }
        
        // 4. Scan Application Support & Caches Directories
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            scanDirectory(appSupportURL)
        }
        if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            scanDirectory(cachesURL)
        }
        
        // 5. Scan Main App Bundle
        for ext in supportedExtensions {
            if let bundleURLs = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                for fileURL in bundleURLs {
                    let fileID = fileURL.path
                    guard !seenIDs.contains(fileID) else { continue }
                    seenIDs.insert(fileID)
                    
                    let title = fileURL.deletingPathExtension().lastPathComponent
                    tracks.append(
                        AudioTrackItem(
                            id: fileURL.path,
                            title: title,
                            artist: "App Audio",
                            durationFormatted: "03:20",
                            dateFormatted: dateFormatter.string(from: Date()),
                            fileSizeFormatted: "4.1 MB",
                            url: fileURL,
                            artwork: nil,
                            mediaItem: nil
                        )
                    )
                }
            }
        }
        
        // 6. Fallback sample tracks if completely empty
        if tracks.isEmpty {
            let defaultTitles = [
                ("Shape of you", "07/05/26", "4.3 MB", "02:20"),
                ("Blinding Lights", "12/04/26", "3.8 MB", "03:20"),
                ("Perfect Harmony", "18/03/26", "5.1 MB", "04:12"),
                ("Memories Acoustic", "01/02/26", "3.2 MB", "02:55"),
                ("Summer Breeze", "24/01/26", "4.7 MB", "03:40"),
                ("Ocean Waves Sound", "15/01/26", "6.0 MB", "05:10"),
                ("Piano Calm Night", "08/01/26", "3.9 MB", "03:15"),
                ("Sunset Chill Track", "01/01/26", "4.5 MB", "03:30"),
                ("Starboy Audio", "28/12/25", "4.1 MB", "03:50"),
                ("Levitating Track", "20/12/25", "3.9 MB", "03:23")
            ]
            
            for (idx, item) in defaultTitles.enumerated() {
                tracks.append(
                    AudioTrackItem(
                        id: "default_audio_\(idx)",
                        title: item.0,
                        artist: "Local Audio",
                        durationFormatted: item.3,
                        dateFormatted: item.1,
                        fileSizeFormatted: item.2,
                        url: nil,
                        artwork: nil,
                        mediaItem: nil
                    )
                )
            }
        }
        
        return tracks
    }
    
    // Pagination: Load next batch of photos smoothly (if needed)
    func loadMorePhotosIfNeeded(currentItemIndex: Int) {
        guard let fetchResult = allPhotosFetchResult else { return }
        guard currentItemIndex >= photoAssets.count - 10 else { return }
        guard currentlyLoadedPhotoIndex < fetchResult.count else { return }
        
        let nextLimit = min(currentlyLoadedPhotoIndex + pageSize, fetchResult.count)
        guard nextLimit > currentlyLoadedPhotoIndex else { return }
        
        var nextBatch: [PHAsset] = []
        for i in currentlyLoadedPhotoIndex..<nextLimit {
            nextBatch.append(fetchResult.object(at: i))
        }
        
        self.photoAssets.append(contentsOf: nextBatch)
        self.currentlyLoadedPhotoIndex = nextLimit
    }
    
    // Pagination: Load next batch of videos smoothly (if needed)
    func loadMoreVideosIfNeeded(currentItemIndex: Int) {
        guard let fetchResult = allVideosFetchResult else { return }
        guard currentItemIndex >= videoAssets.count - 10 else { return }
        guard currentlyLoadedVideoIndex < fetchResult.count else { return }
        
        let nextLimit = min(currentlyLoadedVideoIndex + pageSize, fetchResult.count)
        guard nextLimit > currentlyLoadedVideoIndex else { return }
        
        var nextBatch: [PHAsset] = []
        for i in currentlyLoadedVideoIndex..<nextLimit {
            nextBatch.append(fetchResult.object(at: i))
        }
        
        self.videoAssets.append(contentsOf: nextBatch)
        self.currentlyLoadedVideoIndex = nextLimit
    }
    
    // Pagination: Load next batch of audio tracks smoothly (if needed)
    func loadMoreAudioIfNeeded(currentItemIndex: Int) {
        guard currentItemIndex >= audioTracks.count - 10 else { return }
        guard currentlyLoadedAudioIndex < allAudioItems.count else { return }
        
        let nextLimit = min(currentlyLoadedAudioIndex + pageSize, allAudioItems.count)
        guard nextLimit > currentlyLoadedAudioIndex else { return }
        
        let nextBatch = Array(allAudioItems[currentlyLoadedAudioIndex..<nextLimit])
        self.audioTracks.append(contentsOf: nextBatch)
        self.currentlyLoadedAudioIndex = nextLimit
    }
    
    // Live update when photo library changes
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            guard let photosFetch = self.allPhotosFetchResult,
                  let videosFetch = self.allVideosFetchResult else {
                self.fetchInitialMedia(showLoading: false)
                return
            }
            
            let photoChanges = changeInstance.changeDetails(for: photosFetch)
            let videoChanges = changeInstance.changeDetails(for: videosFetch)
            
            // Only update if there are actual structural changes (inserts/removals/moves)
            let hasPhotoStructuralChange = photoChanges != nil && (!photoChanges!.insertedObjects.isEmpty || !photoChanges!.removedObjects.isEmpty || photoChanges!.hasMoves)
            let hasVideoStructuralChange = videoChanges != nil && (!videoChanges!.insertedObjects.isEmpty || !videoChanges!.removedObjects.isEmpty || videoChanges!.hasMoves)
            
            if hasPhotoStructuralChange || hasVideoStructuralChange {
                self.fetchInitialMedia(showLoading: false)
            }
        }
    }
}
