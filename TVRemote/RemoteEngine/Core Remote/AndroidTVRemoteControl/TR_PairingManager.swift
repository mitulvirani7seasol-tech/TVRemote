//
//  TR_PairManager.swift
//  
//
//

import Foundation
import Network
import CryptoKit

public class TR_PairManager {
    private let stateQueue = DispatchQueue(label: "pairing.state")
    private let connectQueue = DispatchQueue(label: "pairing.connect")
    
    private var pairingResponse = TR_PairingNetwork.TR_PairingResponse()
    private var optionResponse = TR_PairingNetwork.TR_OptionResponse()
    private var configResponse = TR_PairingNetwork.TR_ConfigurationResponse()
    
    private var connection: NWConnection?
    private var cryptoManager: TR_CryptoManager
    private let tlsManager: TR_TLSManager
    
    private var clientName = "client"
    private var serviceName = "service"
    private var code: String = ""
    
    public var logger: TR_Logger?
    private let logPrefix = "Pairing: "
    
    public var stateChanged: ((TR_PairingState)->())?
    
    private var pairingState: TR_PairingState = .idle {
        didSet {
            let state = pairingState
            
            stateQueue.async {
                switch state {
                case .idle:
                    self.logger?.infoLog(self.logPrefix + "idle")
                case .extractTLSparams:
                    self.logger?.infoLog(self.logPrefix + "extract TLS parameters")
                case .connectionSetUp:
                    self.logger?.infoLog(self.logPrefix + "connection set up")
                case .connectionPrepairing:
                    self.logger?.infoLog(self.logPrefix + "connection prepairing")
                case .connected:
                    self.logger?.infoLog(self.logPrefix + "connected")
                case .pairingRequestSent:
                    self.logger?.infoLog(self.logPrefix + "pairing request has been sent")
                case .pairingResponseSuccess:
                    self.logger?.infoLog(self.logPrefix + "pairing sesponse success")
                case .optionRequestSent:
                    self.logger?.infoLog(self.logPrefix + "option request sent")
                case .optionResponseSuccess:
                    self.logger?.infoLog(self.logPrefix + "option response success")
                case .confirmationRequestSent:
                    self.logger?.infoLog(self.logPrefix + "confirmation request has been sent")
                case .confirmationResponseSuccess:
                    self.logger?.infoLog(self.logPrefix + "confirmation response success")
                case .waitingCode:
                    self.logger?.infoLog(self.logPrefix + "waiting code")
                case .secretSent:
                    self.logger?.infoLog(self.logPrefix + "secret has been sent")
                case .successPaired:
                    self.logger?.infoLog(self.logPrefix + "success paired")
                case .error(let error):
                    self.logger?.errorLog(self.logPrefix + error.localizedDescription)
                }
                
                self.stateChanged?(state)
            }
        }
    }
    
    public init(_ tlsManager: TR_TLSManager, _ cryptoManager: TR_CryptoManager, _ logger: TR_Logger? = nil) {
        self.tlsManager = tlsManager
        self.cryptoManager = cryptoManager
        self.logger = logger
    }
    
    public func connect(_ host: String, _ clientName: String, _ serviceName: String) {
        if host.isEmpty {
            logger?.errorLog(logPrefix + "host shouldn't be empty!")
        }
        
        self.clientName = clientName
        self.serviceName = serviceName
        
        pairingState = .extractTLSparams
        
        let tlsParams: NWParameters

        switch tlsManager.getNWParams(connectQueue) {
        case .Result(let params):
            tlsParams = params
        case .Error(let error):
            pairingState = .error(error)
            return
        }
        
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: 6467),
            using: tlsParams)
        
        connection?.stateUpdateHandler = handleConnectionState
        logger?.infoLog(logPrefix + "connecting " + host + ":6467")
        connection?.start(queue: connectQueue)
    }
    
    public func disconnect() {
        logger?.infoLog(logPrefix + "disconnect")
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
    }
    
    public func sendSecret(_ code: String) {
        // Set the code for secret transmission
        logger?.debugLog("code: " + code)
        self.code = code
        let secret: [UInt8]
        switch cryptoManager.getEncodedCert(code) {
        case .Result(let data):
            secret = data
        case .Error(let error):
            pairingState = .error(error)
            disconnect()
            return
        }
        
        send(TR_PairingNetwork.TR_SecretRequest(encodedCert: secret))
        pairingState = .secretSent
        
        receive()
    }
    
    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .setup:
            print("___connection setup")
            pairingState = .connectionSetUp
        case .waiting(let error):
            print("___waiting error")
            pairingState = .error(.connectionWaitingError(error))
            disconnect()
        case .preparing:
            print("___connection preparing")
            pairingState = .connectionPrepairing
        case .ready:
            print("___connection ready")
            pairingState = .connected
            
            pairingResponse = TR_PairingNetwork.TR_PairingResponse()
            logger?.debugLog(logPrefix + "Sending pairing request")
            send(TR_PairingNetwork.TR_PairingRequest(clientName: clientName, serviceName: serviceName))
            pairingState = .pairingRequestSent
            
            receive()
        case .failed(let error):
            print("___connection failed")
            pairingState = .error(.connectionFailed(error))
            disconnect()
        case .cancelled:
            print("___connection cancelled")
            pairingState = .error(.connectionCanceled)
            disconnect()
        default:
            break
        }
    }
    
    private var receivedBuffer = Data()
    
    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] (data, context, isComplete, error) in
            guard let self = self else { return }
            
            if let error = error {
                self.pairingState = .error(.receiveDataError(error))
                return
            }
            
            guard let data = data, !data.isEmpty else {
                if isComplete {
                    self.logger?.infoLog(self.logPrefix + "Connection completed/closed by server")
                }
                return
            }
            
            self.logger?.debugLog(self.logPrefix + "received bytes: \(Array(data))")
            self.receivedBuffer.append(data)
            self.processReceivedBuffer()
        }
    }
    
    private func processReceivedBuffer() {
        guard !receivedBuffer.isEmpty else {
            receive()
            return
        }
        
        guard let (payloadLength, varintBytesCount) = Decoder.decodeVarint(receivedBuffer) else {
            receive()
            return
        }
        
        let totalPacketSize = Int(payloadLength) + varintBytesCount
        guard receivedBuffer.count >= totalPacketSize else {
            receive()
            return
        }
        
        let lengthData = receivedBuffer.subdata(in: 0..<varintBytesCount)
        let payloadData = receivedBuffer.subdata(in: varintBytesCount..<totalPacketSize)
        receivedBuffer.removeSubrange(0..<totalPacketSize)
        
        self.logger?.debugLog(self.logPrefix + "Parsed packet (len=\(payloadLength)): \(Array(payloadData))")
        
        switch self.pairingState {
        case .pairingRequestSent:
            pairingResponse.length = lengthData
            pairingResponse.data = payloadData
            guard pairingResponse.isSuccess || payloadData.starts(with: [0x08, 0x02, 0x10, 0xc8, 0x01]) else {
                self.pairingState = .error(.pairingNotSuccess(payloadData))
                return
            }
            
            self.logger?.debugLog(self.logPrefix + "pairing response success")
            self.pairingState = .pairingResponseSuccess
            
            optionResponse = TR_PairingNetwork.TR_OptionResponse()
            self.logger?.debugLog(self.logPrefix + "Sending option request")
            send(TR_PairingNetwork.TR_OptionRequest())
            self.pairingState = .optionRequestSent
            
            if !receivedBuffer.isEmpty {
                processReceivedBuffer()
            } else {
                receive()
            }
            
        case .optionRequestSent:
            optionResponse.length = lengthData
            optionResponse.data = payloadData
            guard optionResponse.isSuccess || payloadData.starts(with: [0x08, 0x02, 0x10, 0xc8, 0x01]) else {
                self.pairingState = .error(.optionNotSuccess(payloadData))
                return
            }
            
            self.logger?.debugLog(self.logPrefix + "option response success")
            self.pairingState = .optionResponseSuccess
            
            configResponse = TR_PairingNetwork.TR_ConfigurationResponse()
            self.logger?.debugLog(self.logPrefix + "Sending configuration request")
            send(TR_PairingNetwork.TR_ConfigurationRequest())
            self.pairingState = .confirmationRequestSent
            
            if !receivedBuffer.isEmpty {
                processReceivedBuffer()
            } else {
                receive()
            }
            
        case .confirmationRequestSent:
            configResponse.length = lengthData
            configResponse.data = payloadData
            guard configResponse.isSuccess || payloadData.starts(with: [0x08, 0x02, 0x10, 0xc8, 0x01]) else {
                self.pairingState = .error(.configurationNotSuccess(payloadData))
                return
            }
            
            self.logger?.debugLog(self.logPrefix + "confirmation response success -> waitingCode")
            self.pairingState = .confirmationResponseSuccess
            self.pairingState = .waitingCode
            
            // TR_TV is now displaying PIN code on screen! Listen for secret response after user inputs PIN
            receive()
            
        case .secretSent:
            let secretResponse = TR_PairingNetwork.TR_SecretResponse(data: lengthData + payloadData, code: code)
            if secretResponse.isSuccess {
                self.pairingState = .successPaired
            } else {
                let altResponse = TR_PairingNetwork.TR_SecretResponse(data: payloadData, code: code)
                self.pairingState = altResponse.isSuccess ? .successPaired : .error(.secretNotSuccess(payloadData))
            }
            self.disconnect()
            
        default:
            if !receivedBuffer.isEmpty {
                processReceivedBuffer()
            } else {
                receive()
            }
        }
    }
    
    private func send(_ request: TR_RequestDataProtocol) {
        send(Data(Encoder.encodeVarint(UInt(request.data.count))), request.data)
    }
    
    private func send(_ data: Data, _ nextData: Data? = nil) {
        logger?.debugLog(logPrefix + "Sending data: \(Array(data))")
        connection?.send(content: data, completion: .contentProcessed({ [weak self] (error) in
            guard let `self` = self else {
                return
            }
            
            if let error = error {
                self.pairingState = .error(.sendDataError(error))
                self.disconnect()
                return
            }
            
            self.logger?.debugLog(self.logPrefix + "Success sent")
            if let nextMessage = nextData {
                self.send(nextMessage)
            }
        }))
    }
}

extension TR_PairManager {
   public enum TR_PairingState {
        case idle
        case extractTLSparams
        case connectionSetUp
        case connectionPrepairing
        case connected
        case pairingRequestSent
        case pairingResponseSuccess
        case optionRequestSent
        case optionResponseSuccess
        case confirmationRequestSent
        case confirmationResponseSuccess
        case waitingCode
        case secretSent
        case successPaired
        case error(TR_AndroidTVRemoteControlError)
    }
}
