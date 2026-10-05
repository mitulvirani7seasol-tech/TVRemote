//
//  Configuration.swift
//  
//
//

import Foundation

extension TR_PairingNetwork {
    struct TR_ConfigurationResponse {
        var length: Data?
        var data: Data?
        
        var isSuccess: Bool {
            guard length != nil, let data = data else {
                return false
            }
            
            var successArray: [UInt8] = [UInt8](TR_ProtocolVersion2().data)
            successArray.append(contentsOf: TR_Status.ok.data)
            successArray.append(contentsOf: [0xfa, 0x01])
            
            return data.starts(with: successArray) || data.starts(with: TR_ProtocolVersion2().data + TR_Status.ok.data)
        }
    }
}

extension TR_PairingNetwork {
    struct TR_ConfigurationRequest: TR_RequestDataProtocol {
        let config = TR_ParingConfiguration(clientRole: .input, encoding: TR_ParingEncoding(symbolLength: 6, type: .hexadecimal))
        let status: TR_Status = .ok
        let protocolVersion = TR_ProtocolVersion2()
        
        var data: Data {
            var data = Data()
            
            data.append(protocolVersion.data)
            data.append(status.data)
            
            data.append(contentsOf: [0xf2, 0x01, config.length])
            data.append(config.data)
            
            return data
        }
    }
    
    struct TR_ParingConfiguration {
        let clientRole: TR_RoleType
        let encoding: TR_ParingEncoding
        
        var data: Data {
            var data: Data = Data([0xa, encoding.length])
            data.append(encoding.data)
            data.append(contentsOf: [0x10, 0x1])
            
            return data
        }
        
        var length: UInt8 {
            return UInt8(data.count)
        }
    }
    
    enum TR_RoleType: UInt8 {
        case unknown = 0
        case input = 1
        case output = 2
    }
}
