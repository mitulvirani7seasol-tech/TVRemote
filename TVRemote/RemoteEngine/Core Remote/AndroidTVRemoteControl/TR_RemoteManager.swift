//
//  TR_RemoteManager.swift
//  
//
//

import Foundation
import Network
import AVFAudio

//public class TR_RemoteManager {
//    private let stateQueue = DispatchQueue(label: "remote.state")
//    private let remoteQueue = DispatchQueue(label: "remote.connect")
//    private let receiveQueue = DispatchQueue(label: "remote.receive")
//    
//    private var connection: NWConnection?
//    private let tlsManager: TR_TLSManager
//    
//    private var data = Data()
//    private var secondConfigurationResponse = TR_SecondConfigurationResponse()
//    
//    public var stateChanged: ((TR_RemoteState)->())?
//    public var receiveData: ((Data?, Error?)->Void)?
//    public var deviceInfo: TR_CommandNetwork.TR_DeviceInfo
//    
//    public var logger: TR_Logger?
//    private let logPrefix = "Remote: "
//    
//    
//    private var audioPacketBuffer = Data()
//    private let expectedPacketSize = 19800
//    private var audioProcessingQueue = DispatchQueue(label: "AudioProcessingQueue")
//    
//    private let audioEngine = AVAudioEngine()
//    private var isStreaming = false
//    var remoteMessageManager = TR_RemoteMessageManager()
//    var remoteImeBatchEditResponse = TR_Remote_RemoteImeBatchEdit()
//    private var currentSessionID: Int32 = 0
//    
//    private var remoteState: TR_RemoteState = .idle {
//        didSet {
//            let state = remoteState
//            
//            stateQueue.async {
//                switch state {
//                case .error(let error):
//                    self.logger?.errorLog(self.logPrefix + error.localizedDescription)
//                case .connected:
//                    self.logger?.infoLog(self.logPrefix + "connected")
//                case .idle:
//                    self.logger?.infoLog(self.logPrefix + "idle")
//                case .connectionSetUp:
//                    self.logger?.infoLog(self.logPrefix + "connection set up")
//                case .connectionPrepairing:
//                    self.logger?.infoLog(self.logPrefix + "connection preparing")
//                case .fisrtConfigMessageReceived(let info):
//                    self.logger?.infoLog(self.logPrefix + String(format: "fisrt configuration message has been received: %@ %@ %@ %@ %@", info.vendor, info.model, info.appName, info.appBuild, info.version))
//                case .firstConfigSent:
//                    self.logger?.infoLog(self.logPrefix + "fisrt configuration has been sent")
//                case .secondConfigSent:
//                    self.logger?.infoLog(self.logPrefix + "second configuration has been sent")
//                case .paired(runningApp: let runningApp):
//                    self.logger?.infoLog(self.logPrefix + "paired, current running app: " + (runningApp ?? "Unknown"))
//                }
//                
//                self.stateChanged?(state)
//            }
//        }
//    }
//    
//    public init(_ tlsManager: TR_TLSManager, _ deviceInfo: TR_CommandNetwork.TR_DeviceInfo, _ logger: TR_Logger? = nil) {
//        self.tlsManager = tlsManager
//        self.deviceInfo = deviceInfo
//        self.logger = logger
//    }
//    
//    public func connect(_ host: String) {
//        if host.isEmpty {
//            logger?.errorLog(logPrefix + "host shouldn't be empty!")
//        }
//        
//        let tlsParams: NWParameters
//
//        switch tlsManager.getNWParams(remoteQueue) {
//        case .Result(let params):
//            tlsParams = params
//        case .Error(let error):
//            remoteState = .error(error)
//            return
//        }
//        
//        connection = NWConnection(
//            host: NWEndpoint.Host(host),
//            port: NWEndpoint.Port(integerLiteral: 6466),
//            using: tlsParams)
//        
//        connection?.stateUpdateHandler = handleConnectionState
//        logger?.infoLog(logPrefix + "connecting " + host + ":6466")
//        secondConfigurationResponse = TR_SecondConfigurationResponse()
//        connection?.start(queue: remoteQueue)
//    }
//    
//    public func disconnect() {
//        logger?.infoLog(logPrefix + "disconnect")
//        connection?.stateUpdateHandler = nil
//        connection?.cancel()
//        connection = nil
//    }
//    
//    public func send(_ request: TR_RequestDataProtocol) {
//        send(Data(Encoder.encodeVarint(UInt(request.data.count))), request.data)
//    }
//    
//    public func send(_ data: Data, _ nextData: Data? = nil) {
//        logger?.debugLog(logPrefix + "Sending data: \(Array(data))")
//        connection?.send(content: data, completion: .contentProcessed({ [weak self] (error) in
//            guard let `self` = self else {
//                return
//            }
//            
//            if let error = error {
//                self.remoteState = .error(.sendDataError(error))
//                //self.disconnect()
//                return
//            }
//            
//            self.logger?.debugLog(self.logPrefix + "Success sent")
//            if let nextMessage = nextData {
//                self.send(nextMessage)
//            }
//        }))
//    }
//    
//    func sendText(text: String) {
//        let imeCounter = 0
//        let fieldCounter = 0
//        
//        do {
//            let imeBatchEditMessage = try remoteMessageManager.createRemoteImeBatchEdit(
//                text: text,
//                imeCounter: Int32(imeCounter),
//                fieldCounter: Int32(fieldCounter)
//            )
//            
//            self.connection?.send(content: imeBatchEditMessage, completion: .contentProcessed({ error in
//                if let error = error {
//                    print("Error sending IME batch edit: \(error)")
//                }
//            }))
//        } catch {
//            print("Failed to create IME batch edit: \(error)")
//        }
//    }
//    
//    private func handleConnectionState(_ state: NWConnection.State) {
//        switch state {
//        case .setup:
//            remoteState = .connectionSetUp
//        case .waiting(let error):
//            remoteState = .error(.connectionWaitingError(error))
//            disconnect()
//        case .preparing:
//            remoteState = .connectionPrepairing
//        case .ready:
//            remoteState = .connected
//            receive()
//        case .failed(let error):
//            remoteState = .error(.connectionFailed(error))
//            disconnect()
//        case .cancelled:
//            remoteState = .error(.connectionCanceled)
//            disconnect()
//        default:
//            break
//        }
//    }
//    
//    func receive() {
//        guard let conn = connection, conn.state == .ready else { return }
//        
//        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] (data, context, isComplete, error) in
//            guard let self = self else { return }
//            
//            self.receiveQueue.async {
//                self.receiveData?(data, error)
//                
//                if let error = error {
//                    self.logger?.errorLog(self.logPrefix + "Receive error: \(error.localizedDescription)")
//                    self.remoteState = .error(.receiveDataError(error))
//                    return
//                }
//                
//                guard let data = data, !data.isEmpty else {
//                    if isComplete {
//                        self.logger?.infoLog(self.logPrefix + "Connection closed by TR_TV")
//                    } else {
//                        self.receive()
//                    }
//                    return
//                }
//                
//                self.handleReceivedData(data)
//                self.receive()
//            }
//        }
//    }
//    
//    private func handleReceivedData(_ newData: Data) {
//        data.append(newData)
//        
//        while true {
//            guard let (messageLength, lengthBytesCount) = decodeVarint(data) else {
//                break
//            }
//            
//            let totalMessageLength = lengthBytesCount + Int(messageLength)
//            guard data.count >= totalMessageLength else {
//                break
//            }
//            
//            let messageData = data.subdata(in: lengthBytesCount..<totalMessageLength)
//            data.removeSubrange(0..<totalMessageLength)
//            
//            do {
//                let message = try remoteMessageManager.parse(data: messageData)
//                logger?.debugLog("\(logPrefix)Received message: \(message)")
//                
//                if message.hasRemoteConfigure {
//                    logger?.infoLog("\(logPrefix)Received remote configure")
//                    let configureResponse = try remoteMessageManager.createRemoteConfigure()
//                    send(configureResponse)
//                    remoteState = .paired(runningApp: "Home")
//                } else if message.hasRemoteSetActive {
//                    logger?.infoLog("\(logPrefix)Received remote set active")
//                    let setActiveResponse = try remoteMessageManager.createRemoteSetActive(active: 622)
//                    send(setActiveResponse)
//                    remoteState = .paired(runningApp: "Home")
//                } else if message.hasRemotePingRequest {
//                    logger?.infoLog("\(logPrefix)Received ping request")
//                    let pingResponse = try remoteMessageManager.createRemotePingResponse(val1: message.remotePingRequest.val1)
//                    send(pingResponse)
//                    remoteState = .paired(runningApp: "Home")
//                } else if message.hasRemoteImeKeyInject {
//                    let appPackage = message.remoteImeKeyInject.appInfo.appPackage
//                    logger?.infoLog("\(logPrefix)Current app: \(appPackage)")
//                    remoteState = .paired(runningApp: appPackage)
//                } else if message.hasRemoteImeBatchEdit {
//                    remoteImeBatchEditResponse = message.remoteImeBatchEdit
//                    logger?.infoLog("\(logPrefix)Received IME batch edit")
//                } else if message.hasRemoteImeShowRequest {
//                    logger?.infoLog("\(logPrefix)Received IME show request: \(message.remoteImeShowRequest)")
//                } else if message.hasRemoteVoiceBegin {
//                    logger?.infoLog("\(logPrefix)Received voice begin")
//                } else if message.hasRemoteVoicePayload {
//                    logger?.infoLog("\(logPrefix)Received voice payload")
//                } else if message.hasRemoteVoiceEnd {
//                    logger?.infoLog("\(logPrefix)Received voice end")
//                } else if message.hasRemoteStart {
//                    let isPowered = message.remoteStart.started
//                    logger?.infoLog("\(logPrefix)TR_Device powered: \(isPowered)")
//                } else if message.hasRemoteSetVolumeLevel {
//                    let volumeInfo = (
//                        level: message.remoteSetVolumeLevel.volumeLevel,
//                        maximum: message.remoteSetVolumeLevel.volumeMax,
//                        muted: message.remoteSetVolumeLevel.volumeMuted
//                    )
//                    logger?.infoLog("\(logPrefix)Volume changed: \(volumeInfo)")
//                } else if message.hasRemoteSetPreferredAudioDevice {
//                    logger?.infoLog("\(logPrefix)Received set preferred audio device")
//                } else if message.hasRemoteError {
//                    logger?.errorLog("\(logPrefix)Received remote error")
//                } else {
//                    logger?.infoLog("\(logPrefix)Received unknown message type")
//                }
//                
//            } catch {
//                logger?.errorLog("\(logPrefix)Failed to parse message: \(error)")
//            }
//        }
//    }
//    
//    private func decodeVarint(_ data: Data) -> (value: UInt, bytesRead: Int)? {
//        var value: UInt = 0
//        var shift: UInt = 0
//        var bytesRead = 0
//        
//        for byte in data {
//            value |= UInt(byte & 0x7F) << shift
//            shift += 7
//            bytesRead += 1
//            
//            if (byte & 0x80) == 0 {
//                return (value, bytesRead)
//            }
//            
//            if shift >= 64 {
//                return nil
//            }
//        }
//        
//        return nil
//    }
//}
//
//extension TR_RemoteManager {
//    public enum TR_RemoteState {
//        case idle
//        case connectionSetUp
//        case connectionPrepairing
//        case connected
//        case fisrtConfigMessageReceived(TR_CommandNetwork.TR_DeviceInfo)
//        case firstConfigSent
//        case secondConfigSent
//        case paired(runningApp: String?)
//        case error(TR_AndroidTVRemoteControlError)
//    }
//}

public class TR_RemoteManager {
    private let stateQueue = DispatchQueue(label: "remote.state")
    private let remoteQueue = DispatchQueue(label: "remote.connect")
    private let receiveQueue = DispatchQueue(label: "remote.receive")
    
    private var connection: NWConnection?
    private let tlsManager: TR_TLSManager
    
    private var data = Data()
    private var secondConfigurationResponse = TR_SecondConfigurationResponse()
    
    public var stateChanged: ((TR_RemoteState)->())?
    public var receiveData: ((Data?, Error?)->Void)?
    public var deviceInfo: TR_CommandNetwork.TR_DeviceInfo
    
    public var logger: TR_Logger?
    private let logPrefix = "Remote: "
    
    
    private var audioPacketBuffer = Data()
    private let expectedPacketSize = 19800
    private var audioProcessingQueue = DispatchQueue(label: "AudioProcessingQueue")
    
    private let audioEngine = AVAudioEngine()
    private var isStreaming = false
    var remoteMessageManager = TR_RemoteMessageManager()
    var remoteImeBatchEditResponse = TR_Remote_RemoteImeBatchEdit()
    private var currentSessionID: Int32 = 0
    
    private var remoteState: TR_RemoteState = .idle {
        didSet {
            let state = remoteState
            
            stateQueue.async {
                switch state {
                case .error(let error):
                    self.logger?.errorLog(self.logPrefix + error.localizedDescription)
                case .connected:
                    self.logger?.infoLog(self.logPrefix + "connected")
                case .idle:
                    self.logger?.infoLog(self.logPrefix + "idle")
                case .connectionSetUp:
                    self.logger?.infoLog(self.logPrefix + "connection set up")
                case .connectionPrepairing:
                    self.logger?.infoLog(self.logPrefix + "connection preparing")
                case .fisrtConfigMessageReceived(let info):
                    self.logger?.infoLog(self.logPrefix + String(format: "fisrt configuration message has been received: %@ %@ %@ %@ %@", info.vendor, info.model, info.appName, info.appBuild, info.version))
                case .firstConfigSent:
                    self.logger?.infoLog(self.logPrefix + "fisrt configuration has been sent")
                case .secondConfigSent:
                    self.logger?.infoLog(self.logPrefix + "second configuration has been sent")
                case .paired(runningApp: let runningApp):
                    self.logger?.infoLog(self.logPrefix + "paired, current running app: " + (runningApp ?? "Unknown"))
                }
                
                self.stateChanged?(state)
            }
        }
    }
    
    private var currentHost: String = ""
    
    public init(_ tlsManager: TR_TLSManager, _ deviceInfo: TR_CommandNetwork.TR_DeviceInfo, _ logger: TR_Logger? = nil) {
        self.tlsManager = tlsManager
        self.deviceInfo = deviceInfo
        self.logger = logger
    }
    
    public func connect(_ host: String) {
        if host.isEmpty {
            logger?.errorLog(logPrefix + "host shouldn't be empty!")
            return
        }
        self.currentHost = host
        
        let tlsParams: NWParameters

        switch tlsManager.getNWParams(remoteQueue) {
        case .Result(let params):
            tlsParams = params
        case .Error(let error):
            remoteState = .error(error)
            return
        }
        
        connection?.cancel()
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: 6466),
            using: tlsParams)
        
        connection?.stateUpdateHandler = handleConnectionState
        logger?.infoLog(logPrefix + "connecting " + host + ":6466")
        secondConfigurationResponse = TR_SecondConfigurationResponse()
        connection?.start(queue: remoteQueue)
    }
    
    public func reconnectIfNeeded() {
        guard !currentHost.isEmpty else { return }
        if connection == nil || connection?.state != .ready {
            logger?.infoLog(logPrefix + "Reconnecting to \(currentHost)...")
            connect(currentHost)
        }
    }
    
    public func disconnect() {
        logger?.infoLog(logPrefix + "disconnect")
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
    }
    
    public func send(_ request: TR_RequestDataProtocol) {
        send(Data(Encoder.encodeVarint(UInt(request.data.count))), request.data)
    }
    
    public func send(_ data: Data, _ nextData: Data? = nil) {
        if connection == nil, !currentHost.isEmpty {
            connect(currentHost)
        }
        
        logger?.debugLog(logPrefix + "Sending data: \(Array(data))")
        connection?.send(content: data, completion: .contentProcessed({ [weak self] (error) in
            guard let self = self else {
                return
            }
            
            if let error = error {
                self.logger?.errorLog(self.logPrefix + "Send data error: \(error)")
                self.remoteState = .error(.sendDataError(error))
                return
            }
            
            self.logger?.debugLog(self.logPrefix + "Success sent")
            if let nextMessage = nextData {
                self.send(nextMessage)
            }
        }))
    }
    
    func sendText(text: String) {
        if connection == nil, !currentHost.isEmpty {
            connect(currentHost)
        }
        
        guard connection != nil else {
            print("⚠️ Cannot send text: connection is nil")
            return
        }
        
        let imeCounter = remoteImeBatchEditResponse.imeCounter
        let fieldCounter = remoteImeBatchEditResponse.fieldCounter
        
        do {
            let imeBatchEditMessage = try remoteMessageManager.createRemoteImeBatchEdit(
                text: text,
                imeCounter: Int32(imeCounter),
                fieldCounter: Int32(fieldCounter)
            )
            
            self.connection?.send(content: imeBatchEditMessage, completion: .contentProcessed({ error in
                if let error = error {
                    print("Error sending IME batch edit: \(error)")
                }
            }))
        } catch {
            print("Failed to create IME batch edit: \(error)")
        }
    }
    
    public func sendAppLink(url: String) {
        if connection == nil, !currentHost.isEmpty {
            connect(currentHost)
        }
        
        guard connection != nil else {
            print("⚠️ Cannot send app link: connection is nil")
            return
        }
        
        do {
            let data = try remoteMessageManager.createRemoteAppLinkLaunchRequest(app_link: url)
            self.connection?.send(content: data, completion: .contentProcessed({ [weak self] error in
                if let error = error {
                    print("Error sending app link launch request: \(error)")
                    self?.reconnectIfNeeded()
                } else {
                    print("✅ Sent app link: \(url)")
                }
            }))
        } catch {
            print("Failed to create app link launch request: \(error)")
        }
    }
    
    public func sendKey(keyCode: TR_Remote_RemoteKeyCode, direction: TR_Remote_RemoteDirection = .short) {
        if connection == nil, !currentHost.isEmpty {
            connect(currentHost)
        }
        
        do {
            let keyData = try remoteMessageManager.createRemoteKeyInject(direction: direction, keyCode: keyCode)
            self.connection?.send(content: keyData, completion: .contentProcessed({ [weak self] error in
                if let error = error {
                    print("Error sending key inject: \(error)")
                    self?.reconnectIfNeeded()
                } else {
                    print("✅ Sent key inject: \(keyCode)")
                }
            }))
        } catch {
            print("Failed to create key inject: \(error)")
        }
    }
    
    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .setup:
            remoteState = .connectionSetUp
        case .waiting(let error):
            remoteState = .error(.connectionWaitingError(error))
        case .preparing:
            remoteState = .connectionPrepairing
        case .ready:
            remoteState = .connected
            receive()
        case .failed(let error):
            remoteState = .error(.connectionFailed(error))
            connection = nil
        case .cancelled:
            remoteState = .error(.connectionCanceled)
            connection = nil
        default:
            break
        }
    }
    
    func receive() {
        guard let conn = connection, conn.state == .ready else { return }
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] (data, context, isComplete, error) in
            guard let self = self else { return }
            
            if let error = error {
                self.logger?.errorLog(self.logPrefix + "Receive error: \(error)")
                return
            }
            
            if let data = data, !data.isEmpty {
                self.receiveQueue.async {
                    self.receiveData?(data, error)
                    self.handleReceivedData(data)
                }
            }
            
            if !isComplete && error == nil {
                self.receive()
            }
        }
    }
    
    private func handleData() {
        logger?.debugLog(logPrefix + "handle: \(Array(data))")
        if handlePing() {
            receive()
            return
        }
        
        switch remoteState {
        case .connected:
            guard let configMessage = TR_CommandNetwork.TR_AndroidTVConfigurationMessage(data) else {
                logger?.debugLog(logPrefix + "it's not configuration message")
                receive()
                return
            }
            
            data.removeAll()
            remoteState = .fisrtConfigMessageReceived(configMessage.deviceInfo)
            
            secondConfigurationResponse.modelName = configMessage.deviceInfo.model
            
            logger?.debugLog(logPrefix + "Sending first configuration request")
            send(TR_CommandNetwork.TR_FirstConfigurationRequest(deviceInfo: deviceInfo))
            remoteState = .firstConfigSent
            receive()
            
        case .firstConfigSent:
            guard TR_CommandNetwork.TR_FirstConfigurationResponse(data: data).isSuccess else {
                logger?.debugLog(logPrefix + "it's not first configuration response")
                receive()
                return
            }
            
            logger?.debugLog(logPrefix + "first configuration response was received")
            data.removeAll()
            logger?.debugLog(logPrefix + "Sending second configuration request")
            send(TR_CommandNetwork.TR_SecondConfigurationRequest())
            remoteState = .secondConfigSent
            receive()
            
        case .secondConfigSent:
            guard secondConfigurationResponse.parse(data) else {
                logger?.debugLog(logPrefix + "it's not second configuration response")
                receive()
                return
            }
            
            if secondConfigurationResponse.currentAppPart {
                logger?.debugLog(logPrefix + "second configuration response CURRENT APP - OK")
            }
            
            if secondConfigurationResponse.powerPart {
                logger?.debugLog(logPrefix + "second configuration response POWER - OK")
            }
            
            if secondConfigurationResponse.volumeLevelPart {
                logger?.debugLog(logPrefix + "second configuration response VOLUME LEVEL - OK")
            }
            
            data.removeAll()
            guard secondConfigurationResponse.readyFullResponse else {
                receive()
                return
            }
            
            remoteState = .paired(runningApp: secondConfigurationResponse.runAppName)
            receive()
        default:
            logger?.debugLog(logPrefix + "unrecognized data")
            if TR_VolumeLevel(data) != nil {
                data.removeAll()
            }
            receive()
            return
        }
    }
    
    private func handlePing() -> Bool {
        guard let ping = TR_CommandNetwork.TR_Ping.extract(from: data) else {
            return false
        }
        
        logger?.debugLog(logPrefix + "ping has bin handled")
        data.removeAll()
        let pong = TR_CommandNetwork.TR_Pong(ping.val1)
        logger?.debugLog(logPrefix + "sending pong")
        send(pong.data)
        return true
    }
    
    private func handleReceivedData(_ newData: Data) {
        data.append(newData)
        
        while true {
            guard let (messageLength, lengthBytesCount) = decodeVarint(data) else {
                break
            }
            
            let totalMessageLength = lengthBytesCount + Int(messageLength)
            guard data.count >= totalMessageLength else {
                break
            }
            
            let messageData = data.subdata(in: lengthBytesCount..<totalMessageLength)
            data.removeSubrange(0..<totalMessageLength)
            
            do {
                let message = try remoteMessageManager.parse(data: messageData)
                logger?.debugLog("\(logPrefix)Received message: \(message)")
                
                if message.hasRemoteConfigure {
                    logger?.infoLog("\(logPrefix)Received remote configure")
                    let configureResponse = try remoteMessageManager.createRemoteConfigure()
                    send(configureResponse)
                } else if message.hasRemoteSetActive {
                    logger?.infoLog("\(logPrefix)Received remote set active")
                    let setActiveResponse = try remoteMessageManager.createRemoteSetActive(active: 622)
                    send(setActiveResponse)
                } else if message.hasRemotePingRequest {
                    logger?.infoLog("\(logPrefix)Received ping request")
                    let pingResponse = try remoteMessageManager.createRemotePingResponse(val1: message.remotePingRequest.val1)
                    send(pingResponse)
                } else if message.hasRemoteImeKeyInject {
                    let appPackage = message.remoteImeKeyInject.appInfo.appPackage
                    logger?.infoLog("\(logPrefix)Current app: \(appPackage)")
                    remoteState = .paired(runningApp: appPackage)
                } else if message.hasRemoteImeBatchEdit {
                    remoteImeBatchEditResponse = message.remoteImeBatchEdit
                    logger?.infoLog("\(logPrefix)Received IME batch edit")
                } else if message.hasRemoteImeShowRequest {
                    logger?.infoLog("\(logPrefix)Received IME show request: \(message.remoteImeShowRequest)")
                } else if message.hasRemoteVoiceBegin {
                    logger?.infoLog("\(logPrefix)Received voice begin")
                } else if message.hasRemoteVoicePayload {
                    logger?.infoLog("\(logPrefix)Received voice payload")
                } else if message.hasRemoteVoiceEnd {
                    logger?.infoLog("\(logPrefix)Received voice end")
                } else if message.hasRemoteStart {
                    let isPowered = message.remoteStart.started
                    logger?.infoLog("\(logPrefix)TR_Device powered: \(isPowered)")
                } else if message.hasRemoteSetVolumeLevel {
                    let volumeInfo = (
                        level: message.remoteSetVolumeLevel.volumeLevel,
                        maximum: message.remoteSetVolumeLevel.volumeMax,
                        muted: message.remoteSetVolumeLevel.volumeMuted
                    )
                    logger?.infoLog("\(logPrefix)Volume changed: \(volumeInfo)")
                } else if message.hasRemoteSetPreferredAudioDevice {
                    logger?.infoLog("\(logPrefix)Received set preferred audio device")
                } else if message.hasRemoteError {
                    logger?.errorLog("\(logPrefix)Received remote error (app not found or unhandled intent)")
                } else {
                    logger?.infoLog("\(logPrefix)Received unknown message type")
                }
                
            } catch {
                logger?.errorLog("\(logPrefix)Failed to parse message: \(error)")
                data.removeAll()
                break
            }
        }
    }
    
    private func decodeVarint(_ data: Data) -> (value: UInt, bytesRead: Int)? {
        var value: UInt = 0
        var shift: UInt = 0
        var bytesRead = 0
        
        for byte in data {
            value |= UInt(byte & 0x7F) << shift
            shift += 7
            bytesRead += 1
            
            if (byte & 0x80) == 0 {
                return (value, bytesRead)
            }
            
            if shift >= 64 {
                return nil
            }
        }
        
        return nil
    }
}

extension TR_RemoteManager {
    public enum TR_RemoteState {
        case idle
        case connectionSetUp
        case connectionPrepairing
        case connected
        case fisrtConfigMessageReceived(TR_CommandNetwork.TR_DeviceInfo)
        case firstConfigSent
        case secondConfigSent
        case paired(runningApp: String?)
        case error(TR_AndroidTVRemoteControlError)
    }
}
