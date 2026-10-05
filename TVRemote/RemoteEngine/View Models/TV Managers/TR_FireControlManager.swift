//
//  FireTVManager.swift
//  TR_TV Remote
//
//  Created by IOS Developer on 09/09/2025.
//

import Foundation
import Security
import Network
import Combine

class TR_FireControlManager: NSObject, ObservableObject, URLSessionDelegate {
    private var networkSession: URLSession!
    @Published var availableApps: [TR_FireTVApplication] = []
    @Published var connectionStatus: Bool = false
    var deviceIP: String
    
    init(ipAddress: String) {
        self.deviceIP = ipAddress
        super.init()
        configureNetworkSession()
    }
    
    private func configureNetworkSession() {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 60
        sessionConfig.timeoutIntervalForResource = 60

        networkSession = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
    }

    // Add the URLSessionDelegate method here
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
    
    func verifyInitialConnection(showPin: @escaping (Bool) -> Void) {
        CleanUpOnDisconnect()
        resetNetworkSession()
        
        guard !deviceIP.isEmpty else {
            print("checkFirstTime: IP address is empty")
            return
        }

        let url = URL(string: "http://\(deviceIP):8009/apps/FireTVRemote")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data()

        networkSession.dataTask(with: request) { data, response, error in
            if let error = error {
                print("checkFirstTime failed: \(error.localizedDescription), trying establishConnection directly")
                self.establishConnection(showPin: showPin)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("checkFirstTime: Invalid response, trying establishConnection directly")
                self.establishConnection(showPin: showPin)
                return
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                print("verifyInitialConnection succeeded with status code \(httpResponse.statusCode)")
                self.establishConnection(showPin: showPin)
            } else {
                print("verifyInitialConnection non-200 status code: \(httpResponse.statusCode), continuing to establishConnection")
                self.establishConnection(showPin: showPin)
            }
        }.resume()
    }

    func establishConnection(showPin: @escaping (Bool) -> Void) {
        if let clientToken = retrieveClientToken(), !clientToken.isEmpty {
            validateToken(clientToken: clientToken) { isValid in
                if isValid {
                    DispatchQueue.main.async { showPin(false) }
                } else {
                    self.requestPinDisplay(showPin: showPin)
                }
            }
        } else {
            requestPinDisplay(showPin: showPin)
        }
    }

    private func validateToken(clientToken: String, completion: @escaping (Bool) -> Void) {
        guard !deviceIP.isEmpty else {
            completion(false)
            return
        }

        let url = URL(string: "https://\(deviceIP):8080/v1/FireTV")!
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("0987654321", forHTTPHeaderField: "x-api-key")
        request.addValue(clientToken, forHTTPHeaderField: "x-client-token")

        networkSession.dataTask(with: request) { data, response, error in
            if let error = error {
                print("checkTokenValidity failed: \(error.localizedDescription)")
                completion(false)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false)
                return
            }

            if httpResponse.statusCode == 200 {
                self.connectionStatus = true
                self.retrieveApplications()
                completion(true)
            } else {
                print("checkTokenValidity failed with status code: \(httpResponse.statusCode)")
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("Response body: \(responseBody)")
                }
                self.connectionStatus = false
                completion(false)
            }
        }.resume()
    }

    func requestPinDisplay(showPin: @escaping (Bool) -> Void) {
        guard !deviceIP.isEmpty else {
            return
        }

        let jsonObject: [String: Any] = ["friendlyName": "Fire Stick Remote"]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) else {
            return
        }

        let url = URL(string: "https://\(deviceIP):8080/v1/FireTV/pin/display")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("0987654321", forHTTPHeaderField: "x-api-key")

        networkSession.dataTask(with: request) { data, response, error in
            if let error = error {
                print("displayPin failed: \(error.localizedDescription)")
                DispatchQueue.main.async { showPin(true) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async { showPin(true) }
                return
            }

            if httpResponse.statusCode == 200 {
                print("displayPin: Success - PIN should appear on the TR_TV")
                DispatchQueue.main.async { showPin(true) }
            } else {
                print("displayPin status code: \(httpResponse.statusCode)")
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("Response body: \(responseBody)")
                }
                DispatchQueue.main.async { showPin(true) }
            }
        }.resume()
    }

    func verifyPin(pinCode: String, callback: @escaping (String) -> Void) {
        guard !deviceIP.isEmpty else {
            callback("Invalid IP Address")
            return
        }

        let jsonObject: [String: Any] = ["pin": pinCode]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) else {
            callback("Invalid PIN Format")
            return
        }

        let url = URL(string: "https://\(deviceIP):8080/v1/FireTV/pin/verify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("0987654321", forHTTPHeaderField: "x-api-key")

        networkSession.dataTask(with: request) { data, response, error in
            if let error = error {
                callback("Network Error: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                callback("Invalid Server Response")
                return
            }

            if httpResponse.statusCode == 200 {
                if let data = data, let responseJson = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    let description = responseJson["description"] as? String ?? "Unknown"
                    print("verifyPin: Success - \(description)")
                    if let token = responseJson["description"] as? String {
                        self.saveClientToken(token)
                    }
                    callback("Pairing Successful")
                } else {
                    callback("Pairing Successful")
                }
                print("Pairing Successful")
                self.connectionStatus = true
                self.retrieveApplications()
                
            } else {
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("Response body: \(responseBody)")
                }
                callback("Pairing Failed (TR_Status Code: \(httpResponse.statusCode))")
                self.connectionStatus = false
            }
        }.resume()
    }

    func retrieveApplications() {
        guard let clientToken = retrieveClientToken(), !clientToken.isEmpty else {
            return
        }

        let url = URL(string: "https://\(deviceIP):8080/v1/FireTV/apps")!
        var request = URLRequest(url: url)
        request.addValue("0987654321", forHTTPHeaderField: "x-api-key")
        request.addValue(clientToken, forHTTPHeaderField: "x-client-token")

        networkSession.dataTask(with: request) { data, response, error in
            if let error = error {
                print("fetchApps failed: \(error.localizedDescription)")
                return
            }

            guard let data = data, let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                print("fetchApps failed with status code: \(String(describing: response))")
                return
            }

            if let jsonArray = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                var fetchedApps: [TR_FireTVApplication] = []
                for jsonObject in jsonArray {
                    let app = TR_FireTVApplication(
                        identifier: jsonObject["appId"] as? String ?? "",
                        title: jsonObject["name"] as? String ?? "",
                        iconURL: jsonObject["iconArtSmallUri"] as? String ?? "",
                        isAvailable: jsonObject["isInstalled"] as? Bool ?? false
                    )
                    fetchedApps.append(app)
                }

                DispatchQueue.main.async {
                    self.availableApps = fetchedApps
                }
            }
        }.resume()
    }

    func launchApplication(appId: String, completion: @escaping (String) -> Void) {
        guard !deviceIP.isEmpty else {
            completion("Invalid IP Address")
            return
        }
        
        if let app = availableApps.first(where: { $0.identifier == appId }) {
            let url = URL(string: "https://\(deviceIP):8080/v1/FireTV/app/\(appId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("0987654321", forHTTPHeaderField: "x-api-key")
            
            if let clientToken = retrieveClientToken(), !clientToken.isEmpty {
                request.addValue(clientToken, forHTTPHeaderField: "x-client-token")
            }
            
            // Send the request to launch the app
            networkSession.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("launchApp failed: \(error.localizedDescription)")
                    completion("Network Error: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("launchApp: No valid HTTP response")
                    completion("Invalid Server Response")
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    print("launchApp: Success")
                    completion("App Launched Successfully")
                } else {
                    print("launchApp failed with status code: \(httpResponse.statusCode)")
                    if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                        print("Response body: \(responseBody)")
                    }
                    completion("App Launch Failed (TR_Status Code: \(httpResponse.statusCode))")
                }
            }.resume()
        } else {
            completion("App not found")
        }
    }

    func launchAppOnRemote(appId: String, completion: @escaping (String) -> Void) {
        guard !deviceIP.isEmpty else {
            completion("Invalid IP Address")
            return
        }
        
        guard let url = URL(string: "https://\(deviceIP):8080/v1/FireTV/app/\(appId)") else {
            completion("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("0987654321", forHTTPHeaderField: "x-api-key")
        
        if let clientToken = retrieveClientToken(), !clientToken.isEmpty {
            request.addValue(clientToken, forHTTPHeaderField: "x-client-token")
        } else {
            completion("Missing or Invalid Client Token")
            return
        }
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error launching app: \(error.localizedDescription)")
                completion("Error: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion("No valid HTTP response")
                return
            }
            
            if httpResponse.statusCode == 200 {
                completion("App launched successfully!")
            } else {
                let errorMessage = "Failed to launch app (TR_Status Code: \(httpResponse.statusCode))"
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("Error details: \(responseBody)")
                }
                completion(errorMessage)
            }
        }.resume()
    }
    
    func saveClientToken(_ token: String) {
        TR_AppUtils.instance.saveString(key: TR_RemoteConstants.userToken, value: token)
    }
    
    func retrieveClientToken() -> String? {
        return TR_AppUtils.instance.getString(key: TR_RemoteConstants.userToken)
    }

    func FireKeyPress(action: String, key: String, completion: @escaping (String) -> Void) {
        guard let clientToken = retrieveClientToken() else {
            completion("Client Token is missing")
            return
        }

        guard let url = URL(string: "https://\(deviceIP):8080/v1/FireTV?action=\(action)") else {
            completion("Invalid URL")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("0987654321", forHTTPHeaderField: "x-api-key")
        request.addValue(clientToken, forHTTPHeaderField: "x-client-token")

        if !key.isEmpty {
            let jsonObject: [String: Any] = ["keyActionType": key]
            if let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) {
                request.httpBody = jsonData
            } else {
                completion("Failed to create JSON data")
                return
            }
        }

        print("fireCommand: URL - \(url.absoluteString)")
        if let body = request.httpBody {
            print("fireCommand: Body - \(String(data: body, encoding: .utf8) ?? "Invalid JSON")")
        }

        networkSession.dataTask(with: request) { data, response, error in
            if let error = error {
                print("fireCommand failed: \(error.localizedDescription)")
                completion("Network Error: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("fireCommand: No valid HTTP response")
                completion("Invalid Server Response")
                return
            }

            if httpResponse.statusCode == 200 {
                print("fireCommand: Success")
                completion("TR_Command Successful")
            } else {
                print("fireCommand failed with status code: \(httpResponse.statusCode)")
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("Response body: \(responseBody)")
                }
                completion("TR_Command Failed (TR_Status Code: \(httpResponse.statusCode))")
            }
        }.resume()
    }
    
    func PerformKeyPress(keyAction: TR_FireTVKeys) {
        let actionString = "sendKey"
        let keyString = keyAction.rawValue
        
        FireKeyPress(action: keyString, key: "") { response in
            print("Response: \(response)")
        }
    }
    
    
    func sendSearchTextInput(action: String, completion: @escaping (String) -> Void) {
        print("Received action: \(action), key: \(action)")

        guard !deviceIP.isEmpty else {
            completion("IP Address is empty")
            return
        }

        guard let clientToken = retrieveClientToken() else {
            completion("Client Token is missing")
            return
        }

        guard let url = URL(string: "https://\(deviceIP):8080/v1/FireTV/text") else {
            completion("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue("0987654321", forHTTPHeaderField: "x-api-key") // Static API key
        request.addValue(clientToken, forHTTPHeaderField: "x-client-token") // Dynamic client token

        if !action.isEmpty {
            let jsonObject: [String: Any] = ["text": action]
            if let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) {
                request.httpBody = jsonData
            } else {
                completion("Failed to create JSON data")
                return
            }
        }

        print("fireCommand: URL - \(url.absoluteString)")
        if let body = request.httpBody {
            print("fireCommand: Body - \(String(data: body, encoding: .utf8) ?? "Invalid JSON")")
        }

        networkSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion("Network Error: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion("Invalid Server Response")
                return
            }

            if httpResponse.statusCode == 200 {
                completion("TR_Command Successful")
            } else {
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("Response body: \(responseBody)")
                }
                completion("TR_Command Failed (TR_Status Code: \(httpResponse.statusCode))")
            }
        }.resume()
    }

    func Disconnect() {
        networkSession?.invalidateAndCancel()
        connectionStatus = false
        TR_AppUtils.instance.saveString(key: TR_RemoteConstants.userToken, value: "")
    }
    
    func CleanUpOnDisconnect() {
        self.networkSession = nil
        self.availableApps = []
        self.connectionStatus = false
        TR_AppUtils.instance.saveString(key: TR_RemoteConstants.userToken, value: "")
    }

    func resetNetworkSession() {
        self.networkSession?.invalidateAndCancel()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 60
        self.networkSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
}



