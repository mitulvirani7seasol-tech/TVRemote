//
//  Option.swift
//  
//
//

import Foundation

extension TR_PairingNetwork {
    struct TR_OptionRequest: TR_RequestDataProtocol {
        let option: TR_ParingOption
        let status: TR_Status
        let protocolVersion = TR_ProtocolVersion2()
        
        var data: Data {
            var data = Data()
            data.append(protocolVersion.data)
            data.append(status.data)
            
            data.append(contentsOf: [0xa2, 0x01, option.length])
            data.append(option.data)
            
            return data
        }
        
        init() {
            status = .ok
            option = TR_ParingOption(inputEncodings: [TR_ParingEncoding(symbolLength: 6, type: .hexadecimal)],
                                  outputEncodings: [],
                                  preferredRole: .input)
        }
    }
    
    struct TR_OptionResponse {
        var length: Data?
        var data: Data?
        
        var isSuccess: Bool {
            guard length != nil, let data = data else {
                return false
            }

            var successArray: [UInt8] = [UInt8](TR_ProtocolVersion2().data)
            successArray.append(contentsOf: TR_Status.ok.data)
            successArray.append(contentsOf: [0xa2, 0x01])
            
            return data.starts(with: successArray) || data.starts(with: TR_ProtocolVersion2().data + TR_Status.ok.data)
        }
    }
}

extension TR_PairingNetwork.TR_OptionRequest {
    struct TR_ParingOption {
        var inputEncodings: [TR_PairingNetwork.TR_ParingEncoding] = []
        var outputEncodings: [TR_PairingNetwork.TR_ParingEncoding] = []
        var preferredRole: TR_RoleType = .input
        
        var data: Data {
            var data: Data = Data()
            
            if inputEncodings.count > 0 {
                for inputEncoding in inputEncodings {
                    data.append(contentsOf: [0xa, inputEncoding.length])
                    data.append(inputEncoding.data)
                }
            }
            
            if outputEncodings.count > 0 {
                for outputEncoding in outputEncodings {
                    data.append(contentsOf: [0x12, outputEncoding.length])
                    data.append(outputEncoding.data)
                }
            }
            
            if preferredRole.rawValue != 0 {
                data.append(contentsOf: [0x18, preferredRole.rawValue])
            }
            
            return data
        }
        
        var length: UInt8 {
            var length: UInt8 = 0
            
            if inputEncodings.count > 0 {
                for inputEncoding in inputEncodings {
                    length += 2
                    length += inputEncoding.length
                }
            }
            
            if outputEncodings.count > 0 {
                for outputEncoding in outputEncodings {
                    length += 2
                    length += outputEncoding.length
                }
            }
            
            if preferredRole.rawValue != 0 {
                length += 2
            }
            
            return length
        }
    }
    
    enum TR_RoleType: UInt8 {
        case unknown = 0
        case input = 1
        case output = 2
    }
}
