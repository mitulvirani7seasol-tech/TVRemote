//
//  TVCommanderKit+Extensions.swift
//  
//
//

import Foundation

// MARK: Data

extension Data {
    static func magicPacket(from device: TR_TVWakeOnLANDevice) -> Data {
        return magicPacket(from: device.mac)
    }

    static func magicPacket(from macAddress: String) -> Data {
        let cleanMac = macAddress.replacingOccurrences(of: ":", with: "")
                                 .replacingOccurrences(of: "-", with: "")
                                 .replacingOccurrences(of: " ", with: "")
                                 .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanMac.count == 12 else { return Data() }
        
        var macBytes = [UInt8]()
        var index = cleanMac.startIndex
        for _ in 0..<6 {
            let nextIndex = cleanMac.index(index, offsetBy: 2)
            let byteStr = String(cleanMac[index..<nextIndex])
            if let byte = UInt8(byteStr, radix: 16) {
                macBytes.append(byte)
            }
            index = nextIndex
        }
        guard macBytes.count == 6 else { return Data() }
        
        var magicPacketRaw = [UInt8](repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            magicPacketRaw.append(contentsOf: macBytes)
        }
        return Data(magicPacketRaw)
    }

    var asJSON: [String: Any]? {
        try? JSONSerialization.jsonObject(with: self) as? [String: Any]
    }

    var asString: String? {
        String(data: self, encoding: .utf8)
    }
}

// MARK: Dictionary

extension Dictionary {
    var asData: Data? {
        try? JSONSerialization.data(withJSONObject: self)
    }

    var asString: String? {
        asData?.asString
    }
}

// MARK: Encodable

extension Encodable {
    func asString(encoder: JSONEncoder = .init()) throws -> String? {
        try encoder.encode(self).asString
    }
}

// MARK: String

extension String {
    var isValidAppName: Bool {
        !isEmpty
    }

    var isValidIPAddress: Bool {
        let regex = #"^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
        return predicate.evaluate(with: self)
    }

    var asBase64: String? {
        asData?.base64EncodedString()
    }

    var asData: Data? {
        data(using: .utf8)
    }

    var asJSON: [String: Any]? {
        asData.flatMap(\.asJSON)
    }
}

// MARK: TR_TV

extension TR_TV {
    var ipAddress: String? {
        if let httpURLHost = URLComponents(string: uri)?.host,
           httpURLHost.isValidIPAddress {
            return httpURLHost
        } else if let deviceIPAddress = device?.ip,
                  deviceIPAddress.isValidIPAddress {
            return deviceIPAddress
        }
        return nil
    }

    func addingDevice(_ device: TR_TV.TR_Device) -> TR_TV {
        TR_TV(
            device: device,
            id: id,
            isSupport: isSupport,
            name: name,
            remote: remote,
            type: type,
            uri: uri,
            version: version
        )
    }
}

// MARK: TR_TVApp

extension TR_TVApp {
    public static func allApps() -> [TR_TVApp] {
        [
            espn(),
            hulu(),
            max(),
            netflix(),
            paramountPlus(),
            plutoTV(),
            primeVideo(),
            spotify(),
            youtube(),
            youtubeTv(),
            youtubeKids(),
            youtubeMusic(),
            disnep(),
            hbo(),
            tubi(),
            googlePlay(),
            haystackNews()
        ]
    }

    public static func espn() -> TR_TVApp {
        TR_TVApp(id: "3201708014618", name: "ESPN")
    }

    public static func hulu() -> TR_TVApp {
        TR_TVApp(id: "3201601007625", name: "Hulu")
    }

    public static func max() -> TR_TVApp {
        TR_TVApp(id: "3202301029760", name: "Max")
    }

    public static func netflix() -> TR_TVApp {
        TR_TVApp(id: "3201907018807", name: "Netflix")
    }

    public static func paramountPlus() -> TR_TVApp {
        TR_TVApp(id: "3201710014981", name: "Paramount +")
    }

    public static func plutoTV() -> TR_TVApp {
        TR_TVApp(id: "3201808016802", name: "Pluto TR_TV")
    }

    public static func primeVideo() -> TR_TVApp {
        TR_TVApp(id: "3201910019365", name: "Prime Video")
    }

    public static func spotify() -> TR_TVApp {
        TR_TVApp(id: "3201606009684", name: "Spotify")
    }

    public static func youtube() -> TR_TVApp {
        TR_TVApp(id: "111299001912", name: "YouTube")
    }
    
    //New APPs
    public static func youtubeTv() -> TR_TVApp {
        TR_TVApp(id: "3201901017640", name: "YouTube TR_TV")
    }

    public static func youtubeMusic() -> TR_TVApp {
        TR_TVApp(id: "3201901017641", name: "YouTube Music")
    }

    public static func youtubeKids() -> TR_TVApp {
        TR_TVApp(id: "3201901017642", name: "YouTube Kids")
    }

    public static func disnep() -> TR_TVApp {
        TR_TVApp(id: "3201901017643", name: "Disney+")
    }

    public static func tubi() -> TR_TVApp {
        TR_TVApp(id: "3201901017644", name: "Tubi")
    }

    public static func peacock() -> TR_TVApp {
        TR_TVApp(id: "3201901017645", name: "Peacock")
    }

    public static func googlePlay() -> TR_TVApp {
        TR_TVApp(id: "3201901017646", name: "Google Play Movies & TR_TV")
    }

    public static func hbo() -> TR_TVApp {
        TR_TVApp(id: "3201901017647", name: "HBO Max")
    }

    public static func haystackNews() -> TR_TVApp {
        TR_TVApp(id: "3201901017648", name: "Haystack News")
    }
}

// MARK: TR_TVConnectionConfiguration

extension TR_TVConnectionConfiguration {
    func wssURL() -> URL? {
        let base64Name = app.data(using: .utf8)?.base64EncodedString() ?? "U2NyZWVuIE1pcnJvcmluZw=="
        var urlString = "\(scheme)://\(ipAddress):\(port)\(path)?name=\(base64Name)"
        if let token = token, !token.isEmpty {
            urlString += "&token=\(token)"
        }
        return URL(string: urlString)
    }
}

// MARK: TR_TVKeyboardLayout

extension TR_TVKeyboardLayout {
    public static var qwerty: Self {
        [
            ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
            ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
            ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
            ["z", "x", "c", "v", "b", "n", "m"]
        ]
    }

    public static var youtube: Self {
        [
            ["a", "b", "c", "d", "e", "f", "g"],
            ["h", "i", "j", "k", "l", "m", "n"],
            ["o", "p", "q", "r", "s", "t", "u"],
            ["v", "w", "x", "y", "z", "-", "'"],
        ]
    }
}

// MARK: URL

extension URL {
    var removingPercentEncoding: URL? {
        absoluteString.removingPercentEncoding.flatMap(URL.init(string:))
    }
}

