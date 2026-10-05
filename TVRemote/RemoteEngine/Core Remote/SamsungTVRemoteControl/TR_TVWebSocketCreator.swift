//
//  TR_TVWebSocketCreator.swift
//  
//
//
//

import Foundation
import Starscream

class TR_TVWebSocketCreator {
    let builder: TR_TVWebSocketBuilder

    init(builder: TR_TVWebSocketBuilder = .init()) {
        self.builder = builder
    }

    func createTVWebSocket(
        url: URL,
        certPinner: CertificatePinning?,
        delegate: WebSocketDelegate
    ) -> WebSocket {
        var req = URLRequest(url: url)
        req.timeoutInterval = 30.0
        builder.setURLRequest(req)
        builder.setEngine(TVSslWebSocketEngine())
        builder.setDelegate(delegate)
        return builder.getWebSocket()!
    }
}

class TVSslWebSocketEngine: NSObject, Engine, URLSessionDataDelegate, URLSessionWebSocketDelegate {
    private var smWebSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    weak var delegate: EngineDelegate?

    func register(delegate: EngineDelegate) {
        self.delegate = delegate
    }

    func start(request: URLRequest) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        smWebSocketTask = session?.webSocketTask(with: request)
        doRead()
        smWebSocketTask?.resume()
    }

    func stop(closeCode: UInt16) {
        let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: Int(closeCode)) ?? .normalClosure
        smWebSocketTask?.cancel(with: closeCode, reason: nil)
        session?.invalidateAndCancel()
        session = nil
        smWebSocketTask = nil
    }

    func forceStop() {
        stop(closeCode: UInt16(URLSessionWebSocketTask.CloseCode.abnormalClosure.rawValue))
    }

    func write(string: String, completion: (() -> ())?) {
        smWebSocketTask?.send(.string(string), completionHandler: { _ in
            completion?()
        })
    }

    func write(data: Data, opcode: FrameOpCode, completion: (() -> ())?) {
        switch opcode {
        case .binaryFrame:
            smWebSocketTask?.send(.data(data), completionHandler: { _ in
                completion?()
            })
        case .textFrame:
            if let text = String(data: data, encoding: .utf8) {
                write(string: text, completion: completion)
            } else {
                completion?()
            }
        case .ping:
            smWebSocketTask?.sendPing(pongReceiveHandler: { _ in
                completion?()
            })
        default:
            completion?()
        }
    }

    private func doRead() {
        smWebSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let string):
                    self.broadcast(event: .text(string))
                case .data(let data):
                    self.broadcast(event: .binary(data))
                @unknown default:
                    break
                }
                self.doRead()
            case .failure(let error):
                self.broadcast(event: .error(error))
            }
        }
    }

    private func broadcast(event: WebSocketEvent) {
        delegate?.didReceive(event: event)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        let p = `protocol` ?? ""
        broadcast(event: .connected(["Sec-WebSocket-Protocol": p]))
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        var r = ""
        if let d = reason {
            r = String(data: d, encoding: .utf8) ?? ""
        }
        broadcast(event: .disconnected(r, UInt16(closeCode.rawValue)))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            broadcast(event: .error(error))
        }
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
