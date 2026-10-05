//
//  TR_TVWebSocketHandler.swift
//  
//
//

import Foundation
import Starscream

protocol TR_TVWebSocketHandlerDelegate: AnyObject {
    func webSocketDidConnect()
    func webSocketDidDisconnect()
    func webSocketDidReadAuthStatus(_ authStatus: TR_TVAuthStatus)
    func webSocketDidReadAuthToken(_ authToken: TR_TVAuthToken)
    func webSocketError(_ error: TR_TVCommanderError)
}

class TR_TVWebSocketHandler {
    private let decoder = JSONDecoder()
    weak var delegate: TR_TVWebSocketHandlerDelegate?

    // MARK: Interact with WebSocket

    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected:
            delegate?.webSocketDidConnect()
        case .cancelled, .disconnected:
            delegate?.webSocketDidDisconnect()
        case .text(let text):
            handleWebSocketText(text)
        case .binary(let data):
            webSocketDidReadPacket(data)
        case .error(let error):
            delegate?.webSocketError(.webSocketError(error))
        default:
            break
        }
    }

    private func handleWebSocketText(_ text: String) {
        if let packetData = text.asData {
            webSocketDidReadPacket(packetData)
        } else {
            delegate?.webSocketError(.packetDataParsingFailed)
        }
    }

    private func webSocketDidReadPacket(_ packet: Data) {
        if let authResponse = parseAuthResponse(from: packet) {
            handleAuthResponse(authResponse)
        } else {
            delegate?.webSocketError(.packetDataParsingFailed)
        }
    }

    // MARK: Receive Auth

    private func parseAuthResponse(from packet: Data) -> TR_TVAuthResponse? {
        try? decoder.decode(TR_TVAuthResponse.self, from: packet)
    }

    private func handleAuthResponse(_ response: TR_TVAuthResponse) {
        switch response.event {
        case .connect:
            parseTokenFromAuthResponse(response)
            delegate?.webSocketDidReadAuthStatus(.allowed)
        case .unauthorized:
            delegate?.webSocketDidReadAuthStatus(.denied)
        case .timeout:
            delegate?.webSocketDidReadAuthStatus(.none)
        default:
            delegate?.webSocketError(.authResponseUnexpectedChannelEvent(response))
        }
    }

    private func parseTokenFromAuthResponse(_ response: TR_TVAuthResponse) {
        if let newToken = response.data?.token {
            delegate?.webSocketDidReadAuthToken(newToken)
        } else if let refreshedToken = response.data?.clients.first?.attributes.token {
            delegate?.webSocketDidReadAuthToken(refreshedToken)
        } else {
            print("ℹ️ Connected with existing session token")
        }
    }
}
