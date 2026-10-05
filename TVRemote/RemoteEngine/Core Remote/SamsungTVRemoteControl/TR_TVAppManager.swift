//
//  TR_TVAppManager.swift
//  TV Remote Casting
//
//  Created by Parthiv Akbari on 02/05/26.
//

import Foundation

public protocol TR_TVAppManaging {
    func fetchStatus(for tvApp: TR_TVApp, tvIPAddress: String) async throws -> TR_TVAppStatus
    func launch(tvApp: TR_TVApp, tvIPAddress: String) async throws
    func fetchInstalledApps(tvIPAddress: String) async throws -> [TR_TVApp]
}

enum TR_TVAppManagerError: LocalizedError {
    case badURL(description: String)
    case noData
    case networkError(description: String)
    
    var errorDescription: String? {
        switch self {
        case .badURL(let description):
            return "Bad URL: \(description)"
        case .noData:
            return "No data received from the network."
        case .networkError(let description):
            return "Network error: \(description)"
        }
    }
}

public class TR_TVAppManager: TR_TVAppManaging {
    public static let shared = TR_TVAppManager()
    private let urlBuilder: TR_TVAppURLBuilder
    private let networkManager: TR_TVAppNetworkManaging
    private let decoder: TR_TVAppDecoding
    
    private let popularAppIds: [String: String] = [
        // ✅ The ones already working for you
        "11101200001": "Netflix",               // Global Netflix
        "3201907018807": "Netflix Alternative", // Variant Netflix
        "3201512006785": "Prime Video",         // Primary Prime
        "3201910019365": "Prime Video Alternate",
        "3201807016597": "Apple TR_TV",
        "3201606009684": "Spotify",
        "111299001912": "YouTube",
        
        // 🇮🇳 DISNEY+ HOTSTAR
        "3202009021709": "Disney+ Hotstar",
        "3202204027038": "Disney+ Hotstar",
        "3201504001966": "Disney+ Hotstar",   // Core Indian Hotstar ID
        "3201901017640": "Disney+",           // Global Fallback
        "111399002203": "Disney+ Alt",
        
        // 🇮🇳 SONY LIV
        "3201601007625": "Sony LIV",          // Core Indian Sony LIV ID
        "3201412000622": "Sony LIV Legacy",
        "111299001150": "Sony LIV Alt",
        
        // 📡 SAMSUNG TR_TV PLUS (True application runtime ID)
        "com.samsung.dtv.tvplus": "Samsung TR_TV Plus",
        
        // 🏠 SMARTTHINGS (Official Tizen Operating System App ID)
//        "3201710015016": "SmartThings", // 🚀 Explicit App Framework instead of menu panel
//        "3201910019378": "SmartThings", // 🚀 Explicit App Framework instead of menu panel
//        "com.samsung.bixby.tv": "Bixby",        // Voice Shell Interface
        
        // 🌐 SAMSUNG INTERNET BROWSER (Firmware Variations)
        "2011120000049": "Browser Internet",  // Standard Tizen Web Browser
        "111299002016": "Browser Alt",        // Alternative Samsung Internet
        "org.tizen.browser": "Browser",       // Core System package
        "3201907018784": "Browser Modern",     // 2020+ TVs
        
        // 🔌 SAMSUNG INPUT PORTS & SOURCES
        "com.samsung.dtv.hdmi1": "HDMI 1",
        "com.samsung.dtv.hdmi2": "HDMI 2",
        "com.samsung.dtv.hdmi3": "HDMI 3",
        "com.samsung.dtv.hdmi4": "HDMI 4",
        "com.samsung.dtv.av": "AV Input",
        "com.samsung.dtv.component": "Component"
    ]
    
    public init(
        urlBuilder: TR_TVAppURLBuilder = TR_TVAppURLBuilder(),
        networkManager: TR_TVAppNetworkManaging = TR_TVAppNetworkManager(),
        decoder: TR_TVAppDecoder = TR_TVAppDecoder()
    ) {
        self.urlBuilder = urlBuilder
        self.networkManager = networkManager
        self.decoder = decoder
    }
    
    public func fetchStatus(for tvApp: TR_TVApp, tvIPAddress: String) async throws -> TR_TVAppStatus {
        let url = try buildURL(tvApp: tvApp, tvIPAddress: tvIPAddress)
        guard let data = try await networkManager.sendRequest(url: url) else {
            throw TR_TVAppManagerError.noData
        }
        return try decoder.decodeAppStatus(from: data)
    }
    
    public func launch(tvApp: TR_TVApp, tvIPAddress: String) async throws {
        let url = try buildURL(tvApp: tvApp, tvIPAddress: tvIPAddress)
        try await networkManager.sendRequest(url: url, method: "POST")
    }
    
    public func launchBrowser(url: URL, tvIPAddress: String) async throws {
        let browserIds = ["org.tizen.browser", "2011120000049", "3201907018784", "111299002016"]
        for appId in browserIds {
            if let endpoint = URL(string: "http://\(tvIPAddress):8001/api/v2/applications/\(appId)") {
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: Any] = ["url": url.absoluteString]
                if let jsonData = try? JSONSerialization.data(withJSONObject: body) {
                    request.httpBody = jsonData
                }
                if let (_, resp) = try? await URLSession.shared.data(for: request),
                   let httpResp = resp as? HTTPURLResponse, (httpResp.statusCode == 200 || httpResp.statusCode == 201) {
                    print("✅ Samsung TR_TV browser launched with url \(url)")
                    return
                }
            }
        }
    }
    
    private func buildURL(tvApp: TR_TVApp, tvIPAddress: String) throws -> URL {
        if let url = urlBuilder.buildURL(tvIPAddress: tvIPAddress, tvAppId: tvApp.id) {
            return url
        } else {
            throw TR_TVAppManagerError.badURL(description: "Unable to build URL for IP: \(tvIPAddress)")
        }
    }
    
    public func fetchInstalledApps(tvIPAddress: String) async throws -> [TR_TVApp] {
        var availableApps: [TR_TVApp] = []
        
        try await withThrowingTaskGroup(of: TR_TVApp?.self) { group in
            for (appId, appName) in popularAppIds {
                group.addTask {
                    do {
                        let dummyApp = TR_TVApp(id: appId, name: appName)
                        _ = try await self.fetchStatus(for: dummyApp, tvIPAddress: tvIPAddress)
                        return dummyApp
                    } catch let error as TR_TVAppNetworkError {
                        // 🟢 KEY FIX: If it is explicitly 404, the app is not installed
                        if error == .appNotFound {
                            return nil
                        }
                        // If it returns an invalid response (like 403 Forbidden), the app exists!
                        return TR_TVApp(id: appId, name: appName)
                    } catch {
                        // If it's an SSL/network block but NOT a 404, assume the app is there
                        return TR_TVApp(id: appId, name: appName)
                    }
                }
            }
            
            for try await app in group {
                if let verifiedApp = app {
                    availableApps.append(verifiedApp)
                }
            }
        }
        
        // Clean up variants to maintain beautiful titles in your SwiftUI collection view
        var uniqueApps: [String: TR_TVApp] = [:]
        for app in availableApps {
            let cleanName: String
            let lowercaseName = app.name.lowercased()
            
            if lowercaseName.contains("netflix") { cleanName = "Netflix" }
            else if lowercaseName.contains("prime") { cleanName = "Prime Video" }
            else if lowercaseName.contains("disney") || lowercaseName.contains("hotstar") { cleanName = "Disney+" }
            else if lowercaseName.contains("liv") { cleanName = "Sony LIV" }
            else if lowercaseName.contains("plus") { cleanName = "Samsung TR_TV Plus" }
//            else if lowercaseName.contains("smartthings") { cleanName = "SmartThings" }
//            else if lowercaseName.contains("bixby") { cleanName = "Bixby" }
            else { cleanName = app.name }
            
            if uniqueApps[cleanName] == nil {
                uniqueApps[cleanName] = TR_TVApp(id: app.id, name: cleanName)
            }
        }
        
        // 🌐 ABSOLUTE CORE HARDWARE GUARANTEES
        if uniqueApps["Browser"] == nil {
            uniqueApps["Browser"] = TR_TVApp(id: "org.tizen.browser", name: "Browser")
        }
        if uniqueApps["Samsung TR_TV Plus"] == nil {
            uniqueApps["Samsung TR_TV Plus"] = TR_TVApp(id: "com.samsung.dtv.tvplus", name: "TR_TV Plus")
        }
//        if uniqueApps["SmartThings"] == nil {
//            uniqueApps["SmartThings"] = TR_TVApp(id: "3201910019378", name: "SmartThings")
//        }
//        if uniqueApps["Bixby"] == nil {
//            uniqueApps["Bixby"] = TR_TVApp(id: "com.samsung.bixby.tv", name: "Bixby")
//        }
        
        
        let result = Array(uniqueApps.values).sorted(by: { $0.name < $1.name })
        return result.isEmpty ? TR_TVApp.allApps() : result
    }
}

// MARK: - Build App URL
public protocol TR_TVAppURLBuilding {
    func buildURL(tvIPAddress: String, tvAppId: String) -> URL?
}

public class TR_TVAppURLBuilder: TR_TVAppURLBuilding {
    public init() {}
    
    public func buildURL(tvIPAddress: String, tvAppId: String) -> URL? {
        var components = URLComponents()
        components.scheme = "http"
        components.host = tvIPAddress
        components.port = 8001
        components.path = "/api/v2/applications/\(tvAppId)"
        return components.url
    }
}

// MARK: - Send HTTP Request
public protocol TR_TVAppNetworkManaging {
    @discardableResult
    func sendRequest(url: URL, method: String) async throws -> Data?
}

extension TR_TVAppNetworkManaging {
    func sendRequest(url: URL) async throws -> Data? {
        try await sendRequest(url: url, method: "GET")
    }
}

enum TR_TVAppNetworkError: LocalizedError {
    case appNotFound
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .appNotFound:
            return "App Not Found"
        case .invalidResponse:
            return "Invalid Response"
        }
    }
}

public class TR_TVAppNetworkManager: TR_TVAppNetworkManaging {
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func sendRequest(url: URL, method: String) async throws -> Data? {
        var request = URLRequest(url: url)
        request.httpMethod = method
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        return data
    }
    
    private func validate(response: URLResponse) throws {
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200:
            return
        case 404:
            throw TR_TVAppNetworkError.appNotFound
        default:
            throw TR_TVAppNetworkError.invalidResponse
        }
    }
}

// MARK: Decode App TR_Status
public protocol TR_TVAppDecoding {
    func decodeAppStatus(from data: Data) throws -> TR_TVAppStatus
    func decodeInstalledApps(from data: Data) throws -> [TR_TVApp]
}

public class TR_TVAppDecoder: TR_TVAppDecoding {
    private let decoder: JSONDecoder
    
    public init(decoder: JSONDecoder = .init()) {
        self.decoder = decoder
    }
    
    public func decodeAppStatus(from data: Data) throws -> TR_TVAppStatus {
        try decoder.decode(TR_TVAppStatus.self, from: data)
    }
    
    public func decodeInstalledApps(from data: Data) throws -> [TR_TVApp] {
        let response = try decoder.decode(TR_TVInstalledAppsResponse.self, from: data)
        return response.installedApp.map { $0.toTVApp }
    }
}
