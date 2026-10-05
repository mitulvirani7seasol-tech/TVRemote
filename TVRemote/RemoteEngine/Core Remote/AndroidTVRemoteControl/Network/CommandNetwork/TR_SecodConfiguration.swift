//
//  SecodConfiguration.swift
//  
//
//

import Foundation

extension TR_CommandNetwork {
    struct TR_SecondConfigurationRequest: TR_RequestDataProtocol {
        let data = Data([0x12, 0x3, 0x8, 0xEE, 0x4])
    }
}
