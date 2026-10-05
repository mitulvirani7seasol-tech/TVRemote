//
//  TR_TVCommander.swift
//
//
//

import Foundation
import Network
import Starscream

public protocol TR_TVCommanderDelegate: AnyObject {
    func tvCommanderDidConnect(_ tvCommander: TR_TVCommander)
    func tvCommanderDidDisconnect(_ tvCommander: TR_TVCommander)
    func tvCommander(_ tvCommander: TR_TVCommander, didUpdateAuthState authStatus: TR_TVAuthStatus)
    func tvCommander(_ tvCommander: TR_TVCommander, didWriteRemoteCommand command: TR_TVRemoteCommand)
    func tvCommander(_ tvCommander: TR_TVCommander, didEncounterError error: TR_TVCommanderError)
}

public class TR_TVCommander: WebSocketDelegate {
    public weak var delegate: TR_TVCommanderDelegate?
    private(set) public var tvConfig: TR_TVConnectionConfiguration
    private(set) public var authStatus = TR_TVAuthStatus.none
    private(set) public var isConnected = false
    private let webSocketCreator: TR_TVWebSocketCreator
    private let webSocketHandler = TR_TVWebSocketHandler()
    private var webSocket: Starscream.WebSocket?
    private var commandQueue = [TR_TVRemoteCommand]()

    init(tvConfig: TR_TVConnectionConfiguration, webSocketCreator: TR_TVWebSocketCreator) {
        self.tvConfig = tvConfig
        self.webSocketCreator = webSocketCreator
        self.webSocketHandler.delegate = self
    }

    public convenience init(tvId: String? = nil, tvIPAddress: String, appName: String, authToken: TR_TVAuthToken? = nil) throws {
        guard appName.isValidAppName else {
            throw TR_TVCommanderError.invalidAppNameEntered
        }
        guard tvIPAddress.isValidIPAddress else {
            throw TR_TVCommanderError.invalidIPAddressEntered
        }
        let tvConfig = TR_TVConnectionConfiguration(
            id: tvId,
            app: appName,
            path: "/api/v2/channels/samsung.remote.control",
            ipAddress: tvIPAddress,
            port: 8002,
            scheme: "wss",
            token: authToken
        )
        self.init(tvConfig: tvConfig, webSocketCreator: TR_TVWebSocketCreator())
    }

    public convenience init(tv: TR_TV, appName: String, authToken: TR_TVAuthToken? = nil) throws {
        guard let ipAddress = tv.ipAddress else { throw TR_TVCommanderError.invalidIPAddressEntered }
        try self.init(tvId: tv.id, tvIPAddress: ipAddress, appName: appName, authToken: authToken)
    }

    // MARK: Establish WebSocket Connection

    /// **NOTE**
    /// make sure any value for `certPinner` inputted here doesn't strongly reference `TR_TVCommander` (will cause a retain cycle if it does)
    public func connectToTV(certPinner: CertificatePinning? = nil) {
        guard !isConnected else {
            handleError(.connectionAlreadyEstablished)
            return
        }
        guard let url = tvConfig.wssURL() else {
            handleError(.urlConstructionFailed)
            return
        }
        webSocket = webSocketCreator.createTVWebSocket(
            url: url, certPinner: certPinner, delegate: self)
        webSocket?.connect()
    }

    public func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        webSocketHandler.didReceive(event: event, client: client)
    }

    // MARK: Send Remote Control Commands

    public func sendRemoteCommand(key: TR_TVRemoteCommand.TR_Params.TR_ControlKey) {
        guard isConnected else {
            handleError(.remoteCommandNotConnectedToTV)
            return
        }
        guard authStatus == .allowed else {
            handleError(.remoteCommandAuthenticationStatusNotAllowed)
            return
        }
        sendCommandOverWebSocket(createRemoteCommand(key: key))
    }

    private func createRemoteCommand(key: TR_TVRemoteCommand.TR_Params.TR_ControlKey) -> TR_TVRemoteCommand {
        let params = TR_TVRemoteCommand.TR_Params(cmd: .click, dataOfCmd: key, option: false, typeOfRemote: .remoteKey)
        return TR_TVRemoteCommand(method: .control, params: params)
    }

    private func sendCommandOverWebSocket(_ command: TR_TVRemoteCommand) {
        commandQueue.append(command)
        if commandQueue.count == 1 {
            sendNextQueuedCommandOverWebSocket()
        }
    }

    private func sendNextQueuedCommandOverWebSocket() {
        guard let command = commandQueue.first else {
            return
        }
        guard let commandStr = try? command.asString() else {
            handleError(.commandConversionToStringFailed)
            return
        }
        webSocket?.write(string: commandStr) { [weak self] in
            guard let self else { return }
            self.commandQueue.removeFirst()
            self.delegate?.tvCommander(self, didWriteRemoteCommand: command)
            self.sendNextQueuedCommandOverWebSocket()
        }
    }

    // MARK: Send Keyboard Commands
    
    public func sendInputString(_ text: String) {
        guard isConnected else { return }
        guard authStatus == .allowed else { return }
        let base64 = Data(text.utf8).base64EncodedString()
        let payload: [String: Any] = [
            "method": "ms.remote.control",
            "params": [
                "Cmd": base64,
                "DataOfCmd": "base64",
                "TypeOfRemote": "SendInputString"
            ]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: data, encoding: .utf8) {
            webSocket?.write(string: jsonString)
        }
    }
    
    public func sendInputEnd() {
        guard isConnected else { return }
        guard authStatus == .allowed else { return }
        let payload: [String: Any] = [
            "method": "ms.remote.control",
            "params": [
                "Cmd": "SendInputEnd",
                "DataOfCmd": "base64",
                "TypeOfRemote": "SendInputEnd"
            ]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: data, encoding: .utf8) {
            webSocket?.write(string: jsonString)
        }
    }

    public func enterText(_ text: String, on keyboard: TR_TVKeyboardLayout) {
        let keys = controlKeys(toEnter: text, on: keyboard)
        keys.forEach(sendRemoteCommand(key:))
    }

    private func controlKeys(toEnter text: String, on keyboard: TR_TVKeyboardLayout) -> [TR_TVRemoteCommand.TR_Params.TR_ControlKey] {
        let chars = Array(text)
        var moves: [TR_TVRemoteCommand.TR_Params.TR_ControlKey] = [.enter]
        for i in 0..<(chars.count - 1) {
            let currentChar = String(chars[i])
            let nextChar = String(chars[i + 1])
            if let movesToNext = controlKeys(toMoveFrom: currentChar, to: nextChar, on: keyboard) {
                moves.append(contentsOf: movesToNext)
                moves.append(.enter)
            } else {
                delegate?.tvCommander(self, didEncounterError: .keyboardCharNotFound(nextChar))
            }
        }
        return moves
    }

    private func controlKeys(toMoveFrom char1: String, to char2: String, on keyboard: TR_TVKeyboardLayout) -> [TR_TVRemoteCommand.TR_Params.TR_ControlKey]? {
        guard let (startRow, startCol) = coordinates(of: char1, on: keyboard),
              let (endRow, endCol) = coordinates(of: char2, on: keyboard) else {
            return nil
        }
        let rowDiff = endRow - startRow
        let colDiff = endCol - startCol
        var moves: [TR_TVRemoteCommand.TR_Params.TR_ControlKey] = []
        if rowDiff > 0 {
            moves += Array(repeating: .down, count: rowDiff)
        } else if rowDiff < 0 {
            moves += Array(repeating: .up, count: abs(rowDiff))
        }
        if colDiff > 0 {
            moves += Array(repeating: .right, count: colDiff)
        } else if colDiff < 0 {
            moves += Array(repeating: .left, count: abs(colDiff))
        }
        return moves
    }

    private func coordinates(of char: String, on keyboard: TR_TVKeyboardLayout) -> (Int, Int)? {
        for (row, rowChars) in keyboard.enumerated() {
            if let colIndex = rowChars.firstIndex(of: char) {
                return (row, colIndex)
            }
        }
        return nil
    }

    // MARK: Disconnect WebSocket Connection

    public func disconnectFromTV() {
        webSocket?.disconnect()
    }

    // MARK: Handler Errors

    private func handleError(_ error: TR_TVCommanderError) {
        delegate?.tvCommander(self, didEncounterError: error)
    }

    // MARK: Wake on LAN

//    public static func wakeOnLAN(
//        device: TR_TVWakeOnLANDevice,
//        queue: DispatchQueue = .global(),
//        completion: @escaping (TR_TVCommanderError?) -> Void
//    ) {
//        let connection = NWConnection(
//            host: .init(device.broadcast),
//            port: .init(rawValue: device.port)!,
//            using: .udp
//        )
//        connection.stateUpdateHandler = { newState in
//            switch newState {
//            case .ready:
//                connection.send(
//                    content: .magicPacket(from: device),
//                    completion: .contentProcessed({
//                        connection.cancel()
//                        completion($0.flatMap(TR_TVCommanderError.wakeOnLANProcessingError))
//                    })
//                )
//            case .failed(let error):
//                completion(.wakeOnLANConnectionError(error))
//            default:
//                break
//            }
//        }
//        connection.start(queue: queue)
//    }
    
    // MARK: Wake on LAN
    public static func wakeOnLANSamsung(
        device: TR_TVWakeOnLANDevice,
        queue: DispatchQueue = .global(),
        completion: @escaping (TR_TVCommanderError?) -> Void
    ) {
        let mac = device.mac.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mac.isEmpty else {
            completion(.wakeOnLANProcessingError(NSError(domain: "WOL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty MAC Address"])))
            return
        }
        
        let packet = Data.magicPacket(from: mac)
        guard !packet.isEmpty else {
            completion(.wakeOnLANProcessingError(NSError(domain: "WOL", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid MAC Address"])))
            return
        }
        
        var targets: [(String, UInt16)] = [
            ("255.255.255.255", UInt16(device.port)),
            ("255.255.255.255", 9),
            ("255.255.255.255", 7)
        ]
        
        if !device.broadcast.isEmpty && device.broadcast != "255.255.255.255" {
            targets.append((device.broadcast, UInt16(device.port)))
            targets.append((device.broadcast, 9))
            targets.append((device.broadcast, 7))
        }
        
        queue.async {
            var lastError: Int32 = 0
            var sendSuccess = false
            
            for (broadcastIP, port) in targets {
                let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
                if sock < 0 {
                    continue
                }
                
                var broadcastEnable: Int32 = 1
                setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, socklen_t(MemoryLayout.size(ofValue: broadcastEnable)))
                
                var addr = sockaddr_in()
                addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = port.bigEndian
                
                inet_pton(AF_INET, broadcastIP, &addr.sin_addr)
                
                let result = packet.withUnsafeBytes { ptr -> Int in
                    let addrPtr = withUnsafePointer(to: &addr) {
                        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
                    }
                    return sendto(sock, ptr.baseAddress, packet.count, 0, addrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
                
                close(sock)
                
                if result >= 0 {
                    sendSuccess = true
                } else {
                    lastError = errno
                }
            }
            
            if sendSuccess {
                completion(nil)
            } else {
                completion(.wakeOnLANProcessingError(NSError(domain: "WOLSendError", code: Int(lastError))))
            }
        }
    }
        
        static func wakeOnLANLG(
            device: TR_TVWakeOnLANDevice,
            completion: @escaping (TR_TVCommanderError?) -> Void
        ) {
            let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            
            if sock < 0 {
                completion(.wakeOnLANConnectionError(NSError(domain: "SocketError", code: -1)))
                return
            }
            
            var broadcastEnable: Int32 = 1
            setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, socklen_t(MemoryLayout.size(ofValue: broadcastEnable)))
            
            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = UInt16(device.port).bigEndian
            
            inet_pton(AF_INET, device.broadcast, &addr.sin_addr)
            
            let packet = Data.magicPacket(from: device)
            
            let result = packet.withUnsafeBytes { ptr -> Int in
                let addrPtr = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
                }
                
                return sendto(sock, ptr.baseAddress, packet.count, 0, addrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
            
            close(sock)
            
            if result < 0 {
                completion(.wakeOnLANProcessingError(NSError(domain: "SendError", code: Int(errno))))
            } else {
                completion(nil)
            }
        }

}

// MARK: TR_TVWebSocketHandlerDelegate

extension TR_TVCommander: TR_TVWebSocketHandlerDelegate {
    func webSocketDidConnect() {
        isConnected = true
        delegate?.tvCommanderDidConnect(self)
    }
    
    func webSocketDidDisconnect() {
        isConnected = false
        authStatus = .none
        webSocket = nil
        delegate?.tvCommanderDidDisconnect(self)
    }
    
    func webSocketDidReadAuthStatus(_ authStatus: TR_TVAuthStatus) {
        self.authStatus = authStatus
        delegate?.tvCommander(self, didUpdateAuthState: authStatus)
    }
    
    func webSocketDidReadAuthToken(_ authToken: TR_TVAuthToken) {
        tvConfig.token = authToken
    }
    
    func webSocketError(_ error: TR_TVCommanderError) {
        delegate?.tvCommander(self, didEncounterError: error)
    }
}
