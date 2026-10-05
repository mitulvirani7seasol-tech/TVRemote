//
//  ConnectFile.swift
//  TVCastNative
//
//  Created by 7 Seasol3 on 18/08/25.
//

import Foundation
import UIKit
import UniformTypeIdentifiers

//var commonViewModel: CommonCastConnectSDKVM = CommonCastConnectSDKVM()


let SELECTED_TV = "SELECTED_TV"

extension UserDefaults {
    public func set<T: Encodable>(encodable: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(encodable) {
            set(data, forKey: key)
        }
    }
    
    // MARK: Get Custom Object from UserDefaults
    public func get<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        if let data = object(forKey: key) as? Data,
           let value = try? JSONDecoder().decode(type, from: data) {
            return value
        }
        return nil
    }
}

func setSelectedTV(name:String){
    UserDefaults().set(encodable: name, forKey: SELECTED_TV)
    UserDefaults().synchronize()
}

func getSelectedTV() -> String{
    if let count = UserDefaults().get(String.self, forKey: SELECTED_TV){
        return count
    }else{
        return ""
    }
    
}

func smResizeUIImage(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
    let smWidthScale = maxWidth / image.size.width
    let smComputedSize = CGSize(width: maxWidth, height: image.size.height * smWidthScale)
    UIGraphicsBeginImageContextWithOptions(smComputedSize, false, 1.0)
    image.draw(in: CGRect(origin: .zero, size: smComputedSize))
    let smRenderedOutput = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return smRenderedOutput ?? image
}

func getWiFiAddress() -> String? {
    var address : String?
    var ifaddr : UnsafeMutablePointer<ifaddrs>? = nil
    if getifaddrs(&ifaddr) == 0 {
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            let interface = ptr!.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
            }
        }
        freeifaddrs(ifaddr)
    }
    //    return "192.168.1.56"
    return address
}

extension URL {
    
    var attributes: [FileAttributeKey : Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: path)
        } catch let error as NSError {
            print("FileAttribute error: \(error)")
        }
        return nil
    }
    
    var fileSize: UInt64 {
        return attributes?[.size] as? UInt64 ?? UInt64(0)
    }
    
    var fileSizeString: String {
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
    
    // Check Media Type
    func mimeType() -> String {
        if let utType = UTType(filenameExtension: self.pathExtension), let preferredMIME = utType.preferredMIMEType {
            return preferredMIME
        }
        return "application/octet-stream"
    }

    var containsImage: Bool {
        if let utType = UTType(filenameExtension: self.pathExtension) {
            return utType.conforms(to: .image)
        }
        return false
    }

    var containsAudio: Bool {
        if let utType = UTType(filenameExtension: self.pathExtension) {
            return utType.conforms(to: .audio)
        }
        return false
    }

    var containsVideo: Bool {
        if let utType = UTType(filenameExtension: self.pathExtension) {
            return utType.conforms(to: .movie)
        }
        return false
    }
    
}
