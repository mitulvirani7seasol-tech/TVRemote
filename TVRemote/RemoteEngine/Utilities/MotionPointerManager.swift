//
//  MotionPointerManager.swift
//  TV Remote
//
//  Created on 05/10/2026.
//

import Foundation
import CoreMotion
import Combine
import SwiftUI

class MotionPointerManager: ObservableObject {
    static let shared = MotionPointerManager()
    
    @Published var isAirMouseEnabled: Bool = false
    @Published var isMotionTrackingActive: Bool = false
    
    var onMotionDisplacement: ((_ dx: Float, _ dy: Float, _ dt: TimeInterval) -> Void)?
    
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var lastUpdateTime: TimeInterval = 0
    
    // Low-pass filter smoothed deltas
    private var smoothedDX: Double = 0.0
    private var smoothedDY: Double = 0.0
    
    // Fine-tuned motion constants for optimal precision & smooth response
    private let deadZone: Double = 0.015
    private let smoothingAlpha: Double = 0.35
    private let baseSensitivity: Double = 32.0
    
    init() {
        queue.name = "com.tvremote.airmouse.motion"
        queue.qualityOfService = .userInteractive
        queue.maxConcurrentOperationCount = 1
    }
    
    func startTracking() {
        guard motionManager.isDeviceMotionAvailable else {
            print("⚠️ Device motion (gyroscope) not available on this device")
            return
        }
        guard !motionManager.isDeviceMotionActive else { return }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60 Hz update rate
        lastUpdateTime = Date().timeIntervalSince1970
        smoothedDX = 0.0
        smoothedDY = 0.0
        
        DispatchQueue.main.async {
            self.isMotionTrackingActive = true
            self.isAirMouseEnabled = true
        }
        
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            
            let currentTime = Date().timeIntervalSince1970
            let dt = max(currentTime - self.lastUpdateTime, 0.008)
            self.lastUpdateTime = currentTime
            
            // Angular rotation rates (rad/sec)
            let rotX = motion.rotationRate.x // Pitch
            let rotY = motion.rotationRate.y // Roll
            let rotZ = motion.rotationRate.z // Yaw
            
            // Gravity vector in device coordinates
            let gravY = motion.gravity.y
            let gravZ = motion.gravity.z
            
            // Exact 3D projected angular velocity (accurate pointing ray independent of phone tilt angle)
            let rawHorizontal = (rotZ * gravY) - (rotY * gravZ)
            let rawVertical = -rotX
            
            // Deadzone to eliminate resting hand tremor
            let inputX = abs(rawHorizontal) < self.deadZone ? 0.0 : rawHorizontal
            let inputY = abs(rawVertical) < self.deadZone ? 0.0 : rawVertical
            
            // Smooth Exponential Low-Pass Filtering
            self.smoothedDX = (self.smoothingAlpha * inputX) + ((1.0 - self.smoothingAlpha) * self.smoothedDX)
            self.smoothedDY = (self.smoothingAlpha * inputY) + ((1.0 - self.smoothingAlpha) * self.smoothedDY)
            
            guard abs(self.smoothedDX) > 0.001 || abs(self.smoothedDY) > 0.001 else { return }
            
            // Dynamic ballistics acceleration (fine control for small moves, fast response for flicks)
            let speed = sqrt((self.smoothedDX * self.smoothedDX) + (self.smoothedDY * self.smoothedDY))
            let dynamicGain = 1.0 + min(pow(speed * 1.5, 1.25), 3.0)
            
            let deltaX = Float(self.smoothedDX * dynamicGain * self.baseSensitivity)
            let deltaY = Float(self.smoothedDY * dynamicGain * self.baseSensitivity)
            
            DispatchQueue.main.async {
                self.onMotionDisplacement?(deltaX, deltaY, dt)
            }
        }
    }
    
    func stopTracking() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        smoothedDX = 0.0
        smoothedDY = 0.0
        DispatchQueue.main.async {
            self.isMotionTrackingActive = false
            self.isAirMouseEnabled = false
        }
    }
    
    deinit {
        stopTracking()
    }
}
