//
//  WebServer.swift
//  TV Remote Casting
//

import Foundation
import ConnectSDK
import Combine
import Network

class TR_CastingServerManager: ObservableObject {
    static let shared = TR_CastingServerManager()
    private var webServer: GCDWebServer?
    @Published var serverURL: URL?
    @Published var isConnectedToNetwork: Bool = true
    private var monitor: NWPathMonitor?
    private var monitorQueue: DispatchQueue?
    
    private var currentLocalVideoPath: String?
    private let videoPathLock = NSLock()
    
    init() {
        startNetworkMonitoring()
    }

    private func startNetworkMonitoring() {
        monitor = NWPathMonitor()
        monitorQueue = DispatchQueue(label: "NetworkMonitorQueue")
        
        monitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnectedToNetwork = path.status == .satisfied
                
                if self?.isConnectedToNetwork == true {
                    if self?.webServer == nil {
                        self?.setupServer()
                    }
                } else {
                    print("No network connection. Server cannot start.")
                }
            }
        }
        
        monitor?.start(queue: monitorQueue!)
    }
    
    func setLocalVideoToServe(_ path: String) {
        videoPathLock.lock()
        currentLocalVideoPath = path
        videoPathLock.unlock()
    }
    
    var effectiveServerURL: URL? {
        if webServer == nil || webServer?.isRunning == false {
            setupServer()
        }
        let port = webServer?.port ?? 8080
        if let wifiIP = getWiFiAddress(), !wifiIP.isEmpty {
            return URL(string: "http://\(wifiIP):\(port)/")
        }
        if let base = webServer?.serverURL, let host = base.host, host != "127.0.0.1", host != "localhost" {
            return base
        }
        return webServer?.serverURL ?? serverURL
    }
    
    func setupServer() {
        guard isConnectedToNetwork else {
            print("Cannot start the server without network connection.")
            return
        }
        
        if webServer == nil {
            webServer = GCDWebServer()
            
            // HTML Image Viewer Wrapper
            webServer?.addHandler(forMethod: "GET", pathRegex: "/view/.*", request: GCDWebServerRequest.self) { request in
                guard let requestPath = request?.path else { return GCDWebServerErrorResponse(statusCode: 400) }
                let smRequestedFileName = (requestPath as NSString).lastPathComponent
                let imageURL = "/files/\(smRequestedFileName)"
                
                let htmlContent = """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <style>
                        body { margin: 0; background-color: black; display: flex; justify-content: center; align-items: center; height: 100vh; overflow: hidden; }
                        img { max-width: 100%; max-height: 100%; object-fit: contain; }
                    </style>
                </head>
                <body>
                    <img src="\(imageURL)">
                </body>
                </html>
                """
                return GCDWebServerDataResponse(html: htmlContent)
            }
            
            // Full-screen Video & HLS Live Stream Player for Smart TVs
            webServer?.addHandler(forMethod: "GET", pathRegex: "/player.*", request: GCDWebServerRequest.self) { request in
                let query = request?.query ?? [:]
                let streamUrlString = query["url"] ?? ""
                let title = query["title"] ?? "Live TR_TV"
                
                let htmlContent = """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>\(title)</title>
                    <style>
                        * { margin: 0; padding: 0; box-sizing: border-box; }
                        body { background-color: #000; overflow: hidden; width: 100vw; height: 100vh; display: flex; align-items: center; justify-content: center; }
                        video { width: 100%; height: 100%; object-fit: contain; }
                    </style>
                </head>
                <body>
                    <video id="tvPlayer" controls autoplay playsinline></video>
                    <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
                    <script>
                        var video = document.getElementById('tvPlayer');
                        var streamURL = "\(streamUrlString)";
                        
                        function playStream() {
                            if (Hls.isSupported() && (streamURL.indexOf('.m3u8') !== -1 || streamURL.indexOf('m3u8') !== -1)) {
                                var hls = new Hls({ enableWorker: true, lowLatencyMode: true });
                                hls.loadSource(streamURL);
                                hls.attachMedia(video);
                                hls.on(Hls.Events.MANIFEST_PARSED, function() {
                                    video.play().catch(function(e) { console.log(e); });
                                });
                            } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
                                video.src = streamURL;
                                video.addEventListener('loadedmetadata', function() {
                                    video.play().catch(function(e) { console.log(e); });
                                });
                            } else {
                                video.src = streamURL;
                                video.play().catch(function(e) { console.log(e); });
                            }
                        }
                        
                        if (streamURL) {
                            playStream();
                        }
                    </script>
                </body>
                </html>
                """
                return GCDWebServerDataResponse(html: htmlContent)
            }
            
            // Audio Player with Poster & Metadata for Smart TVs
            webServer?.addHandler(forMethod: "GET", pathRegex: "/audioplayer.*", request: GCDWebServerRequest.self) { request in
                let query = request?.query ?? [:]
                let audioUrlString = query["url"] ?? ""
                let title = query["title"] ?? "Music"
                let artist = query["artist"] ?? ""
                let posterUrlString = query["poster"] ?? ""
                
                let htmlContent = """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>\(title)</title>
                    <style>
                        * { margin: 0; padding: 0; box-sizing: border-box; }
                        body {
                            background-color: #0c0f1d;
                            overflow: hidden;
                            width: 100vw;
                            height: 100vh;
                            display: flex;
                            align-items: center;
                            justify-content: center;
                            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                            position: relative;
                        }
                        .bg-blur {
                            position: absolute;
                            top: 0; left: 0; right: 0; bottom: 0;
                            background-size: cover;
                            background-position: center;
                            filter: blur(80px);
                            opacity: 0.40;
                            z-index: 1;
                        }
                        .container {
                            position: relative;
                            z-index: 2;
                            display: flex;
                            flex-direction: column;
                            align-items: center;
                            text-align: center;
                            padding: 24px;
                            max-width: 90vw;
                        }
                        .poster {
                            width: 380px;
                            height: 380px;
                            max-width: 70vw;
                            max-height: 52vh;
                            border-radius: 28px;
                            object-fit: cover;
                            box-shadow: 0 20px 50px rgba(0, 0, 0, 0.65);
                            margin-bottom: 28px;
                            border: 1px solid rgba(255, 255, 255, 0.12);
                            background-color: #1a1d2e;
                        }
                        .title {
                            color: #ffffff;
                            font-size: 32px;
                            font-weight: 700;
                            margin-bottom: 10px;
                            max-width: 80vw;
                            white-space: nowrap;
                            overflow: hidden;
                            text-overflow: ellipsis;
                            text-shadow: 0 2px 10px rgba(0,0,0,0.5);
                        }
                        .artist {
                            color: rgba(255, 255, 255, 0.75);
                            font-size: 22px;
                            font-weight: 500;
                            margin-bottom: 32px;
                            max-width: 80vw;
                            white-space: nowrap;
                            overflow: hidden;
                            text-overflow: ellipsis;
                        }
                        audio {
                            width: 480px;
                            max-width: 85vw;
                            height: 50px;
                            outline: none;
                        }
                    </style>
                </head>
                <body>
                    <div class="bg-blur" id="bgBlur"></div>
                    <div class="container">
                        <img class="poster" id="posterImg" src="\(posterUrlString)">
                        <div class="title">\(title)</div>
                        <div class="artist">\(artist)</div>
                        <audio id="audioPlayer" controls autoplay playsinline src="\(audioUrlString)"></audio>
                    </div>
                    <script>
                        var poster = "\(posterUrlString)";
                        if (poster) {
                            document.getElementById('bgBlur').style.backgroundImage = 'url(' + poster + ')';
                        }
                        var audio = document.getElementById('audioPlayer');
                        audio.play().catch(function(e) { console.log(e); });
                    </script>
                </body>
                </html>
                """
                return GCDWebServerDataResponse(html: htmlContent)
            }
            
            // Upload endpoint
            webServer?.addHandler(forMethod: "POST", path: "/upload", request: GCDWebServerDataRequest.self) { request in
                if let dataRequest = request as? GCDWebServerDataRequest {
                    let contentType = request?.contentType ?? "application/octet-stream"
                    let fileExtension: String
                    
                    if contentType.contains("image") {
                        fileExtension = ".jpg"
                    } else if contentType.contains("video") {
                        fileExtension = ".mp4"
                    } else {
                        fileExtension = ".dat"
                    }
                    
                    let smGeneratedFileName = UUID().uuidString + fileExtension
                    let filePath = NSTemporaryDirectory().appending(smGeneratedFileName)
                    do {
                        try dataRequest.data.write(to: URL(fileURLWithPath: filePath))
                        print("File uploaded to: \(filePath)")
                        let base = self.effectiveServerURL ?? self.serverURL ?? self.webServer?.serverURL
                        let fileURL = base?.appendingPathComponent("files/\(smGeneratedFileName)").absoluteString
                        let response = GCDWebServerDataResponse(text: fileURL)
                        response?.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
                        return response
                    } catch {
                        print("Error saving file: \(error)")
                        return GCDWebServerErrorResponse(statusCode: 500)
                    }
                }
                return GCDWebServerErrorResponse(statusCode: 400)
            }
            
            // Files endpoint
            webServer?.addHandler(forMethod: "GET", pathRegex: "/files/.*", request: GCDWebServerRequest.self) { request in
                let smEndpointFileName = (request?.path as NSString?)?.lastPathComponent ?? ""
                let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(smEndpointFileName)
                let filePath = destinationURL.path
                
                guard FileManager.default.fileExists(atPath: filePath) else {
                    print("❌ File not found at: \(filePath)")
                    return GCDWebServerResponse(statusCode: 404)
                }
                
                let byteRange = request?.byteRange ?? NSRange(location: NSNotFound, length: 0)
                if let fileResponse = GCDWebServerFileResponse(file: filePath, byteRange: byteRange) {
                    let contentType = self.determineContentType(for: destinationURL.pathExtension)
                    fileResponse.setValue(contentType, forAdditionalHeader: "Content-Type")
                    fileResponse.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
                    fileResponse.setValue("bytes", forAdditionalHeader: "Accept-Ranges")
                    return fileResponse
                }
                
                do {
                    let fileData = try Data(contentsOf: destinationURL)
                    let contentType = self.determineContentType(for: destinationURL.pathExtension)
                    let response = GCDWebServerDataResponse(data: fileData, contentType: contentType)
                    response?.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
                    return response
                } catch {
                    print("Error reading file data: \(error)")
                    return GCDWebServerResponse(statusCode: 500)
                }
            }
            
            // Direct Local Video Streaming endpoint
            webServer?.addHandler(
                forMethod: "GET",
                pathRegex: "/localvideo/.*",
                request: GCDWebServerRequest.self
            ) { [weak self] request in
                guard let self = self else {
                    return GCDWebServerErrorResponse(statusCode: 500)
                }
                
                self.videoPathLock.lock()
                let path = self.currentLocalVideoPath
                self.videoPathLock.unlock()
                
                guard let path = path, FileManager.default.fileExists(atPath: path) else {
                    print("❌ Local video path not found: \(String(describing: path))")
                    return GCDWebServerErrorResponse(statusCode: 404)
                }
                
                let byteRange = request?.byteRange ?? NSRange(location: NSNotFound, length: 0)
                guard let response = GCDWebServerFileResponse(file: path, byteRange: byteRange) else {
                    return GCDWebServerErrorResponse(statusCode: 500)
                }
                
                response.setValue("video/mp4", forAdditionalHeader: "Content-Type")
                response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
                return response
            }
        }
        
        if webServer?.isRunning == false {
            do {
                try webServer?.start(options: [
                    GCDWebServerOption_Port: 8080,
                    GCDWebServerOption_BindToLocalhost: false,
                    GCDWebServerOption_AutomaticallySuspendInBackground: false
                ])
                if let wifiIP = getWiFiAddress(), let port = webServer?.port {
                    let url = URL(string: "http://\(wifiIP):\(port)/")
                    self.serverURL = url
                    print("✅ Casting server started on LAN at \(url?.absoluteString ?? "")")
                } else if let serverURL = webServer?.serverURL {
                    self.serverURL = serverURL
                    print("✅ Casting server started at \(serverURL)")
                }
            } catch {
                print("Error starting casting server on port 8080: \(error), falling back to dynamic port...")
                do {
                    try webServer?.start(options: [
                        GCDWebServerOption_BindToLocalhost: false,
                        GCDWebServerOption_AutomaticallySuspendInBackground: false
                    ])
                    if let wifiIP = getWiFiAddress(), let port = webServer?.port {
                        let url = URL(string: "http://\(wifiIP):\(port)/")
                        self.serverURL = url
                        print("✅ Casting server fallback started at \(url?.absoluteString ?? "")")
                    } else if let serverURL = webServer?.serverURL {
                        self.serverURL = serverURL
                    }
                } catch {
                    print("❌ Failed to start casting server: \(error)")
                }
            }
        }
    }

    private func determineContentType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "mp4", "m4v", "mov":
            return "video/mp4"
        case "mp3":
            return "audio/mpeg"
        case "m4a", "aac":
            return "audio/mp4"
        case "wav":
            return "audio/wav"
        case "m3u8":
            return "application/x-mpegURL"
        case "ts":
            return "video/mp2t"
        default:
            return "application/octet-stream"
        }
    }

    func stopServer() {
        if let server = webServer, server.isRunning {
            server.stop()
        }
        webServer = nil
        print("Casting server stopped")
    }

    deinit {
        stopServer()
    }
}
