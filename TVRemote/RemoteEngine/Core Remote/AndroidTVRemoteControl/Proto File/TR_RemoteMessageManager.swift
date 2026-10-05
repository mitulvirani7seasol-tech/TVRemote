//
//  TR_RemoteMessageManager.swift
//  TR_TV Remote
//
//  Created by iOS Developer on 27/08/2025.
//


import Foundation
import SwiftProtobuf

class TR_RemoteMessageManager {
    private var manufacturer: String = ""
    private var model: String = ""
    
    init() {
        getSystemInfo()
    }
    
    private func getSystemInfo() {
        let device = ProcessInfo.processInfo.hostName
        self.model = device
        self.manufacturer = "Apple"
    }
    
    func create(payload: TR_Remote_RemoteMessage) throws -> Data {
        if !payload.hasRemotePingResponse {
            print("Create Remote \(payload)")
        }
        
        do {
            var message: any Message = payload
            var data = Data()
            try data.appendDelimited(message: &message)
            
            print("Size of message: \(data.count)")
            if !payload.hasRemotePingResponse {
                print("Sending \(payload)")
            }
            
            return data
        } catch {
            throw error
        }
    }
    
    func createRemoteConfigure() throws -> Data {
        var deviceInfo = TR_Remote_RemoteDeviceInfo()
        deviceInfo.model = self.model
        deviceInfo.vendor = self.manufacturer
        deviceInfo.unknown1 = 1
        deviceInfo.unknown2 = "1"
        deviceInfo.packageName = "androidtv-remote"
        deviceInfo.appVersion = "1.0.0"
        
        var remoteConfigure = TR_Remote_RemoteConfigure()
        remoteConfigure.code1 = 622
        remoteConfigure.deviceInfo = deviceInfo
        
        var message = TR_Remote_RemoteMessage()
        message.remoteConfigure = remoteConfigure
        
        return try create(payload: message)
    }
    
    func createRemoteSetActive(active: Int) throws -> Data {
        var remoteSetActive = TR_Remote_RemoteSetActive()
        remoteSetActive.active = Int32(active)
        
        var message = TR_Remote_RemoteMessage()
        message.remoteSetActive = remoteSetActive
        
        return try create(payload: message)
    }
    
    func createRemotePingResponse(val1: Int32) throws -> Data {
        var remotePingResponse = TR_Remote_RemotePingResponse()
        remotePingResponse.val1 = val1
        
        var message = TR_Remote_RemoteMessage()
        message.remotePingResponse = remotePingResponse
        
        return try create(payload: message)
    }
    
    func createRemoteKeyInject(direction: TR_Remote_RemoteDirection, keyCode: TR_Remote_RemoteKeyCode) throws -> Data {
        var remoteKeyInject = TR_Remote_RemoteKeyInject()
        remoteKeyInject.keyCode = keyCode
        remoteKeyInject.direction = direction
        
        var message = TR_Remote_RemoteMessage()
        message.remoteKeyInject = remoteKeyInject
        
        return try create(payload: message)
    }
    
    func createRemoteAdjustVolumeLevel(level: TR_Remote_RemoteAdjustVolumeLevel) throws -> Data {
        var message = TR_Remote_RemoteMessage()
        message.remoteAdjustVolumeLevel = level
        
        return try create(payload: message)
    }
    
    func createRemoteResetPreferredAudioDevice() throws -> Data {
        var message = TR_Remote_RemoteMessage()
        message.remoteResetPreferredAudioDevice = TR_Remote_RemoteResetPreferredAudioDevice()
        
        return try create(payload: message)
    }
    
    func createRemoteImeKeyInject(appPackage: String, status: TR_Remote_RemoteTextFieldStatus) throws -> Data {
        var appInfo = TR_Remote_RemoteAppInfo()
        appInfo.appPackage = appPackage
        
        var remoteImeKeyInject = TR_Remote_RemoteImeKeyInject()
        remoteImeKeyInject.textFieldStatus = status
        remoteImeKeyInject.appInfo = appInfo
        
        var message = TR_Remote_RemoteMessage()
        message.remoteImeKeyInject = remoteImeKeyInject
        
        return try create(payload: message)
    }
    
    func createRemoteAppLinkLaunchRequest(app_link: String) throws -> Data {
        var remoteAppLinkLaunchRequest = TR_Remote_RemoteAppLinkLaunchRequest()
        remoteAppLinkLaunchRequest.appLink = app_link
        
        var message = TR_Remote_RemoteMessage()
        message.remoteAppLinkLaunchRequest = remoteAppLinkLaunchRequest
        
        return try create(payload: message)
    }
    
    func createRemoteImeBatchEdit(text: String, imeCounter: Int32, fieldCounter: Int32) throws -> Data {
        // Create the text field status
        var textFieldStatus = TR_Remote_RemoteImeObject()
        textFieldStatus.start = Int32(text.count - 1)
        textFieldStatus.end = Int32(text.count - 1)
        textFieldStatus.value = text
        
        // Create the edit info
        var editInfo = TR_Remote_RemoteEditInfo()
        editInfo.insert = 0
        editInfo.textFieldStatus = textFieldStatus
        
        // Create the batch edit message
        var remoteImeBatchEdit = TR_Remote_RemoteImeBatchEdit()
        remoteImeBatchEdit.imeCounter = imeCounter
        remoteImeBatchEdit.fieldCounter = fieldCounter
        remoteImeBatchEdit.editInfo = [editInfo]
        
        // Create the main message
        var message = TR_Remote_RemoteMessage()
        message.remoteImeBatchEdit = remoteImeBatchEdit
        
        return try create(payload: message)
    }

    func createRemoteVoiceBegin(sessionID: Int32) throws -> Data {
        var begin = TR_Remote_RemoteVoiceBegin()
        begin.sessionID = sessionID

        var message = TR_Remote_RemoteMessage()
        message.remoteVoiceBegin = begin
        return try create(payload: message)
    }

    func createRemoteVoicePayload(sessionID: Int32, audioData: Data) throws -> Data {
        var payload = TR_Remote_RemoteVoicePayload()
        payload.sessionID = sessionID
        payload.voicePayload = audioData

        var message = TR_Remote_RemoteMessage()
        message.remoteVoicePayload = payload
        return try create(payload: message)
    }
    
    func createRemoteVoiceEnd(sessionID: Int32) throws -> Data {
        var end = TR_Remote_RemoteVoiceEnd()
        end.sessionID = sessionID

        var message = TR_Remote_RemoteMessage()
        message.remoteVoiceEnd = end
        return try create(payload: message)
    }
    
    func parse(data: Data) throws -> TR_Remote_RemoteMessage {
        let message = try TR_Remote_RemoteMessage(serializedData: data)
        return message
    }
}

extension Data {
    mutating func appendVarint(_ value: UInt64) {
        var val = value
        while val >= 0x80 {
            self.append(UInt8(val & 0x7F | 0x80))
            val >>= 7
        }
        self.append(UInt8(val))
    }

    mutating func appendDelimited(message: inout Message) throws {
        let serialized = try message.serializedData()
        self.appendVarint(UInt64(serialized.count))
        self.append(serialized)
    }
}
