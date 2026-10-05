//
//  TR_LGControlManager.swift
//  TR_TV Remote
//
//  Created by IOS Developer on 09/09/2025.
//

import Foundation
import ConnectSDK
import Combine

class TR_LGControlManager: NSObject {
    var selectedDevice: ConnectableDevice?
    @Published var connectionStatus = false
    @Published var availableApps: [AppInfo] = []
    @Published var isMuted = false
    var connectedDevice: ConnectableDevice?
    var onDisconnectOrFailure: (() -> Void)?
    var onPairingRequired: ((DeviceServicePairingType) -> Void)?
    var onPairingSuccess: (() -> Void)?
    private var textInputSubscription: ServiceSubscription?
    
    func connectLG(device: ConnectableDevice) {
        disconnectFromTV()
        connectedDevice = device
        selectedDevice = device
        device.setPairingType(DeviceServicePairingTypePinCode)
        device.delegate = self
        device.connect()
    }
    
    func sendPairingKey(_ key: String) {
        print("🔐 LG Sending Pairing TR_Key: \(key)")
        guard let device = selectedDevice, let services = device.services as? [DeviceService], !services.isEmpty else {
            print("⚠️ LG sendPairingKey: no selected device or services")
            DispatchQueue.main.async {
                TR_RemoteViewModel.shared.showProgress = false
                TR_RemoteViewModel.shared.showPinDialog = false
                TR_RemoteViewModel.shared.pinCode = ""
                TR_RemoteViewModel.shared.incorrectPinTrigger = UUID()
            }
            return
        }
        
        var attempted = false
        let sel = NSSelectorFromString("sendPairingKey:success:failure:")
        
        for service in services {
            if service.responds(to: sel) {
                attempted = true
                let successBlock: @convention(block) ([AnyHashable: Any]?) -> Void = { [weak self] _ in
                    print("✅ LG WebOS pairing key accepted")
                    DispatchQueue.main.async {
                        self?.onPairingSuccess?()
                    }
                }
                let failureBlock: @convention(block) (Error?) -> Void = { error in
                    print("❌ LG WebOS pairing key error: \(error?.localizedDescription ?? "Unknown error")")
                    DispatchQueue.main.async {
                        TR_RemoteViewModel.shared.showProgress = false
                        TR_RemoteViewModel.shared.showPinDialog = false
                        TR_RemoteViewModel.shared.pinCode = ""
                        TR_RemoteViewModel.shared.incorrectPinTrigger = UUID()
                    }
                }
                
                typealias SendPairingKeyFunc = @convention(c) (AnyObject, Selector, NSString, AnyObject, AnyObject) -> Void
                let methodIMP = service.method(for: sel)
                let callable = unsafeBitCast(methodIMP, to: SendPairingKeyFunc.self)
                callable(service, sel, key as NSString, successBlock as AnyObject, failureBlock as AnyObject)
            } else if let netcast = service as? NetcastTVService {
                attempted = true
                netcast.pair(withData: key)
            } else if service.responds(to: NSSelectorFromString("pairWithData:")) {
                attempted = true
                service.pair(withData: key)
            }
        }
        
        if !attempted {
            print("⚠️ LG sendPairingKey: no matching pairing service found")
            DispatchQueue.main.async {
                TR_RemoteViewModel.shared.showProgress = false
                TR_RemoteViewModel.shared.showPinDialog = false
                TR_RemoteViewModel.shared.pinCode = ""
                TR_RemoteViewModel.shared.incorrectPinTrigger = UUID()
            }
        }
    }
    
    func disconnectFromTV() {
        textInputSubscription?.unsubscribe()
        textInputSubscription = nil
        selectedDevice?.disconnect()
        selectedDevice = nil
        connectionStatus = false
    }
    
    func getWebOSTVService() -> WebOSTVService? {
        guard let services = selectedDevice?.services as? [DeviceService] else { return nil }
        return services.first(where: { $0 is WebOSTVService }) as? WebOSTVService
    }
    
    func sendSSAPCommand(target: String, payload: [String: Any]? = nil, success: (([AnyHashable: Any]?) -> Void)? = nil, failure: ((Error?) -> Void)? = nil) {
        guard let webosService = getWebOSTVService(), let socket = webosService.socket, let url = URL(string: target) else {
            failure?(NSError(domain: "TR_LGControlManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "WebOS socket unavailable"]))
            return
        }
        let command = ServiceCommand(delegate: socket, target: url, payload: payload as AnyObject?)
        if let success = success {
            command?.callbackComplete = { res in
                success(res as? [AnyHashable: Any])
            }
        }
        command?.callbackError = failure
        command?.send()
    }
    
    func setupKeyboardSubscription() {
        guard let textControl = selectedDevice?.textInputControl() else {
            print("⚠️ LG textInputControl not available for subscription")
            sendSSAPCommand(target: "ssap://com.webos.service.ime/registerRemoteKeyboard")
            return
        }
        textInputSubscription?.unsubscribe()
        textInputSubscription = textControl.subscribeTextInputStatus(success: { status in
            print("⌨️ LG Text Input TR_Status subscribed: \(String(describing: status))")
        }, failure: { [weak self] error in
            print("⚠️ LG Text Input Subscribe failed: \(error?.localizedDescription ?? ""), registering via SSAP")
            self?.sendSSAPCommand(target: "ssap://com.webos.service.ime/registerRemoteKeyboard")
        })
    }
    
    func fetchInstalledApps() {
        guard let launcher = selectedDevice?.launcher() else {
            print("App launcher is not available.")
            return
        }
        launcher.getAppList(success: { [weak self] apps in
            guard let self = self, let allApps = apps as? [AppInfo] else {
                print("Failed to cast apps to [AppInfo]")
                return
            }
            
            let inputPortsOnly = allApps.filter { app in
                guard let appId = app.id?.lowercased(),
                      let appName = app.name?.lowercased() else { return false }
                
                // 1. STAGE 1: ABSOLUTE BLACKLIST (Instantly drops the remaining system noise)
                let strictExclusions = [
                    "overlay", "liveplus", "inputcommon", "plus",
                    "screensaver", "screen saver", "exampleapp", ".nav"
                ]
                if strictExclusions.contains(where: { appId.contains($0) || appName.contains($0) }) {
                    return false
                }
                
                // 2. STAGE 2: STRICT SELECTION (Isolates genuine hardware ports)
                let isHDMI = appId.contains("hdmi") || appName.contains("hdmi")
                
                // Fixed the partial string matching loop bug (.nav matching av)
                let isAV = appId.contains("externalinput.av") ||
                appId.contains("input_av") ||
                appName == "av" ||
                appName.hasPrefix("av ") ||
                appName.hasPrefix("av1") ||
                appName.hasPrefix("av2")
                
                return isHDMI || isAV
            }
            DispatchQueue.main.async {
                // Sort them cleanly so your UI reads: AV, AV1, AV2, HDMI1...
                self.availableApps = inputPortsOnly.sorted { ($0.name ?? "") < ($1.name ?? "") }
                
                print("🔌 Final Locked Count: \(self.availableApps.count)")
                print("Available Ports: \(self.availableApps.map { $0.name ?? "Unknown" }.joined(separator: ", "))")
            }
            
        }, failure: { error in
            print("Failed to fetch apps: \(error?.localizedDescription ?? "Unknown Error")")
        })
    }
    
    
    
    func sendCommand(_ key: TR_LGRemoteKeys) {
        switch key {
        case .KEYCODE_CHANNEL_UP:
            selectedDevice?.tvControl()?.channelUp(success: { _ in
                print("TR_Channel Up Success")},
                                                   failure: { error in
                print("TR_Channel Up Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_CHANNEL_DOWN:
            selectedDevice?.tvControl()?.channelDown(success: { _ in
                print("TR_Channel Down Success") },
                                                     failure: { error in
                print("TR_Channel Down Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_VOLUME_UP:
            selectedDevice?.volumeControl()?.volumeUp(success: { _ in
                print("Volume Up Success") },
                                                      failure: { error in
                print("Volume Up Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_VOLUME_DOWN:
            selectedDevice?.volumeControl()?.volumeDown(success: { _ in
                print("Volume Down Success") },
                                                        failure: { error in
                print("Volume Down Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_MUTE:
            let newMuteState = !isMuted
            selectedDevice?.volumeControl()?.setMute(newMuteState, success: { _ in
                DispatchQueue.main.async {
                    self.isMuted = newMuteState
                }
                print(newMuteState ? "Mute Success" : "Unmute Success")
            }, failure: { error in
                print("Mute Toggle Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_POWER:
            selectedDevice?.powerControl()?.powerOff(success: { _ in
                print("Power Off Success") },
                                                     failure: { error in
                print("Power Off Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_DPAD_UP:
            selectedDevice?.keyControl()?.up(success: { _ in
                print("Navigate Up Success") },
                                             failure: { error in
                print("Navigate Up Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_DPAD_DOWN:
            selectedDevice?.keyControl()?.down(success: { _ in
                print("Navigate Down Success") },
                                               failure: { error in
                print("Navigate Down Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_DPAD_LEFT:
            selectedDevice?.keyControl()?.left(success: { _ in
                print("Navigate Left Success") },
                                               failure: { error in
                print("Navigate Left Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_DPAD_RIGHT:
            selectedDevice?.keyControl()?.right(success: { _ in
                print("Navigate Right Success") },
                                                failure: { error in
                print("Navigate Right Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_OK:
            selectedDevice?.keyControl()?.ok(success: { _ in
                print("Select (OK) Success") },
                                             failure: { error in
                print("Select (OK) Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_HOME:
            selectedDevice?.keyControl()?.home(success: { _ in
                print("Home Success") },
                                               failure: { error in
                print("Home Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_BACK:
            selectedDevice?.keyControl()?.back(success: { _ in
                print("Back Success") },
                                               failure: { error in
                print("Back Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_PLAY:
            selectedDevice?.mediaControl()?.play(success: { _ in
                print("Play Success") },
                                                 failure: { error in
                print("Play Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_PAUSE:
            selectedDevice?.mediaControl()?.pause(success: { _ in
                print("Pause Success") },
                                                  failure: { error in
                print("Pause Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_FAST_FORWARD:
            selectedDevice?.mediaControl()?.fastForward(success: { _ in
                print("Fast Forward Success") },
                                                        failure: { error in
                print("Fast Forward Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_REWIND:
            selectedDevice?.mediaControl()?.rewind(success: { _ in
                print("Rewind Success") },
                                                   failure: { error in
                print("Rewind Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_STOP:
            selectedDevice?.mediaControl()?.stop(success: { _ in
                print("Stop Success") },
                                                 failure: { error in
                print("Stop Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
            
        case .KEYCODE_BACKSPACE:
            if let textControl = selectedDevice?.textInputControl() {
                textControl.sendDelete(success: { _ in
                    print("Delete Success")
                }, failure: { [weak self] error in
                    print("Delete Failed: \(error?.localizedDescription ?? "Unknown Error")")
                    self?.sendSSAPCommand(target: "ssap://com.webos.service.ime/deleteCharacters", payload: ["count": 1])
                })
            } else {
                sendSSAPCommand(target: "ssap://com.webos.service.ime/deleteCharacters", payload: ["count": 1])
            }
        case .KEYCODE_MENU:
            selectedDevice?.keyControl()?.home(success: { _ in
                print("Menu Success") },
                                               failure: { error in
                print("Home Failed: \(error?.localizedDescription ?? "Unknown Error")")
            })
        case .KEYCODE_SEARCH:
            launchSearch()
        }
    }
    
    func launchSearch() {
        print("🔍 Launching LG WebOS Search...")
        let searchAppIds = ["com.webos.app.search", "com.webos.app.discovery"]
        
        func tryLaunchApp(index: Int) {
            guard index < searchAppIds.count else {
                print("⚠️ LG launchApp fallback: sending SSAP launch search command")
                sendSSAPCommand(target: "ssap://system.launcher/launch", payload: ["id": "com.webos.app.search"], success: { _ in
                    print("✅ LG SSAP search launched successfully")
                }, failure: { [weak self] _ in
                    self?.sendSSAPCommand(target: "ssap://system.launcher/launch", payload: ["id": "com.webos.app.discovery"])
                })
                return
            }
            
            let appId = searchAppIds[index]
            selectedDevice?.launcher()?.launchApp(appId, success: { _ in
                print("✅ LG Search app launched successfully: \(appId)")
            }, failure: { error in
                print("⚠️ LG Search app (\(appId)) launch failed: \(error?.localizedDescription ?? ""), trying next")
                tryLaunchApp(index: index + 1)
            })
        }
        
        tryLaunchApp(index: 0)
    }

    func launchYouTubeWithQuery(_ query: String) {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            LaunchYoutube()
            return
        }
        let youtubeUrl = "https://www.youtube.com/results?search_query=\(encoded)"
        print("🔍 LG Launching YouTube Search with query: \(query)")
        
        let appInfo = AppInfo()
        appInfo.id = "youtube.leanback.v4"
        selectedDevice?.launcher()?.launchApp(with: appInfo, params: ["contentId": youtubeUrl], success: { _ in
            print("✅ LG YouTube search opened directly with URL")
        }, failure: { [weak self] _ in
            self?.LaunchApp(url: "youtube.leanback.v4")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self?.keyboard(input: query)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.sendEnter()
                }
            }
        })
    }
    
    func LaunchYoutube() {
        selectedDevice?.launcher()?.launchYouTube("https://www.youtube.com/", success: {_ in
            print("Back Success")
        }, failure: { error in
            print("Back Failed: \(error?.localizedDescription ?? "Unknown Error")")
        })
    }
    
    func LauchNetfliz() {
        selectedDevice?.launcher()?.launchNetflix("https://www.netflix.com/", success: {_ in
            print("Back Success")
        }, failure: { error in
            print("Back Failed: \(error?.localizedDescription ?? "Unknown Error")")
        })
    }
    
    func LauchPrime() {
        selectedDevice?.launcher()?.launchApp("amazon", success: {_ in
            print("Back Success")
        }, failure: { error in
            print("Back Failed: \(error?.localizedDescription ?? "Unknown Error")")
        })
    }
    
    func LaunchApp(url: String) {
        selectedDevice?.launcher()?.launchApp(url, success: {_ in
            print("Back Success")
        }, failure: { error in
            print("Back Failed: \(error?.localizedDescription ?? "Unknown Error")")
        })
    }
    
    func launchBrowser(url: URL) {
        selectedDevice?.launcher()?.launchBrowser(url, success: { _ in
            print("✅ LG WebOS Browser launched with URL: \(url)")
        }, failure: { error in
            print("❌ LG WebOS Browser launch failed: \(error?.localizedDescription ?? "Unknown error")")
        })
    }
    
    func launchBrowser(urlString: String) {
        if let url = URL(string: urlString) {
            launchBrowser(url: url)
        }
    }
    
    func keyboard(input: String) {
        guard !input.isEmpty else { return }
        print("⌨️ LG Typing: '\(input)'")
        
        if textInputSubscription == nil {
            setupKeyboardSubscription()
        }
        
        if let textControl = selectedDevice?.textInputControl() {
            textControl.sendText(input, success: { _ in
                print("✅ LG sendText Success: \(input)")
            }, failure: { [weak self] error in
                print("⚠️ LG sendText failed: \(error?.localizedDescription ?? ""), trying direct SSAP insertText")
                self?.sendSSAPCommand(target: "ssap://com.webos.service.ime/insertText", payload: ["text": input, "replace": 0], success: { _ in
                    print("✅ LG SSAP insertText Success: \(input)")
                }, failure: { err in
                    print("❌ LG SSAP insertText failed: \(err?.localizedDescription ?? "")")
                })
            })
        } else {
            sendSSAPCommand(target: "ssap://com.webos.service.ime/insertText", payload: ["text": input, "replace": 0])
        }
    }
    
    func sendEnter() {
        print("⌨️ LG Sending Enter")
        if let textControl = selectedDevice?.textInputControl() {
            textControl.sendEnter(success: { _ in
                print("✅ LG sendEnter Success")
            }, failure: { [weak self] error in
                print("⚠️ LG sendEnter Failed: \(error?.localizedDescription ?? ""), trying direct SSAP sendEnterKey")
                self?.sendSSAPCommand(target: "ssap://com.webos.service.ime/sendEnterKey", success: { _ in
                    print("✅ LG SSAP sendEnterKey Success")
                }, failure: { [weak self] _ in
                    self?.sendCommand(.KEYCODE_OK)
                })
            })
        } else {
            sendSSAPCommand(target: "ssap://com.webos.service.ime/sendEnterKey", success: nil, failure: { [weak self] _ in
                self?.sendCommand(.KEYCODE_OK)
            })
        }
    }
    
    func sendDelete() {
        print("⌨️ LG Sending Delete/Backspace")
        if let textControl = selectedDevice?.textInputControl() {
            textControl.sendDelete(success: { _ in
                print("✅ LG sendDelete Success")
            }, failure: { [weak self] error in
                print("⚠️ LG sendDelete Failed: \(error?.localizedDescription ?? ""), trying direct SSAP deleteCharacters")
                self?.sendSSAPCommand(target: "ssap://com.webos.service.ime/deleteCharacters", payload: ["count": 1], success: { _ in
                    print("✅ LG SSAP deleteCharacters Success")
                }, failure: { [weak self] _ in
                    self?.sendCommand(.KEYCODE_BACKSPACE)
                })
            })
        } else {
            sendSSAPCommand(target: "ssap://com.webos.service.ime/deleteCharacters", payload: ["count": 1], success: nil, failure: { [weak self] _ in
                self?.sendCommand(.KEYCODE_BACKSPACE)
            })
        }
    }
    
    func movePointer(dx: Float, dy: Float) {
        guard let mouse = selectedDevice?.mouseControl() else {
            print("⚠️ Mouse control not available")
            return
        }
        
        let vector = CGVector(dx: CGFloat(dx), dy: CGFloat(dy))
        
        mouse.move(vector, success: nil, failure: { error in
            print("❌ Move failed: \(error?.localizedDescription ?? "Unknown")")
        })
    }
    
    func clickPointer() {
        guard let mouse = selectedDevice?.mouseControl() else {
            print("⚠️ Mouse control not available")
            return
        }
        
        mouse.click(success: nil, failure: { error in
            print("❌ Click failed: \(error?.localizedDescription ?? "Unknown")")
        })
    }
    
    func scrollPointer(dx: Float, dy: Float) {
        guard let mouse = selectedDevice?.mouseControl() else {
            print("⚠️ Mouse control not available")
            return
        }
        
        let vector = CGVector(dx: CGFloat(dx), dy: CGFloat(dy))
        
        mouse.scroll(vector, success: nil, failure: { error in
            print("❌ Scroll failed: \(error?.localizedDescription ?? "Unknown")")
        })
    }
    
    func sendNumber(_ number: String) {
        let netcastMapping: [String: UInt] = [
            "0": 2, "1": 3, "2": 4, "3": 5, "4": 6,
            "5": 7, "6": 8, "7": 9, "8": 10, "9": 11
        ]
        if let code = netcastMapping[number] {
            selectedDevice?.keyControl()?.sendKeyCode(code, success: { _ in
                print("LG sendKeyCode Success: \(number)")
            }, failure: { error in
                print("LG sendKeyCode Failed: \(error?.localizedDescription ?? "")")
            })
        }
        
        keyboard(input: number)
    }
}

extension TR_LGControlManager: ConnectableDeviceDelegate {
    func connectableDeviceReady(_ device: ConnectableDevice) {
        DispatchQueue.main.async {
            self.selectedDevice = device
            self.connectionStatus = true
            self.fetchInstalledApps()
            self.setupKeyboardSubscription()
            self.onPairingSuccess?()
        }
    }
    
    func connectableDeviceDisconnected(_ device: ConnectableDevice, withError error: Error?) {
        DispatchQueue.main.async {
            self.resetLGPairingState()
            self.onDisconnectOrFailure?()
            print("TR_Device disconnected: \(error?.localizedDescription ?? "No Error Info")")
        }
    }
    
    func connectableDevice(_ device: ConnectableDevice, service: DeviceService, pairingRequiredOfType pairingType: Int32, withData pairingData: Any?) {
        DispatchQueue.main.async {
            print("🔐 LG pairingRequiredOfType: \(pairingType)")
            let pType = DeviceServicePairingType(rawValue: UInt32(pairingType))
            self.onPairingRequired?(pType)
        }
    }
    
    func connectableDevicePairingSuccess(_ device: ConnectableDevice, service: DeviceService) {
        DispatchQueue.main.async {
            print("✅ LG Pairing Success for service: \(service.serviceName ?? "")")
            self.selectedDevice = device
            self.connectionStatus = true
            self.fetchInstalledApps()
            self.setupKeyboardSubscription()
            self.onPairingSuccess?()
        }
    }
    
    func connectableDevice(
        _ device: ConnectableDevice,
        service: DeviceService,
        pairingFailedWithError error: Error?
    ) {
        DispatchQueue.main.async {
            self.resetLGPairingState()
            self.onDisconnectOrFailure?()
            print("LG pairing failed/cancelled: \(error?.localizedDescription ?? "No Error Info")")
            TR_RemoteViewModel.shared.showProgress = false
            TR_RemoteViewModel.shared.showPinDialog = false
            TR_RemoteViewModel.shared.pinCode = ""
            TR_RemoteViewModel.shared.incorrectPinTrigger = UUID()
        }
    }

    func connectableDevice(
        _ device: ConnectableDevice,
        service: DeviceService,
        disconnectedWithError error: Error?
    ) {
        DispatchQueue.main.async {
            self.resetLGPairingState()
            print("LG service disconnected: \(error?.localizedDescription ?? "No Error Info")")
            self.onDisconnectOrFailure?()
        }
    }

    func connectableDevice(
        _ device: ConnectableDevice,
        service: DeviceService,
        didFailConnectWithError error: Error?
    ) {
        DispatchQueue.main.async {
            self.resetLGPairingState()
            print("LG service failed: \(error?.localizedDescription ?? "No Error Info")")
            self.onDisconnectOrFailure?()
        }
    }

    private func resetLGPairingState() {
        self.connectionStatus = false
        self.selectedDevice = nil
    }
}

