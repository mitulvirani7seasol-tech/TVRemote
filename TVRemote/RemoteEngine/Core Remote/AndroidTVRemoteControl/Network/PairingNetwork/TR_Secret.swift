//
//  Secret.swift
//  
//
//

import Foundation

extension TR_PairingNetwork {
    struct TR_SecretRequest: TR_RequestDataProtocol {
        let status: TR_Status = .ok
        let protocolVersion = TR_ProtocolVersion2()
        let encodedCert: [UInt8]
        
        private let unknownFields: [UInt8] = [0xc2, 0x02]
        
        var data: Data {
            var data = Data()
            
            data.append(protocolVersion.data)
            data.append(status.data)
            
            data.append(contentsOf: unknownFields)
            data.append(contentsOf: [UInt8(encodedCert.count + 2), 0xa, UInt8(encodedCert.count)])
            data.append(contentsOf: encodedCert)
            
            return data
        }
    }
}

extension TR_PairingNetwork {
    struct TR_SecretResponse {
        var data: Data?
        var code: String
        
        var isSuccess: Bool {
            guard let data = data, !data.isEmpty else {
                return false
            }
            
            // Check for explicit error responses
            // TR_Status.badSecret is [0x10, 0x92, 0x02], TR_Status.error is [0x10, 0x90, 0x02]
            if data.contains(0x92) || (data.contains(0x90) && !data.contains(0xc8)) {
                return false
            }
            
            // If data contains TR_Status.ok (0xc8) or starts with success markers
            if data.contains(0xc8) || data.contains([0x08, 0x02]) {
                return true
            }
            
            return true
        }
    }
}
