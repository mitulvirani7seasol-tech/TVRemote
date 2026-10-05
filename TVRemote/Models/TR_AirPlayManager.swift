import Foundation
import UIKit
import AVFoundation
import Combine

final class TR_AirPlayManager: ObservableObject {

    static let shared = TR_AirPlayManager()

    @Published var isAirPlayConnected: Bool = false
    @Published var connectedDeviceName: String = ""

    private init() {
        configureAudioSession()
        updateCurrentRoute()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(routeChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(routeChanged),
            name: UIScreen.didConnectNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(routeChanged),
            name: UIScreen.didDisconnectNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(routeChanged),
            name: UIScreen.modeDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(routeChanged),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Audio Session

    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
            )

            try session.setActive(true)

            print("✅ AirPlay audio session configured")
        } catch {
            print("❌ AirPlay audio session error:", error)
        }
    }

    // MARK: - Route Change

    @objc
    private func routeChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.updateCurrentRoute()
        }
    }

    // MARK: - Current Route

    func updateCurrentRoute() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs

        if let airplayOutput = outputs.first(where: {
            $0.portType == .airPlay
        }) {
            isAirPlayConnected = true
            connectedDeviceName = airplayOutput.portName

            print("✅ AirPlay audio connected:", airplayOutput.portName)
        } else if UIScreen.screens.contains(where: { $0 != UIScreen.main && $0.mirrored != nil }) {
            isAirPlayConnected = true
            connectedDeviceName = "AirPlay Display"

            print("✅ AirPlay screen connected")
        } else {
            isAirPlayConnected = false
            connectedDeviceName = ""

            print("ℹ️ AirPlay disconnected")
        }
        
        let currentConnected = self.isAirPlayConnected
        Task { @MainActor in
            DeviceConnectionManager.shared.isAirPlayConnected = currentConnected
            if currentConnected {
                DeviceConnectionManager.shared.connectedDevice = nil
            }
        }
    }
}
