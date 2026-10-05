//
//  TR_SilentAudioManager.swift
//  TV Remote Casting
//
//  Created by iOS Developer on 22/09/2025.
//


//
//  TR_SilentAudioManager.swift
//  TV Remote Casting
//
//  Created by iOS Developer on 22/09/2025.
//

import AVFoundation

final class TR_SilentAudioManager {
    static let shared = TR_SilentAudioManager()
    private var audioPlayer: AVAudioPlayer?
    
    private init() {}
    
    func start() {
        if audioPlayer?.isPlaying == true {
            print("Silent audio already running ✅")
            return
        }
        
        guard let url = Bundle.main.url(forResource: "silent", withExtension: "mp3") else {
            print("Silent audio file not found ⚠️")
            return
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true, options: [])
            
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.01
            player.prepareToPlay()
            player.play()
            
            audioPlayer = player
            
            print("Silent audio started ✅")
        } catch {
            print("Error starting silent audio: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        guard let player = audioPlayer else {
            print("Silent audio not running, nothing to stop ⛔️")
            return
        }
        
        if player.isPlaying {
            player.stop()
        }
        audioPlayer = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            print("Silent audio stopped ⛔️")
        } catch {
            print("Error stopping audio session: \(error.localizedDescription)")
        }
    }
    
    func forceStop() {
        stop()
    }
}

