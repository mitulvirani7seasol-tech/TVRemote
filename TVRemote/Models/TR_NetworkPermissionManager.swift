//
//  TR_NetworkPermissionManager.swift
//  ScreenNova
//
//  Created by Vivek Rakholiya on 21/08/26.
//

import Foundation
import Network

final class TR_NetworkPermissionManager {
    
    static let shared = TR_NetworkPermissionManager()
    private init() {}
    
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.screennova.networkMonitor")
    private var currentPath: NWPath?
    
    private var browser: NWBrowser?
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.currentPath = path
        }
        monitor.start(queue: monitorQueue)
    }
    
    /// WiFi/Internet ON hai ya nahi
    var isInternetAvailable: Bool {
        return currentPath?.status == .satisfied
    }
    
    /// Local Network permission granted hai ya nahi — kDNSServiceErr_PolicyDenied specifically check karta hai
    func checkLocalNetworkPermission(completion: @escaping (Bool) -> Void) {
        
        // Previous browser properly stop karo
        browser?.cancel()
        browser = nil
        
        var didComplete = false
        
        let params = NWParameters()
        params.includePeerToPeer = true
        
        let newBrowser = NWBrowser(
            for: .bonjour(type: "_googlecast._tcp", domain: nil),
            using: params
        )
        
        self.browser = newBrowser
        
        newBrowser.stateUpdateHandler = { state in
            
            guard !didComplete else { return }
            
            switch state {
            case .ready:
                didComplete = true
                newBrowser.cancel()
                print("✅ Local Network Permission Authorized")
                completion(true)
                
            case .failed(let error):
                print("❌ Browser Failed:", error)
                
                if case NWError.dns(let dnsError) = error,
                   dnsError == kDNSServiceErr_PolicyDenied {
                    didComplete = true
                    newBrowser.cancel()
                    print("❌ Local Network Permission Denied")
                    completion(false)
                }
                
            case .waiting(let error):
                print("⏳ Waiting:", error)
                
                if case NWError.dns(let dnsError) = error,
                   dnsError == kDNSServiceErr_PolicyDenied {
                    didComplete = true
                    newBrowser.cancel()
                    print("❌ Local Network Permission Denied")
                    completion(false)
                }
                
            default:
                break
            }
        }
        
        newBrowser.start(queue: monitorQueue)
        
        // Safety fallback timeout — agar koi state update hi na aaye
        monitorQueue.asyncAfter(deadline: .now() + 3.0) {
            if !didComplete {
                didComplete = true
                newBrowser.cancel()
                print("⏳ Timeout — treating as denied")
                completion(false)
            }
        }
    }
    
    func stopChecking() {
        browser?.cancel()
        browser = nil
        monitor.cancel()
    }
    
    deinit {
        stopChecking()
    }
}
