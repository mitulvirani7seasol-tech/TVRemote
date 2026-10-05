//
//  TR_RokuControlManager.swift
//  TR_TV Remote
//
//  Created by IOS Developer on 09/09/2025.
//

import Foundation
import Combine

class TR_RokuControlManager: NSObject, ObservableObject {
    @Published var availableApps: [String] = []
    @Published var connectionStatus = false
    private var ip: String = "192.168.0.1"
    
    override init() {
        super.init()
    }
    
    func SelectRoku(_ rokuIP: String) {
        self.ip = rokuIP
        connectionStatus = true
        RetrieveApps()
    }
    
    func RetrieveApps() {
        FetchApps { [weak self] ids in
            DispatchQueue.main.async {
                self?.availableApps = ids
            }
        }
    }
    
    func getAppImageUrl(id: String) -> String {
        ensureValidIP()
        return "\(ip)/query/icon/\(id)"
    }

    func launchApp(_ id: String) {
        Stroke(fullRequest: "launch/\(id)")
    }

    func sendKeyboardInput(_ input: String) {
        if input.isEmpty {
            TR_KeyPress(key: .KEYCODE_BACKSPACE)
        } else if input == " " {
            Stroke(fullRequest: "keypress/Lit_%20")
        } else {
            for char in input {
                let charStr = String(char)
                if charStr == " " {
                    Stroke(fullRequest: "keypress/Lit_%20")
                } else if let encoded = charStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    Stroke(fullRequest: "keypress/Lit_\(encoded)")
                } else {
                    Stroke(fullRequest: "keypress/Lit_\(charStr)")
                }
            }
        }
    }

    private func ensureValidIP() {
        if !ip.contains("http") {
            ip = "http://\(ip):8060/"
        }
    }

    func TR_KeyPress(key: TR_RokuRemoteKeys) {
        Stroke(fullRequest: "keypress/\(key.rawValue)")
    }

    func Stroke(fullRequest: String) {
        ensureValidIP()
        if let url = URL(string: ip + fullRequest) {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            URLSession.shared.dataTask(with: req).resume()
        }
    }

    func FetchApps(completion: @escaping ([String]) -> Void) {
        ensureValidIP()
        guard let url = URL(string: ip + "query/apps") else { return }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: req) { (data, res, err) in
            guard let data = data,
                  let dataString = String(data: data, encoding: .utf8) else { return }
            
            do {
                let regex = try NSRegularExpression(pattern: "id=\"[^\"]*\"", options: .caseInsensitive)
                
                let matches = regex.matches(in: dataString, options: [], range: NSRange(dataString.startIndex..., in: dataString))
                
                let strs = matches.compactMap { match -> String? in
                    if let range = Range(match.range, in: dataString) {
                        let matchStr = String(dataString[range])
                        return matchStr.split(separator: "\"").dropFirst().first.map { String($0) }
                    }
                    return nil
                }
                
                DispatchQueue.main.async {
                    completion(strs)
                }
            } catch {
                print("Regex error: \(error)")
            }
        }.resume()
    }
    
    func Disconnect() {
        self.connectionStatus = false
        self.ip = ""
    }
}


