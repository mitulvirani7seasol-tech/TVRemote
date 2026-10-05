//
//  TR_CertManager.swift
//  
//
//

import Foundation

public class TR_CertManager {
    public init() {}
    
    // Base64 embedded cert.der (834 bytes)
    private static let certDerBase64 = "MIIDPjCCAiYCCQDr1ZsgycrofDANBgkqhkiG9w0BAQsFADBhMQswCQYDVQQGEwJubzELMAkGA1UECAwCbm8xCzAJBgNVBAcMAm5vMQswCQYDVQQKDAJubzELMAkGA1UECwwCbm8xCzAJBgNVBAMMAm5vMREwDwYJKoZIhvcNAQkBFgJubzAeFw0yMzEwMTkxNzI1MDdaFw0yMzExMTgxNzI1MDdaMGExCzAJBgNVBAYTAm5vMQswCQYDVQQIDAJubzELMAkGA1UEBwwCbm8xCzAJBgNVBAoMAm5vMQswCQYDVQQLDAJubzELMAkGA1UEAwwCbm8xETAPBgkqhkiG9w0BCQEWAm5vMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvNkIc8eaA8PiawzdVOwNp7q2w4h1trH5I01OvPPHBnwbZSnIrP5sCUXHL+Lsw0DHh+S85wMtvwo3XjKkFiM3dnQCHvQNlb0SiklQYmShJlN/zyOTXclZ41IESB1L5QQy9+LC/GQxR97Pj9iUF0hwy0XZNe9tbKivgBsOwxLEq8Hag2fW5cEi31Auhe/HxQrkP7r0iAK+Eciq1C7lLGlAlwZfodI4s4N/vnvcB21t9yQSrO437gc+aWgiZrHTO4WSiifpZWbN8rbxiiDb/fUyysgiqFCIQ9loagJiNJv8fU+OqEPj7HXVgHNdhiKRN7G8xhcAVJSAXEdRy2S2idvIDQIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQA85xlAp5Q9yc+JjtijPRhv7RsqRb4Md2r4L+iH50ue+dEPlEoh3Ip/kYZF+PjJgC0h8j2HvspnZZp4JHALAQxTCyxfMlffuZYsUE0HEq5HEijMBnFDNIOZW7V6EuqZizPXuHRvRcEl4Z719nP3UT0N3ul3aHp2SHUpkhYI5vg6a3RLd0NumOWsqQhclomcnpXJROrML0dW+0j4ale5Yph3higbyK+yDhcXRS+Ft6Dm/AXiB+ZfE1UiIwGF4xJqREqTwewt3UxBVwgy1G9HwJmY5oSJIMfL9YgTvmAQw0dEVPL0ytTzD1k82MRAotzhVfRV/syGyToeC+BYTSD1GBRG"
    
    // Base64 embedded cert.p12 (2437 bytes)
    private static let certP12Base64 = "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"

    public func getCertDerData() -> Data? {
        if let url = Bundle.main.url(forResource: "cert", withExtension: "der") {
            if let data = try? Data(contentsOf: url), !data.isEmpty {
                return data
            }
        }
        return Data(base64Encoded: TR_CertManager.certDerBase64)
    }

    public func getCertP12Data() -> Data? {
        if let url = Bundle.main.url(forResource: "cert", withExtension: "p12") {
            if let data = try? Data(contentsOf: url), !data.isEmpty {
                return data
            }
        }
        return Data(base64Encoded: TR_CertManager.certP12Base64)
    }

    public func certFromData(_ p12Data: Data, _ password: String) -> Result<CFArray?> {
        let importOptions = [kSecImportExportPassphrase as String: password]
        var rawItems: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, importOptions as CFDictionary, &rawItems)
        
        guard status == errSecSuccess else {
            return .Error(.secPKCS12ImportNotSuccess)
        }
        
        return .Result(rawItems)
    }

    public func getSecKeyFromData(_ certificateData: Data) -> Result<SecKey> {
        guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
            return .Error(.createCertFromDataError)
        }
        
        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        let status = SecTrustCreateWithCertificates(certificate, policy, &trust)
        
        guard status == errSecSuccess else {
            return .Error(.secTrustCreateWithCertificatesNotSuccess(status))
        }
 
        guard let secTrust = trust else {
            return (.Error(.createTrustObjectError))
        }
        
        if #available(iOS 14.0, *) {
            guard let key = SecTrustCopyKey(secTrust) else {
                return .Error(.secTrustCopyKeyError)
            }
            return .Result(key)
        } else {
            guard let key = SecTrustCopyPublicKey(secTrust) else {
                return .Error(.secTrustCopyKeyError)
            }
            return .Result(key)
        }
    }
    
    public func cert(_ url: URL, _ password: String) -> Result<CFArray?> {
        let p12Data: Data
        do {
            p12Data = try Data(contentsOf: url)
        } catch let error {
            if let fallback = getCertP12Data() {
                return certFromData(fallback, password)
            }
            return .Error(.loadCertFromURLError(error))
        }
        return certFromData(p12Data, password)
    }
    
    public func getSecKey(_ url: URL) -> Result<SecKey> {
        guard let certificateData = try? Data(contentsOf: url) else {
            if let fallback = getCertDerData() {
                return getSecKeyFromData(fallback)
            }
            return .Error(.createCertFromDataError)
        }
        return getSecKeyFromData(certificateData)
    }
}
