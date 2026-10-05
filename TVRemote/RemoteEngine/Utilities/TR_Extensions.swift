//
//  TR_AndroidControlManager+Extensions.swift
//  TR_TV Remote
//
//  Created by iOS Developer on 22/08/2025.
//

import Foundation
import SwiftUI

extension TR_RemoteManager.TR_RemoteState {
    func toString() -> String {
        switch self {
        case .idle:
            return "idle"
        case .connectionSetUp:
            return "connection Set Up"
        case .connectionPrepairing:
            return "connection Prepairing"
        case .connected:
            return "connected"
        case .fisrtConfigMessageReceived(let info):
            return "fisrt Config Message Received: vendor: \(info.vendor) model: \(info.model)"
        case .firstConfigSent:
            return "first Config Sent"
        case .secondConfigSent:
            return "second Config Sent"
        case .paired(let runningApp):
            return "Paired! Current runned app " + (runningApp ?? "")
        case .error(let error):
            return "Error: " + error.toString()
        }
    }
}

extension TR_PairManager.TR_PairingState {
    func toString() -> String {
        switch self {
        case .idle:
            return "idle"
        case .extractTLSparams:
            return "Extract TLS params"
        case .connectionSetUp:
            return "Connection Set Up"
        case .connectionPrepairing:
            return "Connection Prepairing"
        case .connected:
            return "Connected"
        case .pairingRequestSent:
            return "Pairing Request Sent"
        case .pairingResponseSuccess:
            return "Pairing Response Success"
        case .optionRequestSent:
            return "Option Request Sent"
        case .optionResponseSuccess:
            return "Option Response Success"
        case .confirmationRequestSent:
            return "Confirmation Request Sent"
        case .confirmationResponseSuccess:
            return "Confirmation Response Success"
        case .waitingCode:
            return "Waiting Code"
        case .secretSent:
            return "Secret Sent"
        case .successPaired:
            if let currentHost = TR_AndroidControlManager.currentHost {
                TR_ConnectedTVs.shared.saveIP(currentHost)
            }
            return "Success Paired"
        case .error(let error):
            return "Error: " + error.toString()
        }
    }
}

extension TR_AndroidTVRemoteControlError {
    func toString() -> String {
        switch self {
        case .unexpectedCertData:
            return "unexpected Cert Data"
        case .extractCFTypeRefError:
            return "extract CFTypeRef Error"
        case .secIdentityCreateError:
            return "sec Identity Create Error"
        case .toLongNames(let description):
            return "to Long Names" + description
        case .connectionCanceled:
            return "connection Canceled"
        case .pairingNotSuccess:
            return "pairing Not Success"
        case .optionNotSuccess:
            return "option Not Success"
        case .configurationNotSuccess:
            return "configuration Not Success"
        case .secretNotSuccess:
            return "secret Not Success"
        case .connectionWaitingError(let error):
            return "connection Waiting Error: " + error.localizedDescription
        case .connectionFailed:
            return "connection Failed"
        case .receiveDataError:
            return "receive Data Error"
        case .sendDataError:
            return "send Data Error"
        case .invalidCode(let description):
            return "invalid Code " + description
        case .wrongCode:
            return "wrong Code"
        case .noSecAttributes:
            return "no SecAttributes"
        case .notRSAKey:
            return "not RSA TR_Key"
        case .notPublicKey:
            return "not Public TR_Key"
        case .noKeySizeAttribute:
            return "no TR_Key Size Attribute"
        case .noValueData:
            return "no Value Data"
        case .invalidCertData:
            return "invalid Cert Data"
        case .createCertFromDataError:
            return "create Cert From Data Error"
        case .noClientPublicCertificate:
            return "no Client Public Certificate"
        case .noServerPublicCertificate:
            return "no Server Public Certificate"
        case .secTrustCopyKeyError:
            return "sec Trust Copy TR_Key Error"
        case .loadCertFromURLError:
            return "load Cert From URL Error"
        case .secPKCS12ImportNotSuccess:
            return "secPKCS12Import Not Success"
        case .createTrustObjectError:
            return "create Trust Object Error"
        case .secTrustCreateWithCertificatesNotSuccess:
            return "secTrust Create With Certificates Not Success"
        }
    }
}

