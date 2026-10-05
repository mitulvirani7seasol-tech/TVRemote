//
//  SystemVolumeManager.swift
//  TV Remote
//

import Foundation
import UIKit
import MediaPlayer
import AVFoundation

final class SystemVolumeManager {
    static let shared = SystemVolumeManager()
    
    private var volumeSlider: UISlider?
    private var volumeView: MPVolumeView?
    
    private init() {
        setupVolumeSlider()
    }
    
    private func setupVolumeSlider() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let volView = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 1, height: 1))
            volView.alpha = 0.0001
            volView.clipsToBounds = true
            self.volumeView = volView
            
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
               let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
                window.addSubview(volView)
            } else if let window = UIApplication.shared.windows.first {
                window.addSubview(volView)
            }
            
            volView.layoutIfNeeded()
            self.extractSlider(from: volView)
        }
    }
    
    private func extractSlider(from view: UIView) {
        for subview in view.subviews {
            if let slider = subview as? UISlider {
                self.volumeSlider = slider
                return
            }
            extractSlider(from: subview)
        }
    }
    
    func getSystemVolume() -> Float {
        return AVAudioSession.sharedInstance().outputVolume
    }
    
    func setSystemVolume(_ volume: Float) {
        let clamped = max(0.0, min(1.0, volume))
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let slider = self.volumeSlider {
                slider.setValue(clamped, animated: false)
                slider.sendActions(for: .valueChanged)
            } else if let volView = self.volumeView {
                self.extractSlider(from: volView)
                self.volumeSlider?.setValue(clamped, animated: false)
                self.volumeSlider?.sendActions(for: .valueChanged)
            }
        }
    }
    
    func volumeUp() {
        let current = getSystemVolume()
        setSystemVolume(min(1.0, current + 0.01))
    }
    
    func volumeDown() {
        let current = getSystemVolume()
        setSystemVolume(max(0.0, current - 0.01))
    }
}
