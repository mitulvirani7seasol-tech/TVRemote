//
//  ContinuousPressButton.swift
//  TV Remote
//
//

import SwiftUI
import Combine

// Coordinator to handle immediate tap + continuous repeating actions on Long Press
final class ContinuousPressCoordinator: ObservableObject {
    private var timer: Timer?
    private var isPressing: Bool = false
    var action: (() -> Void)?
    
    @MainActor func touchDown(action: @escaping () -> Void) {
        guard !isPressing else { return }
        self.isPressing = true
        self.action = action
        HapticFeedback.generate(.light)
        action() // Instant trigger on first touch
        startRepeatingTimer()
    }
    
    func touchUp() {
        stopRepeatingTimer()
        isPressing = false
    }
    
    private func startRepeatingTimer() {
        timer?.invalidate()
        // Wait 0.35s before starting repeat, then repeat every 0.12s
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            guard let self = self, self.isPressing else { return }
            HapticFeedback.generate(.light)
            self.action?()
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
                guard let self = self, self.isPressing else {
                    self?.stopRepeatingTimer()
                    return
                }
                HapticFeedback.generate(.light)
                self.action?()
            }
        }
    }
    
    private func stopRepeatingTimer() {
        timer?.invalidate()
        timer = nil
        action = nil
    }
    
    deinit {
        timer?.invalidate()
    }
}

struct ContinuousPressButton<Content: View>: View {
    let action: () -> Void
    let content: () -> Content
    
    @StateObject private var coordinator = ContinuousPressCoordinator()
    
    init(action: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.action = action
        self.content = content
    }
    
    var body: some View {
        content()
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        coordinator.touchDown(action: action)
                    }
                    .onEnded { _ in
                        coordinator.touchUp()
                    }
            )
            .onDisappear {
                coordinator.touchUp()
            }
    }
}
