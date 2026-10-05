//
//  HapticFeedbackManager.swift
//  TV Remote
//

import SwiftUI
import UIKit

// MARK: - Global Haptic Feedback Manager
public final class HapticFeedback {
    public static let shared = HapticFeedback()
    
    private var lastHapticTime: TimeInterval = 0
    private let minimumInterval: TimeInterval = 0.06 // 60ms debounce to prevent double-firing
    
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    private init() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        selectionGenerator.prepare()
    }
    
    public static func generate(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        shared.trigger(style)
    }
    
    public static func selection() {
        let now = CACurrentMediaTime()
        guard now - shared.lastHapticTime > shared.minimumInterval else { return }
        shared.lastHapticTime = now
        DispatchQueue.main.async {
            shared.selectionGenerator.selectionChanged()
            shared.selectionGenerator.prepare()
        }
    }
    
    public static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let now = CACurrentMediaTime()
        guard now - shared.lastHapticTime > shared.minimumInterval else { return }
        shared.lastHapticTime = now
        DispatchQueue.main.async {
            shared.notificationGenerator.notificationOccurred(type)
        }
    }
    
    public func trigger(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let now = CACurrentMediaTime()
        guard now - lastHapticTime > minimumInterval else { return }
        lastHapticTime = now
        
        DispatchQueue.main.async {
            switch style {
            case .light:
                self.lightGenerator.impactOccurred()
                self.lightGenerator.prepare()
            case .medium:
                self.mediumGenerator.impactOccurred()
                self.mediumGenerator.prepare()
            case .heavy:
                self.heavyGenerator.impactOccurred()
                self.heavyGenerator.prepare()
            case .soft:
                self.lightGenerator.impactOccurred()
            case .rigid:
                self.mediumGenerator.impactOccurred()
            @unknown default:
                self.lightGenerator.impactOccurred()
            }
        }
    }
}

// MARK: - Global App Haptic Button Style (Default for all SwiftUI Buttons)
public struct AppHapticButtonStyle: ButtonStyle {
    public var scaleAmount: CGFloat = 0.96
    public var opacityAmount: CGFloat = 0.88
    public var brightnessAmount: Double = 0.08
    
    public init(scaleAmount: CGFloat = 0.96, opacityAmount: CGFloat = 0.88, brightnessAmount: Double = 0.08) {
        self.scaleAmount = scaleAmount
        self.opacityAmount = opacityAmount
        self.brightnessAmount = brightnessAmount
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? opacityAmount : 1.0)
            .brightness(configuration.isPressed ? brightnessAmount : 0.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.68), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    HapticFeedback.generate(.light)
                }
            }
    }
}

// MARK: - Plain Haptic Button Style
public struct HapticPlainButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    HapticFeedback.generate(.light)
                }
            }
    }
}

// MARK: - Swizzling for Global UIControl & UIKit Button Haptics
extension UIApplication {
    private static var hasSwizzledSendAction = false
    
    public static func enableGlobalButtonHaptics() {
        guard !hasSwizzledSendAction else { return }
        hasSwizzledSendAction = true
        
        let originalSelector = #selector(UIApplication.sendAction(_:to:from:for:))
        let swizzledSelector = #selector(UIApplication.sm_sendAction(_:to:from:for:))
        
        guard let originalMethod = class_getInstanceMethod(UIApplication.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIApplication.self, swizzledSelector) else { return }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    @objc func sm_sendAction(_ action: Selector, to target: Any?, from sender: Any?, for event: UIEvent?) -> Bool {
        // Trigger haptic for button/control user interactions
        if let event = event, event.type == .touches {
            HapticFeedback.generate(.light)
        } else if sender is UIControl || sender is UIButton || sender is UIBarButtonItem {
            HapticFeedback.generate(.light)
        }
        return sm_sendAction(action, to: target, from: sender, for: event)
    }
}
