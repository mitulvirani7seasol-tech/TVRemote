//
//  BrowserViewModel.swift
//  TV Remote
//

import Foundation
import SwiftUI
import Combine
import WebKit

struct QuickAccessItem: Identifiable {
    let id = UUID()
    let name: String
    let iconImageName: String
    let urlString: String
}

@MainActor
class BrowserViewModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.bounces = true
        return wv
    }()
    
    @Published var currentURL: URL?
    @Published var pageTitle: String = ""
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0.0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var searchInputText: String = ""
    
    // Video Detection for TR_TV Casting
    @Published var detectedVideoID: String? = nil
    @Published var streamableVideoURL: URL? = nil
    @Published var isVideoDetected: Bool = false
    @Published var isFetchingStream: Bool = false
    @Published var detectedVideoTitle: String = ""
    @Published var detectedVideoThumbnailURL: URL? = nil
    @Published var detectedVideoDuration: Double = 0.0
    
    // 8 Figma Quick Access Items from "browser ic" Assets (media_1788337562137.png)
    let quickAccessItems: [QuickAccessItem] = [
        QuickAccessItem(name: "Youtube", iconImageName: "Youtube2", urlString: "https://www.youtube.com"),
        QuickAccessItem(name: "Reddit", iconImageName: "Reddit", urlString: "https://www.reddit.com"),
        QuickAccessItem(name: "Telegram", iconImageName: "Telegram", urlString: "https://web.telegram.org"),
        QuickAccessItem(name: "Pinterest", iconImageName: "Pinterest", urlString: "https://www.pinterest.com"),
        QuickAccessItem(name: "Disney +", iconImageName: "Disney", urlString: "https://www.disneyplus.com"),
        QuickAccessItem(name: "Instagram", iconImageName: "Instagram", urlString: "https://www.instagram.com"),
        QuickAccessItem(name: "Twitch", iconImageName: "Twitch", urlString: "https://www.twitch.tv"),
        QuickAccessItem(name: "Facebook", iconImageName: "Facebook", urlString: "https://www.facebook.com")
    ]
    
    private var progressObserver: NSKeyValueObservation?
    private var urlObserver: NSKeyValueObservation?
    private var titleObserver: NSKeyValueObservation?
    private var backObserver: NSKeyValueObservation?
    private var forwardObserver: NSKeyValueObservation?
    private var loadingObserver: NSKeyValueObservation?
    private var pollTimer: Timer?
    
    override init() {
        super.init()
        webView.navigationDelegate = self
        setupObservers()
        startPeriodicUrlCheck()
    }
    
    deinit {
        progressObserver?.invalidate()
        urlObserver?.invalidate()
        titleObserver?.invalidate()
        backObserver?.invalidate()
        forwardObserver?.invalidate()
        loadingObserver?.invalidate()
        pollTimer?.invalidate()
    }
    
    private func setupObservers() {
        progressObserver = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
            DispatchQueue.main.async {
                self?.estimatedProgress = wv.estimatedProgress
            }
        }
        
        urlObserver = webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
            DispatchQueue.main.async {
                self?.handleUrlChanged(wv.url)
            }
        }
        
        titleObserver = webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
            DispatchQueue.main.async {
                self?.pageTitle = wv.title ?? ""
            }
        }
        
        backObserver = webView.observe(\.canGoBack, options: [.new]) { [weak self] wv, _ in
            DispatchQueue.main.async {
                self?.canGoBack = wv.canGoBack
            }
        }
        
        forwardObserver = webView.observe(\.canGoForward, options: [.new]) { [weak self] wv, _ in
            DispatchQueue.main.async {
                self?.canGoForward = wv.canGoForward
            }
        }
        
        loadingObserver = webView.observe(\.isLoading, options: [.new]) { [weak self] wv, _ in
            DispatchQueue.main.async {
                self?.isLoading = wv.isLoading
                if !(wv.isLoading) {
                    self?.inspectInPageMedia()
                }
            }
        }
    }
    
    private func startPeriodicUrlCheck() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.webView.evaluateJavaScript("""
                (function() {
                    var href = window.location.href;
                    var vid = "";
                    var match = href.match(/[?&]v=([^&#]+)/) || href.match(/\\/shorts\\/([^&#/?]+)/) || href.match(/\\/embed\\/([^&#/?]+)/) || href.match(/youtu\\.be\\/([^&#/?]+)/);
                    if (match && match[1]) {
                        vid = match[1];
                    }
                    var title = document.title || "";
                    var h1 = document.querySelector('h1.slim-video-information-title, h1.title, .watch-title, h2.media-item-headline');
                    if (h1 && h1.innerText && h1.innerText.length > 0) {
                        title = h1.innerText.trim();
                    }
                    return JSON.stringify({ url: href, videoId: vid, title: title });
                })()
                """) { (result, _) in
                    if let jsonString = result as? String,
                       let data = jsonString.data(using: .utf8),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let href = dict["url"] as? String ?? ""
                        let videoId = dict["videoId"] as? String ?? ""
                        let title = dict["title"] as? String ?? ""
                        
                        if let url = URL(string: href) {
                            if url.absoluteString != self.currentURL?.absoluteString {
                                self.handleUrlChanged(url)
                            }
                        }
                        
                        if !videoId.isEmpty && self.detectedVideoID != videoId {
                            self.detectedVideoID = videoId
                            self.isVideoDetected = true
                            if !title.isEmpty && title != "YouTube" {
                                self.detectedVideoTitle = title
                            }
                            self.detectedVideoThumbnailURL = URL(string: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg")
                            self.fetchYouTubeStreamURL(videoID: videoId)
                        } else if self.streamableVideoURL == nil && !self.isFetchingStream {
                            self.inspectInPageMedia()
                        }
                    } else if let href = result as? String, let url = URL(string: href) {
                        if url.absoluteString != self.currentURL?.absoluteString {
                            self.handleUrlChanged(url)
                        } else if self.streamableVideoURL == nil && !self.isFetchingStream {
                            self.inspectInPageMedia()
                        }
                    }
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }
    
    private func handleUrlChanged(_ newUrl: URL?) {
        guard let url = newUrl else { return }
        if currentURL?.absoluteString != url.absoluteString {
            currentURL = url
            searchInputText = url.absoluteString
            checkForVideo(url: url)
        }
    }
    
    func loadSearchOrURL(input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var targetURL: URL?
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            targetURL = URL(string: trimmed)
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            targetURL = URL(string: "https://" + trimmed)
        } else {
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            targetURL = URL(string: "https://www.google.com/search?q=\(encoded)")
        }
        
        if let url = targetURL {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }
    
    func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }
    
    func reload() {
        webView.reload()
    }
    
    func goHome() {
        loadSearchOrURL(input: "https://www.google.com")
    }
    
    func pauseInPageVideos() {
        muteAndPauseInPageMedia()
    }
    
    func muteAndPauseInPageMedia() {
        let js = """
        (function() {
            // 1. Pause and mute all video & audio elements on page
            var mediaElements = document.querySelectorAll('video, audio');
            mediaElements.forEach(function(m) {
                try {
                    m.pause();
                    m.muted = true;
                    m.volume = 0;
                } catch(e) {}
            });
            
            // 2. YouTube specific player API
            try {
                var ytPlayer = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (ytPlayer) {
                    if (typeof ytPlayer.pauseVideo === 'function') ytPlayer.pauseVideo();
                    if (typeof ytPlayer.mute === 'function') ytPlayer.mute();
                    if (typeof ytPlayer.setVolume === 'function') ytPlayer.setVolume(0);
                }
            } catch(e) {}
            
            // 3. Any iframes with video/audio
            try {
                var iframes = document.querySelectorAll('iframe');
                iframes.forEach(function(f) {
                    try {
                        var doc = f.contentDocument || f.contentWindow.document;
                        if (doc) {
                            var ifMedia = doc.querySelectorAll('video, audio');
                            ifMedia.forEach(function(m) {
                                try {
                                    m.pause();
                                    m.muted = true;
                                    m.volume = 0;
                                } catch(e) {}
                            });
                        }
                    } catch(e) {}
                });
            } catch(e) {}
        })()
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    // MARK: - Video Detection & Stream Resolution
    func checkForVideo(url: URL) {
        let urlString = url.absoluteString.lowercased()
        
        if let videoID = extractYouTubeID(from: url.absoluteString) {
            if self.detectedVideoID == videoID && self.streamableVideoURL != nil {
                return
            }
            self.detectedVideoID = videoID
            self.isVideoDetected = true
            self.streamableVideoURL = nil
            self.isFetchingStream = true
            fetchYouTubeStreamURL(videoID: videoID)
        } else if urlString.hasSuffix(".mp4") || urlString.hasSuffix(".m3u8") || urlString.hasSuffix(".mpd") || urlString.hasSuffix(".mov") || urlString.hasSuffix(".ts") {
            self.detectedVideoID = nil
            self.streamableVideoURL = url
            self.isVideoDetected = true
            self.isFetchingStream = false
        } else {
            self.detectedVideoID = nil
            self.streamableVideoURL = nil
            self.isVideoDetected = false
            self.isFetchingStream = false
            inspectInPageMedia()
        }
    }
    
    private func inspectInPageMedia() {
        // Inspect HTML5 video elements if not YouTube
        guard detectedVideoID == nil else { return }
        
        let js = """
        (function() {
            var v = document.querySelector('video');
            if (v) {
                if (v.currentSrc && v.currentSrc.length > 0 && v.currentSrc.indexOf('blob:') !== 0) return v.currentSrc;
                if (v.src && v.src.length > 0 && v.src.indexOf('blob:') !== 0) return v.src;
                var s = v.querySelector('source');
                if (s && s.src && s.src.indexOf('blob:') !== 0) return s.src;
            }
            return '';
        })()
        """
        webView.evaluateJavaScript(js) { [weak self] (result, _) in
            guard let self = self else { return }
            if let src = result as? String, !src.isEmpty, let videoURL = URL(string: src), videoURL.scheme?.hasPrefix("http") == true {
                DispatchQueue.main.async {
                    self.isVideoDetected = true
                    self.streamableVideoURL = videoURL
                    self.isFetchingStream = false
                }
            }
        }
    }
    
    private func fetchYouTubeStreamURL(videoID: String) {
        guard let apiURL = URL(string: "https://yt-api.p.rapidapi.com/dl?id=\(videoID)") else {
            self.isFetchingStream = false
            return
        }
        var request = URLRequest(url: apiURL)
        request.setValue("4c8a6959d4mshdda890c244de333p1a9559jsnfa944e297289", forHTTPHeaderField: "x-rapidapi-key")
        request.setValue("yt-api.p.rapidapi.com", forHTTPHeaderField: "x-rapidapi-host")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.isFetchingStream = false
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    var resolvedURL: URL?
                    
                    if let formats = json["formats"] as? [[String: Any]] {
                        for format in formats {
                            if let urlString = format["url"] as? String, let streamURL = URL(string: urlString) {
                                resolvedURL = streamURL
                                break
                            }
                        }
                    }
                    
                    if resolvedURL == nil, let adaptiveFormats = json["adaptiveFormats"] as? [[String: Any]] {
                        for format in adaptiveFormats {
                            if let mimeType = format["mimeType"] as? String,
                               mimeType.contains("video/mp4"),
                               let urlString = format["url"] as? String,
                               let streamURL = URL(string: urlString) {
                                resolvedURL = streamURL
                                break
                            }
                        }
                    }
                    
                    let parsedTitle = (json["title"] as? String) ?? self.pageTitle
                    var parsedDuration: Double = 0.0
                    if let secStr = json["lengthSeconds"] as? String, let dur = Double(secStr) {
                        parsedDuration = dur
                    } else if let secNum = json["lengthSeconds"] as? Double {
                        parsedDuration = secNum
                    }
                    
                    let thumbURL = URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg")
                    
                    DispatchQueue.main.async {
                        self.isFetchingStream = false
                        self.detectedVideoThumbnailURL = thumbURL
                        if !parsedTitle.isEmpty {
                            self.detectedVideoTitle = parsedTitle
                        }
                        self.detectedVideoDuration = parsedDuration
                        if let streamURL = resolvedURL {
                            self.streamableVideoURL = streamURL
                            self.isVideoDetected = true
                            print("✅ YouTube stream extracted: \(streamURL.absoluteString.prefix(60))...")
                        } else {
                            print("❌ No direct stream found in YouTube response")
                        }
                    }
                }
            } catch {
                print("YouTube parse error: \(error)")
                DispatchQueue.main.async {
                    self.isFetchingStream = false
                }
            }
        }.resume()
    }
    
    func extractYouTubeID(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            if let id = queryItems.first(where: { $0.name == "v" })?.value, !id.isEmpty {
                return id
            }
        }
        
        if url.host?.contains("youtu.be") == true {
            let last = url.lastPathComponent
            return last.isEmpty ? nil : last
        }
        
        if url.path.contains("/shorts/") {
            let last = url.lastPathComponent
            return last.isEmpty ? nil : last
        }
        
        if url.path.contains("/embed/") {
            let last = url.lastPathComponent
            return last.isEmpty ? nil : last
        }
        
        return nil
    }
    
    // MARK: - WKNavigationDelegate
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.handleUrlChanged(webView.url)
            self.inspectInPageMedia()
        }
    }
}
