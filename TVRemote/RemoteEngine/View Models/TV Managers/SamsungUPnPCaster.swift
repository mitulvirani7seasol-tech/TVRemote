//
//  SamsungUPnPCaster.swift
//  TV Remote
//
//  Created by iOS Developer on 19/09/2026.
//

import Foundation

class SamsungUPnPCaster {
    static let shared = SamsungUPnPCaster()
    
    private var lastUsedControlURL: [String: URL] = [:]
    private var lastUsedRenderingURL: [String: URL] = [:]
    
    // Candidate UPnP AVTransport control endpoints on Samsung TVs
    private func candidateControlURLs(ip: String) -> [URL] {
        var urls: [URL] = []
        if let cached = lastUsedControlURL[ip] {
            urls.append(cached)
        }
        let candidates = [
            "http://\(ip):9197/upnp/control/AVTransport1",
            "http://\(ip):7676/smp_4_",
            "http://\(ip):7676/smp_17_",
            "http://\(ip):7676/smp_18_",
            "http://\(ip):8001/upnp/control/AVTransport1"
        ]
        for c in candidates {
            if let url = URL(string: c), !urls.contains(url) {
                urls.append(url)
            }
        }
        return urls
    }
    
    private func candidateRenderingURLs(ip: String) -> [URL] {
        var urls: [URL] = []
        if let cached = lastUsedRenderingURL[ip] {
            urls.append(cached)
        }
        let candidates = [
            "http://\(ip):9197/upnp/control/RenderingControl1",
            "http://\(ip):7676/smp_7_",
            "http://\(ip):7676/smp_8_",
            "http://\(ip):8001/upnp/control/RenderingControl1"
        ]
        for c in candidates {
            if let url = URL(string: c), !urls.contains(url) {
                urls.append(url)
            }
        }
        return urls
    }
    
    // MARK: - Cast Media (Photo, Video, Music)
    func castMedia(
        tvIP: String,
        mediaURL: URL,
        mimeType: String,
        title: String = "Media",
        completion: ((Bool) -> Void)? = nil
    ) {
        let isImage = mimeType.lowercased().contains("image") || mimeType.lowercased().contains("jpeg") || mimeType.lowercased().contains("jpg") || mimeType.lowercased().contains("png")
        let isAudio = mimeType.lowercased().contains("audio") || mimeType.lowercased().contains("mp3") || mimeType.lowercased().contains("m4a") || mimeType.lowercased().contains("wav")
        
        let upnpClass: String
        let dlnaProtocol: String
        
        if isImage {
            upnpClass = "object.item.imageItem.photo"
            dlnaProtocol = "http-get:*:image/jpeg:DLNA.ORG_PN=JPEG_LRG;DLNA.ORG_OP=01;DLNA.ORG_FLAGS=00D00000000000000000000000000000"
        } else if isAudio {
            upnpClass = "object.item.audioItem.musicTrack"
            let audioMime = mimeType.lowercased().contains("mp3") ? "audio/mpeg" : "audio/mp4"
            dlnaProtocol = "http-get:*:\(audioMime):DLNA.ORG_OP=01;DLNA.ORG_FLAGS=01700000000000000000000000000000"
        } else {
            upnpClass = "object.item.videoItem"
            dlnaProtocol = "http-get:*:video/mp4:DLNA.ORG_PN=AVC_MP4_HP_HD_AAC;DLNA.ORG_OP=01;DLNA.ORG_FLAGS=01700000000000000000000000000000"
        }
        
        let escapedMediaURL = mediaURL.absoluteString.replacingOccurrences(of: "&", with: "&amp;")
        let cleanTitle = title.replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "&", with: "&amp;")
        
        let didlMetadata = """
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">
          <item id="1" parentID="0" restricted="0">
            <dc:title>\(cleanTitle)</dc:title>
            <upnp:class>\(upnpClass)</upnp:class>
            <res protocolInfo="\(dlnaProtocol)">\(escapedMediaURL)</res>
          </item>
        </DIDL-Lite>
        """
        
        let escapedDIDL = didlMetadata
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        
        let soapBody = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <InstanceID>0</InstanceID>
              <CurrentURI>\(escapedMediaURL)</CurrentURI>
              <CurrentURIMetaData>\(escapedDIDL)</CurrentURIMetaData>
            </u:SetAVTransportURI>
          </s:Body>
        </s:Envelope>
        """
        
        print("📡 Samsung UPnP: Sending SetAVTransportURI to \(tvIP) for URL: \(mediaURL)")
        
        sendSoapCommandWithFallback(
            ip: tvIP,
            action: "SetAVTransportURI",
            serviceType: "urn:schemas-upnp-org:service:AVTransport:1",
            body: soapBody
        ) { [weak self] success, workingURL in
            guard let self = self else { return }
            if success {
                print("✅ Samsung UPnP: SetAVTransportURI succeeded on \(workingURL?.absoluteString ?? "")")
                if let workingURL = workingURL {
                    self.lastUsedControlURL[tvIP] = workingURL
                }
                
                // Immediately send Play command for video/audio (and ensure images trigger display)
                self.play(tvIP: tvIP) { _ in
                    completion?(true)
                }
            } else {
                print("❌ Samsung UPnP: SetAVTransportURI failed on all candidate endpoints")
                completion?(false)
            }
        }
    }
    
    // MARK: - Play
    func play(tvIP: String, completion: ((Bool) -> Void)? = nil) {
        let soapBody = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <InstanceID>0</InstanceID>
              <Speed>1</Speed>
            </u:Play>
          </s:Body>
        </s:Envelope>
        """
        
        sendSoapCommandWithFallback(
            ip: tvIP,
            action: "Play",
            serviceType: "urn:schemas-upnp-org:service:AVTransport:1",
            body: soapBody
        ) { success, _ in
            completion?(success)
        }
    }
    
    // MARK: - Pause
    func pause(tvIP: String, completion: ((Bool) -> Void)? = nil) {
        let soapBody = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:Pause xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <InstanceID>0</InstanceID>
            </u:Pause>
          </s:Body>
        </s:Envelope>
        """
        
        sendSoapCommandWithFallback(
            ip: tvIP,
            action: "Pause",
            serviceType: "urn:schemas-upnp-org:service:AVTransport:1",
            body: soapBody
        ) { success, _ in
            completion?(success)
        }
    }
    
    // MARK: - Stop
    func stop(tvIP: String, completion: ((Bool) -> Void)? = nil) {
        let soapBody = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:Stop xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <InstanceID>0</InstanceID>
            </u:Stop>
          </s:Body>
        </s:Envelope>
        """
        
        sendSoapCommandWithFallback(
            ip: tvIP,
            action: "Stop",
            serviceType: "urn:schemas-upnp-org:service:AVTransport:1",
            body: soapBody
        ) { success, _ in
            completion?(success)
        }
    }
    
    // MARK: - Seek
    func seek(tvIP: String, seconds: TimeInterval, completion: ((Bool) -> Void)? = nil) {
        let targetTime = formatTime(seconds)
        let soapBody = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:Seek xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <InstanceID>0</InstanceID>
              <Unit>REL_TIME</Unit>
              <Target>\(targetTime)</Target>
            </u:Seek>
          </s:Body>
        </s:Envelope>
        """
        
        sendSoapCommandWithFallback(
            ip: tvIP,
            action: "Seek",
            serviceType: "urn:schemas-upnp-org:service:AVTransport:1",
            body: soapBody
        ) { success, _ in
            completion?(success)
        }
    }
    
    // MARK: - SOAP Dispatch Helper with Endpoint Fallback
    private func sendSoapCommandWithFallback(
        ip: String,
        action: String,
        serviceType: String,
        body: String,
        completion: @escaping (Bool, URL?) -> Void
    ) {
        let candidates = candidateControlURLs(ip: ip)
        tryNextCandidate(index: 0, candidates: candidates, action: action, serviceType: serviceType, body: body, completion: completion)
    }
    
    private func tryNextCandidate(
        index: Int,
        candidates: [URL],
        action: String,
        serviceType: String,
        body: String,
        completion: @escaping (Bool, URL?) -> Void
    ) {
        guard index < candidates.count else {
            completion(false, nil)
            return
        }
        
        let endpoint = candidates[index]
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("\"\(serviceType)#\(action)\"", forHTTPHeaderField: "SOAPACTION")
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("close", forHTTPHeaderField: "Connection")
        request.httpBody = body.data(using: .utf8)
        request.timeoutInterval = 3.0
        
        let smSoapDataTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let http = response as? HTTPURLResponse, (http.statusCode == 200 || http.statusCode == 204) {
                completion(true, endpoint)
                return
            }
            
            // Try next candidate endpoint
            self?.tryNextCandidate(
                index: index + 1,
                candidates: candidates,
                action: action,
                serviceType: serviceType,
                body: body,
                completion: completion
            )
        }
        smSoapDataTask.resume()
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let sec = s % 60
        let min = (s / 60) % 60
        let hr = s / 3600
        return String(format: "%02d:%02d:%02d", hr, min, sec)
    }
}
