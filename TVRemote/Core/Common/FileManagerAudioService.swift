//
//  FileManagerAudioService.swift
//  TV Remote
//

import Foundation
import SwiftUI
import AVFoundation

final class FileManagerAudioService {
    static let shared = FileManagerAudioService()
    
    private let supportedExtensions = ["mp3", "m4a", "wav", "aac", "flac", "aiff", "caf", "alac"]
    
    // Dynamically fetch all real audio files directly from device storage via FileManager
    func fetchAudioFilesFromDisk() -> [MusicItem] {
        var audioItems: [MusicItem] = []
        var seenPaths: Set<String> = []
        let fileManager = FileManager.default
        
        // Helper to scan a directory recursively
        func scanDirectory(url: URL) {
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .creationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return }
            
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                if supportedExtensions.contains(ext) {
                    let path = fileURL.path
                    guard !seenPaths.contains(path) else { continue }
                    seenPaths.insert(path)
                    
                    let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .creationDateKey])
                    let fileSize = resourceValues?.fileSize ?? 0
                    let sizeMB = Double(fileSize) / (1024.0 * 1024.0)
                    let sizeStr = sizeMB > 0.05 ? String(format: "%.1f MB", sizeMB) : "1.0 MB"
                    
                    var title = fileURL.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
                    var artist = "Audio File"
                    var album = "TR_Device Files"
                    var artwork: UIImage? = nil
                    
                    let asset = AVURLAsset(url: fileURL)
                    let durSeconds = CMTimeGetSeconds(asset.duration)
                    let duration: TimeInterval = (!durSeconds.isNaN && durSeconds > 0) ? durSeconds : 0
                    
                    for meta in asset.commonMetadata {
                        if meta.commonKey == .commonKeyTitle, let val = meta.stringValue, !val.isEmpty {
                            title = val
                        }
                        if meta.commonKey == .commonKeyArtist, let val = meta.stringValue, !val.isEmpty {
                            artist = val
                        }
                        if meta.commonKey == .commonKeyAlbumName, let val = meta.stringValue, !val.isEmpty {
                            album = val
                        }
                        if meta.commonKey == .commonKeyArtwork, let data = meta.dataValue {
                            artwork = UIImage(data: data)
                        }
                    }
                    
                    if artwork == nil {
                        for meta in asset.metadata {
                            if let data = meta.dataValue, let img = UIImage(data: data) {
                                artwork = img
                                break
                            }
                        }
                    }
                    
                    let item = MusicItem(
                        id: path,
                        title: title,
                        size: sizeStr,
                        artist: artist,
                        album: album,
                        duration: duration,
                        assetURL: fileURL,
                        artwork: artwork,
                        mediaItem: nil
                    )
                    audioItems.append(item)
                }
            }
        }
        
        // 1. Documents Directory (Files App: On My iPhone -> TV Remote)
        if let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            scanDirectory(url: docsURL)
        }
        
        // 2. Downloads Directory
        if let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            scanDirectory(url: downloadsURL)
        }
        
        // 3. Music Directory
        if let musicURL = fileManager.urls(for: .musicDirectory, in: .userDomainMask).first {
            scanDirectory(url: musicURL)
        }
        
        // 4. Application Support Directory
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            scanDirectory(url: appSupportURL)
        }
        
        // 5. Caches Directory
        if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            scanDirectory(url: cachesURL)
        }
        
        // 6. Main App Bundle Audio Files
        for ext in supportedExtensions {
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                for fileURL in urls {
                    let path = fileURL.path
                    guard !seenPaths.contains(path) else { continue }
                    seenPaths.insert(path)
                    
                    let title = fileURL.deletingPathExtension().lastPathComponent
                    let asset = AVURLAsset(url: fileURL)
                    let durSeconds = CMTimeGetSeconds(asset.duration)
                    let duration: TimeInterval = (!durSeconds.isNaN && durSeconds > 0) ? durSeconds : 0
                    
                    let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
                    let fileSize = resourceValues?.fileSize ?? 0
                    let sizeMB = Double(fileSize) / (1024.0 * 1024.0)
                    let sizeStr = sizeMB > 0.05 ? String(format: "%.1f MB", sizeMB) : "1.0 MB"
                    
                    let item = MusicItem(
                        id: path,
                        title: title,
                        size: sizeStr,
                        artist: "App Audio",
                        album: "Bundle",
                        duration: duration,
                        assetURL: fileURL,
                        artwork: nil,
                        mediaItem: nil
                    )
                    audioItems.append(item)
                }
            }
        }
        
        return audioItems
    }
}
