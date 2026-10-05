//
//  ConnectToTVSheetView.swift
//  TV Remote
//
//

import SwiftUI
import AVKit
import ConnectSDK

// MARK: - AirPlay Picker Container (ScreenNova Parity)
struct TR_AirPlayPickerContainer: UIViewRepresentable {
    var onReady: (UIButton) -> Void
    
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = true
        picker.tintColor = .clear
        picker.activeTintColor = .clear
        picker.backgroundColor = .clear
        
        DispatchQueue.main.async {
            if let button = self.findButton(in: picker) {
                onReady(button)
            }
        }
        return picker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        DispatchQueue.main.async {
            if let button = self.findButton(in: uiView) {
                onReady(button)
            }
        }
    }
    
    private func findButton(in view: UIView) -> UIButton? {
        if let btn = view as? UIButton { return btn }
        for subview in view.subviews {
            if let btn = findButton(in: subview) { return btn }
        }
        return nil
    }
}

// MARK: - Device Alert Enum
enum TR_DeviceAlertKind: Identifiable {
    case success(String)
    case disconnectConfirm(ConnectableDevice)
    case disconnectRequired(ConnectableDevice)
    case airplayDisconnectRequired(ConnectableDevice)
    case airplaySwitchConfirm
    case wifiDisabled
    case localNetworkDisabled
    case pinPrompt
    case airplayGuide
    
    var id: String {
        switch self {
        case .success(let name): return "success_\(name)"
        case .disconnectConfirm(let device): return "disconnectConfirm_\(device.id ?? device.address ?? device.friendlyName ?? "dev")"
        case .disconnectRequired(let device): return "disconnectRequired_\(device.id ?? device.address ?? device.friendlyName ?? "dev")"
        case .airplayDisconnectRequired(let device): return "airplayDisconnectRequired_\(device.id ?? device.address ?? device.friendlyName ?? "dev")"
        case .airplaySwitchConfirm: return "airplaySwitchConfirm"
        case .wifiDisabled: return "wifiDisabled"
        case .localNetworkDisabled: return "localNetworkDisabled"
        case .pinPrompt: return "pinPrompt"
        case .airplayGuide: return "airplayGuide"
        }
    }
}

// MARK: - ConnectToTVSheetView (Full-Screen Presentation)
struct ConnectToTVSheetView: View {
    @ObservedObject private var remoteVM = TR_RemoteViewModel.shared
    @ObservedObject private var deviceManager = DeviceConnectionManager.shared
    @ObservedObject private var airPlayManager = TR_AirPlayManager.shared
    @ObservedObject private var languageManager = TR_LanguageManager.shared
    
    var onDismiss: (() -> Void)? = nil
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { UIDevice.isIPad || horizontalSizeClass == .regular }
    
    @State private var activeAlert: TR_DeviceAlertKind? = nil
    @State private var pendingDevice: ConnectableDevice? = nil
    @State private var isPermissionCheckDone = false
    @State private var airplayButton: UIButton? = nil
    @State private var airplayRouteObserver: NSObjectProtocol? = nil
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var keyboardHeight: CGFloat = 0
    
    // Official App Theme Gradient
    private var brandGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func isPinPrompt(_ alert: TR_DeviceAlertKind) -> Bool {
        if case .pinPrompt = alert {
            return true
        }
        return false
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func submitPinAction() {
        dismissKeyboard()
        triggerHaptic()
        let submittedPin = remoteVM.pinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !submittedPin.isEmpty else { return }
        remoteVM.submitPinCode()
        activeAlert = nil
    }
    
    private func performCompleteDisconnect() {
        remoteVM.disconnectTV()
        
        airPlayManager.isAirPlayConnected = false
        airPlayManager.connectedDeviceName = ""
        deviceManager.isAirPlayConnected = false
        deviceManager.isMirroringActive = false
        deviceManager.connectedDevice = nil
        for i in deviceManager.availableDevices.indices {
            deviceManager.availableDevices[i].isConnected = false
            deviceManager.availableDevices[i].isConnecting = false
        }
        
        TR_DeviceConnectivityViewModel.shared.disconnectTv()
        
        TR_ImageCastAirPlayManager.shared.stopPlayback()
        TR_CastVideoPlayerManager.shared.stopPlayback()
        AudioPlaybackController.dismissGlobalExternalDisplay()
        TR_MirroringServerManager.shared.stopServer()
        TR_SilentAudioManager.shared.forceStop()
        
        pendingDevice = nil
        activeAlert = nil
    }
    
    private func dismissPinDialog() {
        dismissKeyboard()
        triggerHaptic()
        remoteVM.pinCode = ""
        remoteVM.showPinDialog = false
        remoteVM.showProgress = false
        remoteVM.isConnectedSuccessfully = false
        remoteVM.deviceName = nil
        performCompleteDisconnect()
    }
    
    private func showToastNotification(message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.25)) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showToast = false
            }
        }
    }
    
    // AirPlay vs TV Mutually Exclusive Connection States
    private var isAirplayActive: Bool {
        airPlayManager.isAirPlayConnected || deviceManager.isAirPlayConnected || AVAudioSession.sharedInstance().currentRoute.outputs.contains(where: { $0.portType == .airPlay }) || UIScreen.screens.contains(where: { $0 != UIScreen.main && $0.mirrored != nil })
    }
    
    private var isTVConnected: Bool {
        !isAirplayActive && (remoteVM.connectedTVType != nil || deviceManager.connectedDevice != nil || (remoteVM.connectingDeviceAddress != nil && remoteVM.connectedTVType != nil))
    }
    
    // Helper to validate Smart TVs
    private func isValidSmartTV(_ device: ConnectableDevice) -> Bool {
        let name = device.friendlyName ?? device.modelName ?? ""
        let model = device.modelName
        let mfr = device.serviceDescription?.manufacturer
        return isStrictlySmartTV(name: name, model: model, manufacturer: mfr)
    }
    
    private func isDeviceConnected(_ device: ConnectableDevice) -> Bool {
        if isAirplayActive { return false }
        guard remoteVM.connectedTVType != nil || deviceManager.connectedDevice != nil else { return false }
        
        let targetAddress = remoteVM.connectingDeviceAddress ?? deviceManager.connectedDevice?.ipAddress
        if let targetAddress = targetAddress, !targetAddress.isEmpty {
            if device.address == targetAddress { return true }
        }
        
        let targetName = remoteVM.deviceName ?? deviceManager.connectedDevice?.name
        if let targetName = targetName, !targetName.isEmpty {
            let devName = (device.friendlyName ?? device.modelName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !devName.isEmpty && devName.caseInsensitiveCompare(targetName.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame {
                return true
            }
        }
        return false
    }
    
    // Discovered Devices Splitting
    private var connectedDevices: [ConnectableDevice] {
        if isAirplayActive {
            return []
        }
        return remoteVM.discoveredDevices
            .filter { isValidSmartTV($0) && isDeviceConnected($0) }
    }
    
    private var otherDevices: [ConnectableDevice] {
        if isAirplayActive {
            return remoteVM.discoveredDevices.filter { isValidSmartTV($0) }
        }
        return remoteVM.discoveredDevices
            .filter { isValidSmartTV($0) && !isDeviceConnected($0) }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top Header View
                topHeaderView
                    .padding(.horizontal, isIPad ? 24 : 16)
                    .padding(.top, isIPad ? 12 : 8)
                    .padding(.bottom, 6)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: isIPad ? 20 : 16) {
                        // TV Header Illustration Graphic
                        Image("ic_tv_Header")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: isIPad ? 360 : 300)
                            .padding(.top, 4)
                            .padding(.bottom, 2)
                        
                        // SECTION 1: AIRPLAY
                        VStack(alignment: .leading, spacing: 8) {
                            Text(languageManager.localized("airplay"))
                                .font(.inter(.bold, size: isIPad ? 16 : 14, autoScaleForPad: false))
                                .foregroundColor(Color(hex: "111827"))
                            
                            airplayCardView(isIPad: isIPad)
                        }
                        .padding(.horizontal, isIPad ? 24 : 16)
                        
                        // SECTION 2: AVAILABLE DEVICES
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(languageManager.localized("available_devices"))
                                    .font(.inter(.bold, size: isIPad ? 16 : 14, autoScaleForPad: false))
                                    .foregroundColor(Color(hex: "111827"))
                                
//                                Spacer()
                                
//                                Button(action: {
//                                    triggerHaptic()
//                                    remoteVM.rescanNow()
//                                }) {
//                                    Image(systemName: "arrow.clockwise")
//                                        .font(.system(size: isIPad ? 16 : 14, weight: .semibold))
//                                        .foregroundColor(Color(hex: "4B5563"))
//                                        .padding(6)
//                                }
//                                .buttonStyle(.plain)
                            }
                            
                            if connectedDevices.isEmpty && otherDevices.isEmpty {
                                troubleshootingSection(isIPad: isIPad)
                                    .padding(.top, 4)
                            } else {
                                VStack(spacing: 12) {
                                    // Connected Device Section
                                    ForEach(connectedDevices, id: \.address) { device in
                                        smartTVCardView(device: device, isConnected: true, isIPad: isIPad)
                                    }
                                    
                                    // Other Available Devices Section
                                    ForEach(otherDevices, id: \.address) { device in
                                        smartTVCardView(device: device, isConnected: false, isIPad: isIPad)
                                    }
                                }
                                
                                troubleshootingSection(isIPad: isIPad)
                                    .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, isIPad ? 24 : 16)
                        .padding(.bottom, isIPad ? 36 : 30)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            // Popups & Dialogs Overlay
            if let alert = activeAlert {
                ZStack(alignment: .center) {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            dismissKeyboard()
                        }
                    
                    customPopupDialog(for: alert)
                        .offset(y: isPinPrompt(alert) && keyboardHeight > 0 ? -min(keyboardHeight * 0.45, 140) : 0)
                        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
                        .transition(.scale.combined(with: .opacity))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .zIndex(100)
            }
            
            // Toast Notification Overlay
            if showToast {
                VStack {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text(toastMessage)
                            .font(.inter(.semiBold, size: isIPad ? 15 : 13.5))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(hex: "EF4444"))
                            .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 4)
                    )
                    .padding(.top, isIPad ? 32 : 16)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
                .zIndex(200)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Image("BG")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        )
        .animation(.easeInOut(duration: 0.22), value: activeAlert?.id)
        .animation(.easeInOut(duration: 0.25), value: showToast)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notif in
            if let frame = notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = frame.height
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
        .onAppear {
            TR_AirPlayManager.shared.updateCurrentRoute()
            deviceManager.checkAirPlayStatus()
            isPermissionCheckDone = false
            runSequentialNetworkChecks()
            remoteVM.rescanNow()
        }
        .onDisappear {
            remoteVM.showProgress = false
            remoteVM.pinCode = ""
            remoteVM.showPinDialog = false
            if let observer = airplayRouteObserver {
                NotificationCenter.default.removeObserver(observer)
                airplayRouteObserver = nil
            }
        }
        .onChange(of: remoteVM.isConnectedSuccessfully) { isSuccess in
            if isSuccess, !remoteVM.showPinDialog, remoteVM.connectedTVType != nil {
                let name = pendingDevice?.friendlyName ?? pendingDevice?.modelName ?? remoteVM.deviceName ?? "Smart TV"
                pendingDevice = nil
                activeAlert = .success(name)
            }
        }
        .onChange(of: remoteVM.connectedTVType) { newType in
            if newType != nil, remoteVM.isConnectedSuccessfully, !remoteVM.showPinDialog {
                let name = pendingDevice?.friendlyName ?? pendingDevice?.modelName ?? remoteVM.deviceName ?? "Smart TV"
                pendingDevice = nil
                activeAlert = .success(name)
            }
        }
        .onChange(of: remoteVM.showPinDialog) { isShowing in
            if isShowing {
                if remoteVM.selectedTVType != .SAMSUNG && remoteVM.connectedTVType != .SAMSUNG {
                    activeAlert = .pinPrompt
                } else {
                    remoteVM.showPinDialog = false
                }
            } else if case .pinPrompt = activeAlert {
                activeAlert = nil
            }
        }
        .onChange(of: remoteVM.showProgress) { inProgress in
            if !inProgress && !remoteVM.showPinDialog && !remoteVM.isConnectedSuccessfully {
                pendingDevice = nil
            }
        }
        .onChange(of: remoteVM.incorrectPinTrigger) { _ in
            if remoteVM.selectedTVType != .SAMSUNG && remoteVM.connectedTVType != .SAMSUNG {
                showToastNotification(message: languageManager.localized("incorrect_pin"))
                dismissPinDialog()
            }
        }
        .alert(
            languageManager.localized("samsung_tv_permission_required"),
            isPresented: $remoteVM.showAllowInTVSettingsAlert
        ) {
            Button(languageManager.localized("ok"), role: .cancel) { }
        } message: {
            Text(languageManager.localized("samsung_permission_desc"))
        }
    }
    
    // MARK: - Top Header Navigation View
    private var topHeaderView: some View {
        HStack(alignment: .center) {
            // Close Button (Cross mark in circular glass button)
            Button(action: {
                triggerHaptic()
                onDismiss?()
            }) {
                ZStack {
                    Image(systemName: "xmark")
                        .font(.system(size: isIPad ? 17 : 14, weight: .bold))
                        .foregroundColor(Color(hex: "111827"))
                }
                .frame(width: isIPad ? 46 : 40, height: isIPad ? 46 : 40)
                .glassModifier(cornerRadius: (isIPad ? 46 : 40) / 2)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
            
            Spacer()
            
            // Screen Title
            Text(languageManager.localized("connect_to_tv"))
                .font(.inter(.bold, size: isIPad ? 20 : 18, autoScaleForPad: false))
                .foregroundColor(Color(hex: "111827"))
            
            Spacer()
            
            // Right Spacer to center title (ic_cast removed as requested)
            Color.clear
                .frame(width: isIPad ? 46 : 40, height: isIPad ? 46 : 40)
        }
    }
    
    // MARK: - 1. AirPlay Card
    @ViewBuilder
    private func airplayCardView(isIPad: Bool) -> some View {
        let isConnected = isAirplayActive
        let airplayDisplayName = isConnected ? (airPlayManager.connectedDeviceName.isEmpty ? "AirPlay" : airPlayManager.connectedDeviceName) : languageManager.localized("airplay")
        
        ZStack {
            Button(action: {
                triggerHaptic()
                handleAirPlayTap()
            }) {
                HStack(spacing: 14) {
                    // Pink Gradient Squircle Icon with ic_tv_aiplay
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(brandGradient)
                            .frame(width: isIPad ? 56 : 48, height: isIPad ? 56 : 48)
                        
                        Image("ic_tv_aiplay")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.white)
                            .frame(width: isIPad ? 24 : 20, height: isIPad ? 24 : 20)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(airplayDisplayName)
                            .font(.inter(.bold, size: isIPad ? 17 : 15, autoScaleForPad: false))
                            .foregroundColor(Color(hex: "111827"))
                        
                        Text(isConnected ? languageManager.localized("connected") : languageManager.localized("not_connected"))
                            .font(.inter(isConnected ? .semiBold : .regular, size: isIPad ? 13 : 12, autoScaleForPad: false))
                            .foregroundColor(isConnected ? Color(hex: "10B981") : Color(hex: "9CA3AF"))
                    }
                    
                    Spacer()
                    
                    // Trailing Status Indicator (Pink Gradient Checkmark)
                    if isConnected {
                        ZStack {
                            Circle()
                                .fill(brandGradient)
                                .frame(width: isIPad ? 24 : 22, height: isIPad ? 24 : 22)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: isIPad ? 12 : 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#9C9C9C").opacity(0.12))
                .glassModifier(cornerRadius: 18)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.96))
            
            // Native AirPlay Route Picker Hook
            TR_AirPlayPickerContainer { button in
                self.airplayButton = button
            }
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)
        }
    }
    
    // MARK: - AirPlay Tap Handling
    private func handleAirPlayTap() {
        if isAirplayActive {
            airplayButton?.sendActions(for: .touchUpInside)
        } else if isTVConnected {
            activeAlert = .airplaySwitchConfirm
        } else {
            if let button = airplayButton {
                button.sendActions(for: .touchUpInside)
            }
        }
    }
    
    // MARK: - 2. Smart TV Device Card
    @ViewBuilder
    private func smartTVCardView(device: ConnectableDevice, isConnected: Bool, isIPad: Bool) -> some View {
        let isCurrentConnecting: Bool = {
            guard remoteVM.showProgress else { return false }
            if let pending = pendingDevice {
                if let pendingAddr = pending.address, let devAddr = device.address, !pendingAddr.isEmpty, pendingAddr == devAddr {
                    return true
                }
                if let pendingId = pending.id, let devId = device.id, !pendingId.isEmpty, pendingId == devId {
                    return true
                }
                if let pendingName = pending.friendlyName, let devName = device.friendlyName, !pendingName.isEmpty, pendingName == devName {
                    return true
                }
            }
            if let connectingAddr = remoteVM.connectingDeviceAddress, let devAddr = device.address, !connectingAddr.isEmpty, connectingAddr == devAddr {
                return true
            }
            return false
        }()
        
        Button(action: {
            handleCardTap(device: device, isConnected: isConnected)
        }) {
            HStack(spacing: 14) {
                // Pink Gradient Squircle Icon with ic_tv_cast
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(brandGradient)
                        .frame(width: isIPad ? 56 : 48, height: isIPad ? 56 : 48)
                    
                    Image("ic_tv_cast")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white)
                        .frame(width: isIPad ? 24 : 20, height: isIPad ? 24 : 20)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(device.friendlyName ?? device.modelName ?? "Smart TV")
                        .font(.inter(.bold, size: isIPad ? 17 : 15, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "111827"))
                        .lineLimit(1)
                    
                    Text(isConnected ? languageManager.localized("connected") : (isCurrentConnecting ? languageManager.localized("connecting") : languageManager.localized("not_connected")))
                        .font(.inter(isConnected ? .semiBold : .regular, size: isIPad ? 13 : 12, autoScaleForPad: false))
                        .foregroundColor(isConnected ? Color(hex: "10B981") : (isCurrentConnecting ? Color(hex: "E25F89") : Color(hex: "9CA3AF")))
                }
                
                Spacer()
                
                // Trailing Status Indicator
                if isConnected {
                    ZStack {
                        Circle()
                            .fill(brandGradient)
                            .frame(width: isIPad ? 24 : 22, height: isIPad ? 24 : 22)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: isIPad ? 12 : 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else if isCurrentConnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "E25F89")))
                        .scaleEffect(0.9)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(hex: "#9C9C9C").opacity(0.12))
            .glassModifier(cornerRadius: 18)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.96))
        .disabled(isCurrentConnecting)
    }
    
    // MARK: - Handle Card Tap
    private func handleCardTap(device: ConnectableDevice, isConnected: Bool) {
        if isConnected {
            activeAlert = .disconnectConfirm(device)
        } else if isAirplayActive {
            activeAlert = .airplayDisconnectRequired(device)
        } else if !connectedDevices.isEmpty {
            activeAlert = .disconnectRequired(device)
        } else {
            pendingDevice = device
            remoteVM.isConnectedSuccessfully = false
            remoteVM.showPinDialog = false
            remoteVM.pinCode = ""
            remoteVM.connect(to: device)
        }
    }
    
    // MARK: - AirPlay Disconnect & Switch Helper
    private func openAirPlayPickerThenRetry(newDevice: ConnectableDevice) {
        if let existing = airplayRouteObserver {
            NotificationCenter.default.removeObserver(existing)
            airplayRouteObserver = nil
        }
        
        let checkAndProceed = {
            let isAudioAirplay = AVAudioSession.sharedInstance()
                .currentRoute.outputs
                .contains { $0.portType == .airPlay }
            let isScreenAirplay = UIScreen.screens.contains(where: { $0 != UIScreen.main && $0.mirrored != nil })
            
            if !isAudioAirplay && !isScreenAirplay {
                if let observer = self.airplayRouteObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self.airplayRouteObserver = nil
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.performCompleteDisconnect()
                    self.pendingDevice = newDevice
                    self.remoteVM.connect(to: newDevice)
                }
            }
        }
        
        airplayRouteObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            checkAndProceed()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { _ in
            checkAndProceed()
        }
        
        if let button = airplayButton {
            button.sendActions(for: .touchUpInside)
        } else {
            activeAlert = .airplayGuide
        }
    }
    
    // MARK: - Sequential Network Checks
    private func runSequentialNetworkChecks() {
        TR_NetworkPermissionManager.shared.startMonitoring()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Step 1: WiFi check
            guard TR_NetworkPermissionManager.shared.isInternetAvailable else {
                self.activeAlert = .wifiDisabled
                return
            }
            
            // Step 2: Local Network permission check
            TR_NetworkPermissionManager.shared.checkLocalNetworkPermission { granted in
                DispatchQueue.main.async {
                    if !granted {
                        self.activeAlert = .localNetworkDisabled
                    } else {
                        self.isPermissionCheckDone = true
                    }
                }
            }
        }
    }
    
    // MARK: - 3. Troubleshooting Guide
    @ViewBuilder
    private func troubleshootingSection(isIPad: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(languageManager.localized("how_to_connect_guide"))
                .font(.inter(.bold, size: isIPad ? 14 : 13, autoScaleForPad: false))
                .foregroundColor(Color(hex: "111827"))
            
            VStack(alignment: .leading, spacing: 4) {
                guideBullet(text: languageManager.localized("ensure_same_wifi"), isIPad: isIPad)
                guideBullet(text: languageManager.localized("ensure_tv_on"), isIPad: isIPad)
                guideBullet(text: languageManager.localized("restart_router"), isIPad: isIPad)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassModifier(cornerRadius: 14)
    }
    
    private func guideBullet(text: String, isIPad: Bool) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.system(size: isIPad ? 14 : 12, weight: .bold))
                .foregroundColor(Color(hex: "6B7280"))
            
            Text(text)
                .font(.inter(.regular, size: isIPad ? 13 : 12, autoScaleForPad: false))
                .foregroundColor(Color(hex: "6B7280"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - 4. Custom Popup Dialogs (Glass Design)
    @ViewBuilder
    private func customPopupDialog(for alert: TR_DeviceAlertKind) -> some View {
        VStack(spacing: 0) {
            switch alert {
            case .success(let deviceName):
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: {
                            triggerHaptic()
                            activeAlert = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onDismiss?()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "9CA3AF"))
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Connected Checkmark Icon
                    ZStack {
                        Circle()
                            .fill(brandGradient)
                            .frame(width: isIPad ? 64 : 56, height: isIPad ? 64 : 56)
                            .shadow(color: Color(hex: "8E03A1").opacity(0.35), radius: 10, x: 0, y: 4)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: isIPad ? 28 : 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                    
                    // Title & Description
                    VStack(spacing: 6) {
                        Text(languageManager.localized("connection_successful"))
                            .font(.inter(.bold, size: isIPad ? 20 : 18))
                            .foregroundColor(Color(hex: "111827"))
                            .multilineTextAlignment(.center)
                        
                        Text(languageManager.localized("now_connected_to") + " \(deviceName)")
                            .font(.inter(.regular, size: isIPad ? 14 : 13))
                            .foregroundColor(Color(hex: "6B7280"))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.horizontal, 4)
                    }
                    .padding(.bottom, 22)
                    
                    // Action Button
                    Button(action: {
                        triggerHaptic()
                        activeAlert = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onDismiss?()
                        }
                    }) {
                        Text(languageManager.localized("continue"))
                            .font(.inter(.semiBold, size: isIPad ? 15 : 14))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: isIPad ? 48 : 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(brandGradient)
                            )
                            .shadow(color: Color(hex: "8E03A1").opacity(0.28), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .frame(width: isIPad ? 360 : 315)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 8)
                )
                
            case .disconnectConfirm(let device):
                let name = device.friendlyName ?? device.modelName ?? "Smart TV"
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: {
                            triggerHaptic()
                            activeAlert = nil
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "9CA3AF"))
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    VStack(spacing: 6) {
                        Text(languageManager.localized("disconnect_device"))
                            .font(.inter(.bold, size: isIPad ? 20 : 18))
                            .foregroundColor(Color(hex: "111827"))
                            .multilineTextAlignment(.center)
                        
                        Text(languageManager.localized("disconnect_confirm_message") + " \(name)?")
                            .font(.inter(.regular, size: isIPad ? 14 : 13))
                            .foregroundColor(Color(hex: "6B7280"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 22)
                    
                    // Single Disconnect Button (Glass style as in screenshot)
                    Button(action: {
                        triggerHaptic()
                        performCompleteDisconnect()
                    }) {
                        Text(languageManager.localized("disconnect"))
                            .font(.inter(.semiBold, size: isIPad ? 15 : 14))
                            .foregroundColor(Color(hex: "6B7280"))
                            .frame(maxWidth: .infinity)
                            .frame(height: isIPad ? 48 : 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: "#9C9C9C").opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color(hex: "6B7280").opacity(0.35), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .frame(width: isIPad ? 360 : 315)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 8)
                )
                
            case .disconnectRequired(let device):
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: {
                            triggerHaptic()
                            activeAlert = nil
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "9CA3AF"))
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    VStack(spacing: 6) {
                        Text(languageManager.localized("disconnect_required"))
                            .font(.inter(.bold, size: isIPad ? 20 : 18))
                            .foregroundColor(Color(hex: "111827"))
                            .multilineTextAlignment(.center)
                        
                        Text(languageManager.localized("disconnect_required_desc"))
                            .font(.inter(.regular, size: isIPad ? 14 : 13))
                            .foregroundColor(Color(hex: "6B7280"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 22)
                    
                    Button(action: {
                        triggerHaptic()
                        performCompleteDisconnect()
                        pendingDevice = device
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            remoteVM.connect(to: device)
                        }
                    }) {
                        Text(languageManager.localized("disconnect"))
                            .font(.inter(.semiBold, size: isIPad ? 15 : 14))
                            .foregroundColor(Color(hex: "6B7280"))
                            .frame(maxWidth: .infinity)
                            .frame(height: isIPad ? 48 : 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: "#9C9C9C").opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color(hex: "6B7280").opacity(0.35), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .frame(width: isIPad ? 360 : 315)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 8)
                )
                
            case .airplayDisconnectRequired(let device):
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: {
                            triggerHaptic()
                            activeAlert = nil
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "9CA3AF"))
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    VStack(spacing: 6) {
                        Text(languageManager.localized("connect_tv_confirm_title"))
                            .font(.inter(.bold, size: isIPad ? 20 : 18))
                            .foregroundColor(Color(hex: "111827"))
                            .multilineTextAlignment(.center)
                        
                        Text(languageManager.localized("connect_tv_confirm_desc"))
                            .font(.inter(.regular, size: isIPad ? 14 : 13))
                            .foregroundColor(Color(hex: "6B7280"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 22)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            triggerHaptic()
                            activeAlert = nil
                            openAirPlayPickerThenRetry(newDevice: device)
                        }) {
                            Text(languageManager.localized("yes"))
                                .font(.inter(.semiBold, size: isIPad ? 15 : 14))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: isIPad ? 48 : 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(brandGradient)
                                )
                                .shadow(color: Color(hex: "8E03A1").opacity(0.28), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            triggerHaptic()
                            activeAlert = nil
                        }) {
                            Text(languageManager.localized("no"))
                                .font(.inter(.semiBold, size: isIPad ? 15 : 14))
                                .foregroundColor(Color(hex: "6B7280"))
                                .frame(maxWidth: .infinity)
                                .frame(height: isIPad ? 48 : 44)
                                .background(Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .frame(width: isIPad ? 360 : 315)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 8)
                )
                
            case .airplaySwitchConfirm:
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: {
                            triggerHaptic()
                            activeAlert = nil
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "9CA3AF"))
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    VStack(spacing: 6) {
                        Text(languageManager.localized("connect_airplay_confirm_title"))
                            .font(.inter(.bold, size: isIPad ? 20 : 18))
                            .foregroundColor(Color(hex: "111827"))
                            .multilineTextAlignment(.center)
                        
                        Text(languageManager.localized("connect_airplay_confirm_desc"))
                            .font(.inter(.regular, size: isIPad ? 14 : 13))
                            .foregroundColor(Color(hex: "6B7280"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 22)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            triggerHaptic()
                            performCompleteDisconnect()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                if let button = airplayButton {
                                    button.sendActions(for: .touchUpInside)
                                } else {
                                    activeAlert = .airplayGuide
                                }
                            }
                        }) {
                            Text(languageManager.localized("yes"))
                                .font(.inter(.semiBold, size: isIPad ? 15 : 14))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: isIPad ? 48 : 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(brandGradient)
                                )
                                .shadow(color: Color(hex: "8E03A1").opacity(0.28), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            triggerHaptic()
                            activeAlert = nil
                        }) {
                            Text(languageManager.localized("no"))
                                .font(.inter(.semiBold, size: isIPad ? 15 : 14))
                                .foregroundColor(Color(hex: "6B7280"))
                                .frame(maxWidth: .infinity)
                                .frame(height: isIPad ? 48 : 44)
                                .background(Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .frame(width: isIPad ? 360 : 315)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 8)
                )
                
            case .wifiDisabled:
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: {
                            triggerHaptic()
                            activeAlert = nil
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "9CA3AF"))
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // ic_tv_wifi Icon
                    Image("ic_tv_wifi")
                        .resizable()
                        .scaledToFit()
                        .frame(width: isIPad ? 80 : 70, height: isIPad ? 80 : 70)
                        .padding(.top, -4)
                        .padding(.bottom, 16)
                    
                    // Title & Description
                    VStack(spacing: 6) {
                        Text(languageManager.localized("wifi_disabled"))
                            .font(.inter(.bold, size: isIPad ? 20 : 18))
                            .foregroundColor(Color(hex: "111827"))
                            .multilineTextAlignment(.center)
                        
                        Text(languageManager.localized("wifi_disabled_desc"))
                            .font(.inter(.regular, size: isIPad ? 14 : 13))
                            .foregroundColor(Color(hex: "6B7280"))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.horizontal, 4)
                    }
                    .padding(.bottom, 22)
                    
                    // Buttons Row
                    HStack(spacing: 12) {
                        Button(action: {
                            triggerHaptic()
                            activeAlert = nil
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text(languageManager.localized("open_settings"))
                                .font(.inter(.semiBold, size: isIPad ? 15 : 14))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: isIPad ? 48 : 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(brandGradient)
                                )
                                .shadow(color: Color(hex: "8E03A1").opacity(0.28), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            triggerHaptic()
                            activeAlert = nil
                        }) {
                            Text(languageManager.localized("cancel"))
                                .font(.inter(.semiBold, size: isIPad ? 15 : 14))
                                .foregroundColor(Color(hex: "6B7280"))
                                .frame(maxWidth: .infinity)
                                .frame(height: isIPad ? 48 : 44)
                                .background(Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .frame(width: isIPad ? 360 : 315)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 8)
                )
                
            case .localNetworkDisabled:
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: {
                            triggerHaptic()
                            activeAlert = nil
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "9CA3AF"))
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // ic_tv_wifi Icon
                    Image("ic_tv_wifi")
                        .resizable()
                        .scaledToFit()
                        .frame(width: isIPad ? 80 : 70, height: isIPad ? 80 : 70)
                        .padding(.top, -4)
                        .padding(.bottom, 16)
                    
                    // Title & Description
                    VStack(spacing: 6) {
                        Text(languageManager.localized("local_network_disabled"))
                            .font(.inter(.bold, size: isIPad ? 20 : 18))
                            .foregroundColor(Color(hex: "111827"))
                            .multilineTextAlignment(.center)
                        
                        Text(languageManager.localized("local_network_disabled_desc"))
                            .font(.inter(.regular, size: isIPad ? 14 : 13))
                            .foregroundColor(Color(hex: "6B7280"))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.horizontal, 4)
                    }
                    .padding(.bottom, 22)
                    
                    // Buttons Row
                    HStack(spacing: 12) {
                        Button(action: {
                            triggerHaptic()
                            activeAlert = nil
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text(languageManager.localized("open_settings"))
                                .font(.inter(.semiBold, size: isIPad ? 15 : 14))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: isIPad ? 48 : 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(brandGradient)
                                )
                                .shadow(color: Color(hex: "8E03A1").opacity(0.28), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            triggerHaptic()
                            activeAlert = nil
                        }) {
                            Text(languageManager.localized("cancel"))
                                .font(.inter(.semiBold, size: isIPad ? 15 : 14))
                                .foregroundColor(Color(hex: "6B7280"))
                                .frame(maxWidth: .infinity)
                                .frame(height: isIPad ? 48 : 44)
                                .background(Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .frame(width: isIPad ? 360 : 315)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 8)
                )
                
            case .pinPrompt:
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: {
                            dismissPinDialog()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "9CA3AF"))
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Pin / Shield Icon
                    ZStack {
                        Circle()
                            .fill(brandGradient.opacity(0.12))
                            .frame(width: isIPad ? 68 : 60, height: isIPad ? 68 : 60)
                        
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: isIPad ? 28 : 24, weight: .semibold))
                            .foregroundColor(Color(hex: "8E03A1"))
                    }
                    .padding(.top, -4)
                    .padding(.bottom, 14)
                    
                    // Title & Description
                    VStack(spacing: 6) {
                        Text(languageManager.localized("enter_pin_code"))
                            .font(.inter(.bold, size: isIPad ? 20 : 18))
                            .foregroundColor(Color(hex: "111827"))
                            .multilineTextAlignment(.center)
                        
                        Text(languageManager.localized("please_enter_pin"))
                            .font(.inter(.regular, size: isIPad ? 14 : 13))
                            .foregroundColor(Color(hex: "6B7280"))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.horizontal, 4)
                    }
                    .padding(.bottom, 16)
                    
                    // PIN Code Text Input Field
                    TextField(languageManager.localized("enter_pin"), text: $remoteVM.pinCode)
                        .font(.inter(.semiBold, size: isIPad ? 18 : 16))
                        .multilineTextAlignment(.center)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .keyboardType(.asciiCapable)
                        .submitLabel(.done)
                        .onSubmit {
                            submitPinAction()
                        }
                        .padding(.horizontal, 14)
                        .frame(height: isIPad ? 50 : 46)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(hex: "F3F4F6"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color(hex: "8E03A1").opacity(0.35), lineWidth: 1)
                                )
                        )
                        .padding(.bottom, 20)
                    
                    // Buttons Row
                    HStack(spacing: 12) {
                        Button(action: {
                            submitPinAction()
                        }) {
                            Text(languageManager.localized("submit"))
                                .font(.inter(.semiBold, size: isIPad ? 15 : 14))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: isIPad ? 48 : 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(brandGradient)
                                )
                                .shadow(color: Color(hex: "8E03A1").opacity(0.28), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .disabled(remoteVM.pinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(remoteVM.pinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                        
                        Button(action: {
                            dismissPinDialog()
                        }) {
                            Text(languageManager.localized("cancel"))
                                .font(.inter(.semiBold, size: isIPad ? 15 : 14))
                                .foregroundColor(Color(hex: "6B7280"))
                                .frame(maxWidth: .infinity)
                                .frame(height: isIPad ? 48 : 44)
                                .background(Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .frame(width: isIPad ? 360 : 315)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 8)
                )
                
            case .airplayGuide:
                AirPlayGuideDialog(
                    onOpenPicker: {
                        activeAlert = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            airplayButton?.sendActions(for: .touchUpInside)
                        }
                    },
                    onDismiss: {
                        activeAlert = nil
                    }
                )
            }
        }
    }
    
    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

#Preview {
    ConnectToTVSheetView()
}
