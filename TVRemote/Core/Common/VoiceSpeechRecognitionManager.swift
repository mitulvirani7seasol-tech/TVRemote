//
//  VoiceSpeechRecognitionManager.swift
//  TV Remote
//
//

import Foundation
import Combine
import AVFoundation
import Speech
import UIKit

class VoiceSpeechRecognitionManager: ObservableObject {
    static let shared = VoiceSpeechRecognitionManager()
    
    @Published var isRecording: Bool = false
    @Published var recognizedText: String = ""
    @Published var showRecognizedView: Bool = false
    @Published var showMicPermissionAlert: Bool = false
    @Published var showSpeechPermissionAlert: Bool = false
    @Published var micPermissionDeniedPermanently: Bool = false
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    init() {}
    
    // MARK: - Mic Touch Actions (Hold to Speak)
    
    func micTouchDown() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVAudioSession.sharedInstance().recordPermission
        
        if speechStatus == .authorized && micStatus == .granted {
            startLiveRecognition()
            return
        }
        
        if speechStatus == .denied || micStatus == .denied {
            DispatchQueue.main.async {
                self.micPermissionDeniedPermanently = true
                self.showMicPermissionAlert = true
            }
            return
        }
        
        // First time request
        requestMicPermissionAndStart()
    }
    
    @MainActor func micTouchUp(remoteVM: TR_RemoteViewModel = TR_RemoteViewModel.shared) {
        stopRecording(remoteVM: remoteVM)
    }
    
    // MARK: - Live Speech Recognition
    
    func startLiveRecognition() {
        if audioEngine.isRunning { return }
        
        DispatchQueue.main.async {
            self.isRecording = true
            self.recognizedText = TR_LanguageManager.shared.localized("listening")
            self.showRecognizedView = true
        }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session error:", error)
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            stopLiveRecognition()
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.recognizedText = text.isEmpty ? TR_LanguageManager.shared.localized("listening") : text
                    self.showRecognizedView = true
                }
            }
            
            if error != nil {
                self.stopLiveRecognition()
            }
        }
        
        inputNode.removeTap(onBus: 0)
        
        let nodeFormat = inputNode.outputFormat(forBus: 0)
        let validFormat: AVAudioFormat?
        if nodeFormat.sampleRate > 0 && nodeFormat.channelCount > 0 {
            validFormat = nodeFormat
        } else if let fallback = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false) {
            validFormat = fallback
        } else {
            validFormat = nil
        }
        
        guard let format = validFormat, format.sampleRate > 0, format.channelCount > 0 else {
            print("⚠️ Invalid audio format for speech recognition: sampleRate=\(nodeFormat.sampleRate), channels=\(nodeFormat.channelCount)")
            stopLiveRecognition()
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine error:", error)
            stopLiveRecognition()
        }
    }
    
    @MainActor func stopRecording(remoteVM: TR_RemoteViewModel = TR_RemoteViewModel.shared) {
        stopLiveRecognition()
        
        let finalText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let localizedListening = TR_LanguageManager.shared.localized("listening")
        if !finalText.isEmpty && finalText != localizedListening && finalText != "Listening..." {
            remoteVM.handleVoiceCommands(finalText)
        }
        
        DispatchQueue.main.async {
            self.isRecording = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.showRecognizedView = false
            }
        }
    }
    
    func stopLiveRecognition() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.reset()
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("Audio session deactivate error:", error)
        }
    }
    
    // MARK: - Permissions
    
    func requestMicPermissionAndStart() {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            requestSpeechPermission()
        case .denied:
            DispatchQueue.main.async {
                self.showMicPermissionAlert = true
            }
        case .undetermined:
            session.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.requestSpeechPermission()
                    } else {
                        self?.showMicPermissionAlert = true
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.startLiveRecognition()
                    self?.isRecording = true
                case .denied, .restricted:
                    self?.showSpeechPermissionAlert = true
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
    
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
    deinit {
        stopLiveRecognition()
    }
}
