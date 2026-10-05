//
//  TR_Ping.swift
//  
//
//

import Foundation

extension TR_CommandNetwork {
    struct TR_Ping {
        let val1: [UInt8]
        let val2: [UInt8]
        
        init?(_ data: Data) {
            let arrayData = Array(data)
            self.init(arrayData)
        }
        
        init?(_ data: [UInt8]) {
            guard !data.isEmpty,
                  data[0] == data.count - 1,
                  data.indices.contains(1), data[1] == 66,
                  data.indices.contains(2), data[2] == data[0] - 2,
                  data.indices.contains(3), data[3] == 8 else {
                return nil
            }
            
            let startIndex = 4
            if data[2] == 0x02 {
                val1 = Array(data.suffix(from: startIndex))
                val2 = []
                return
            }
            
            guard var endIndex = data.firstIndex(of: 16) else {
                return nil
            }
            
            guard endIndex > 3, data.count > endIndex else {
                return nil
            }
            
            if data.indices.contains(endIndex + 1), data[endIndex + 1] == 16 {
                endIndex += 1
            }
            
            val1 = Array(data[startIndex..<endIndex])
            val2 = endIndex + 1 < data.count ? Array(data.suffix(from: endIndex)) : []
        }
        
        static func extract(from data: Data) -> TR_Ping? {
            return self.extract(from: Array(data))
        }
        
        static func extract(from bytes: [UInt8]) -> TR_Ping? {
            let indexes = bytes.indices.filter { bytes[$0] == 66 }
            
            guard indexes.count > 0 else {
                return nil
            }
            
            for i in indexes {
                if i == 0 { continue }
                
                let size = Int(bytes[i-1])
                if i + size > bytes.count {
                    continue
                }
                
                
                if let ping = TR_Ping(Array(bytes[i-1..<i+size])) {
                    return ping
                }
            }
            
            return nil
        }
    }
}

extension TR_CommandNetwork {
    struct TR_Pong: TR_RequestDataProtocol {
        let data: Data
        
        init(_ value: [UInt8]) {
            var data: [UInt8] = [74, UInt8(value.count + 1), 8]
            data.append(contentsOf: value)
            data.insert(UInt8(data.count), at: 0)
            self.data = Data(data)
        }
    }
}
