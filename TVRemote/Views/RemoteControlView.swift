//
//  RemoteControlView.swift
//  TV Remote
//
//  Created by iOS Developer on 01/10/2026.
//

import SwiftUI
import ConnectSDK
import Speech
import AVFoundation

enum RemoteMode: Int, CaseIterable {
    case dpad = 0
    case touchMouse = 1
    case swipePad = 2
    case keyboard = 3
}

// MARK: - Custom Rounded Annular Sector Shape (With Smooth Corner Fillets on Outer & Inner Arcs)
struct RoundedAnnularSector: Shape {
    var centerAngle: Double // degrees: 270 for Up, 90 for Down, 180 for Left, 0 for Right
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    var sweepAngle: Double = 76.0
    var cornerRadiusOut: CGFloat = 14.0
    var cornerRadiusIn: CGFloat = 10.0
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r1 = innerRadius
        let r2 = outerRadius
        
        let halfSweep = sweepAngle / 2.0
        let sDeg = centerAngle - halfSweep
        let eDeg = centerAngle + halfSweep
        
        // Angular offset corresponding to fillet radius on the arcs
        let dOutDeg = min((cornerRadiusOut / r2) * (180.0 / .pi), halfSweep * 0.4)
        let dInDeg = min((cornerRadiusIn / r1) * (180.0 / .pi), halfSweep * 0.4)
        
        let sArcOut = sDeg + dOutDeg
        let eArcOut = eDeg - dOutDeg
        let sArcIn = sDeg + dInDeg
        let eArcIn = eDeg - dInDeg
        
        // 4 sharp vertices of the sector
        let p1 = CGPoint(x: center.x + r2 * cos(sDeg * .pi / 180), y: center.y + r2 * sin(sDeg * .pi / 180))
        let p2 = CGPoint(x: center.x + r2 * cos(eDeg * .pi / 180), y: center.y + r2 * sin(eDeg * .pi / 180))
        let p3 = CGPoint(x: center.x + r1 * cos(eDeg * .pi / 180), y: center.y + r1 * sin(eDeg * .pi / 180))
        let p4 = CGPoint(x: center.x + r1 * cos(sDeg * .pi / 180), y: center.y + r1 * sin(sDeg * .pi / 180))
        
        // Points on radial edges where the fillets end
        let pRadialOutEnd = CGPoint(x: center.x + (r2 - cornerRadiusOut) * cos(eDeg * .pi / 180), y: center.y + (r2 - cornerRadiusOut) * sin(eDeg * .pi / 180))
        let pRadialInEnd = CGPoint(x: center.x + (r1 + cornerRadiusIn) * cos(eDeg * .pi / 180), y: center.y + (r1 + cornerRadiusIn) * sin(eDeg * .pi / 180))
        
        let pRadialInStart = CGPoint(x: center.x + (r1 + cornerRadiusIn) * cos(sDeg * .pi / 180), y: center.y + (r1 + cornerRadiusIn) * sin(sDeg * .pi / 180))
        let pRadialOutStart = CGPoint(x: center.x + (r2 - cornerRadiusOut) * cos(sDeg * .pi / 180), y: center.y + (r2 - cornerRadiusOut) * sin(sDeg * .pi / 180))
        
        // Start and end points of the arc segments
        let pOutArcStart = CGPoint(x: center.x + r2 * cos(sArcOut * .pi / 180), y: center.y + r2 * sin(sArcOut * .pi / 180))
        let pInArcEnd = CGPoint(x: center.x + r1 * cos(eArcIn * .pi / 180), y: center.y + r1 * sin(eArcIn * .pi / 180))
        
        var path = Path()
        
        // Start at outer arc start
        path.move(to: pOutArcStart)
        
        // 1. Outer Arc
        path.addArc(
            center: center,
            radius: r2,
            startAngle: Angle(degrees: sArcOut),
            endAngle: Angle(degrees: eArcOut),
            clockwise: false
        )
        
        // 2. Outer End Fillet (Top-Right outer corner)
        path.addQuadCurve(to: pRadialOutEnd, control: p2)
        
        // 3. Right Radial Edge
        path.addLine(to: pRadialInEnd)
        
        // 4. Inner End Fillet (Bottom-Right inner corner)
        path.addQuadCurve(to: pInArcEnd, control: p3)
        
        // 5. Inner Arc (Concave)
        path.addArc(
            center: center,
            radius: r1,
            startAngle: Angle(degrees: eArcIn),
            endAngle: Angle(degrees: sArcIn),
            clockwise: true
        )
        
        // 6. Inner Start Fillet (Bottom-Left inner corner)
        path.addQuadCurve(to: pRadialInStart, control: p4)
        
        // 7. Left Radial Edge
        path.addLine(to: pRadialOutStart)
        
        // 8. Outer Start Fillet (Top-Left outer corner)
        path.addQuadCurve(to: pOutArcStart, control: p1)
        
        path.closeSubpath()
        return path
    }
}

struct RemoteControlView: View {
    @ObservedObject var languageManager = TR_LanguageManager.shared
    @ObservedObject var deviceManager = DeviceConnectionManager.shared
    @ObservedObject private var airPlayManager = TR_AirPlayManager.shared
    @ObservedObject var remoteVM = TR_RemoteViewModel.shared
    @ObservedObject var voiceManager = VoiceSpeechRecognitionManager.shared
    @ObservedObject var connectivityVM = TR_DeviceConnectivityViewModel.shared
    
    @Binding var isKeyboardActive: Bool
    @AppStorage(TR_SessionKeys.isPro) var isPro = false
    
    var onOpenSettings: () -> Void
    var onOpenDeviceDiscovery: () -> Void
    var onOpenKeypad: () -> Void
    var onOpenKeyboard: () -> Void
    var onOpenInputSource: () -> Void
    var onOpenChannels: () -> Void
    
    @State private var selectedMode: RemoteMode = .dpad
    @State private var cursorVisible: Bool = true
    @State private var isKeyboardVisible: Bool = false
    @State private var keyboardInput: String = ""
    @State private var previousTextInput: String = ""
    @FocusState private var isKeyboardFocused: Bool
    
    // Mic & Voice states
    @State private var showHoldSpeak: Bool = false
    @State private var isLongPressing: Bool = false
    @State private var ignoreNextTap: Bool = false
    
    // Quick Guide sheet state
    @State private var showQuickGuide: Bool = false
    @State private var showAirPlayAlert: Bool = false
    
    // Touch Mouse Trackpad states
    @StateObject private var smMotionManager = TR_AirMouseMotionManager.shared
    @State private var smLastDpadTriggerTime: TimeInterval = 0
    @State private var lastPoint: CGPoint = .zero
    @State private var lastTime: TimeInterval = 0
    @State private var isDragging: Bool = false
    @State private var accumulatedDX: CGFloat = 0
    @State private var accumulatedDY: CGFloat = 0
    @State private var dragStartLocation: CGPoint = .zero
    
    // Dedicated Smooth Scroll Strip State
    @State private var lastScrollY: CGFloat = 0
    @State private var lastScrollX: CGFloat = 0
    @State private var lastScrollTime: TimeInterval = 0
    @State private var lastHScrollTime: TimeInterval = 0
    @State private var scrollAccumulatedDY: CGFloat = 0
    @State private var scrollAccumulatedDX: CGFloat = 0
    @State private var lastScrollTriggerTime: TimeInterval = 0
    @State private var isScrollStripActive: Bool = false
    @State private var isHScrollStripActive: Bool = false
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { UIDevice.isIPad || horizontalSizeClass == .regular }
    
    private var isAirplayActive: Bool {
        airPlayManager.isAirPlayConnected ||
        deviceManager.isAirPlayConnected ||
        remoteVM.connectedTVType == .AIRPLAY ||
        connectivityVM.connectedTvType == .AIRPLAY ||
        AVAudioSession.sharedInstance().currentRoute.outputs.contains(where: { $0.portType == .airPlay })
    }
    
    private var isAndroidTVConnected: Bool {
        remoteVM.connectedTVType == .ANDROID ||
        connectivityVM.getConnectedTvType() == .ANDROID ||
        connectivityVM.connectedTvType == .ANDROID
    }
    
    private var isTVConnected: Bool {
        if isAirplayActive { return false }
        
        return (remoteVM.connectedTVType != nil && remoteVM.connectedTVType != .NONETV) ||
               (connectivityVM.getConnectedTvType() != nil && connectivityVM.getConnectedTvType() != .NONETV) ||
               (deviceManager.connectedDevice != nil && !deviceManager.connectedDevice!.isAirPlay)
    }
    
    private var isMirroringActive: Bool {
        let isBroadcasting = UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") ?? false
        let mode = UserDefaults(suiteName: TR_AppStrings.groupID)?.string(forKey: "broadcastMode") ?? ""
        let isCaptured = UIScreen.main.isCaptured
        return deviceManager.isMirroringActive || isCaptured || (isBroadcasting && (mode == "mirroring" || mode == "camera" || mode == "drawing" || mode.isEmpty))
    }
    
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let cardMaxWidth: CGFloat = isIPad ? (isLandscape ? min(geo.size.width - 32, 600) : min(geo.size.width - 20, 520)) : .infinity
            let topPadding: CGFloat = isIPad ? (isLandscape ? 6 : 8) : 0
            let bottomPadding: CGFloat = isIPad ? (isLandscape ? 115 : 125) : 95
            let totalAvailableHeight = max(geo.size.height - topPadding - bottomPadding, 480)
            
            ZStack {
                // Background tap gesture to dismiss keyboard when clicking outside
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                    }
                
                ScrollView(showsIndicators: false) {
                    ScrollViewReader { proxy in
                        VStack(spacing: isIPad ? (isLandscape ? 12 : 16) : 16) {
                            // 1. Top Header (Power ON/OFF - Choose a TV / Connected - TV Settings)
                            topHeaderView(isLandscape: isLandscape)
                                .frame(maxWidth: .infinity)
                            
                            // 2. Upper Controls Section (VOL Pill - Center 5 Buttons [Home, Mute, Mic, Back, Keypad] - CH Pill)
                            upperControlsSection(isLandscape: isLandscape)
                                .frame(maxWidth: .infinity)
                            
                            // 3. Mode Switcher Bar (D-Pad, Touch/Gesture, Mouse, Keyboard)
                            modeSwitcherBar(isLandscape: isLandscape)
                                .frame(maxWidth: .infinity)
                            
                            // 4. Center Interactive Area (D-Pad with 4 Rounded Petals & OK Button / Touchpad / Swipe / Keyboard)
                            centerModeController(isLandscape: isLandscape)
                                .id("mainRemoteCard")
                                .frame(maxWidth: .infinity)
                                .frame(height: isIPad ? (isLandscape ? 250 : 270) : 218)
                            
                            // 5. Bottom 3 Action Buttons (GUIDE, INPUT, CHANNEL)
                            bottomActionButtons(isLandscape: isLandscape)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: cardMaxWidth)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: totalAvailableHeight, maxHeight: isKeyboardVisible ? .none : (isIPad && isLandscape ? nil : totalAvailableHeight), alignment: .top)
                        .padding(.top, topPadding)
                        .padding(.bottom, bottomPadding)
                        .onChange(of: isKeyboardVisible) { visible in
                            if visible {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo("mainRemoteCard", anchor: .top)
                                }
                            }
                        }
                    }
                }
                .scrollDisabled(!isKeyboardVisible && geo.size.height >= 680)
                .scrollDismissesKeyboard(.interactively)
            }
            .overlay(alignment: .top) {
                // Voice Command Live Recognition Floating Status Bar (Overlay prevents any UI shifting)
                if showHoldSpeak || voiceManager.showRecognizedView {
                    voiceStatusBubbleView
                        .padding(.top, isIPad ? 58 : 46)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .zIndex(100)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    isKeyboardVisible = true
                    isKeyboardActive = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    isKeyboardVisible = false
                    isKeyboardActive = false
                }
            }
            .onChange(of: isKeyboardFocused) { focused in
                withAnimation(.easeInOut(duration: 0.25)) {
                    isKeyboardActive = focused
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .alert(languageManager.localized("microphone_permission_required"), isPresented: $voiceManager.showMicPermissionAlert) {
            Button(languageManager.localized("settings")) {
                voiceManager.openAppSettings()
            }
            Button(languageManager.localized("cancel"), role: .cancel) { }
        } message: {
            Text(languageManager.localized("mic_permission_desc"))
        }
        .alert(languageManager.localized("speech_recognition_permission_required"), isPresented: $voiceManager.showSpeechPermissionAlert) {
            Button(languageManager.localized("settings")) {
                voiceManager.openAppSettings()
            }
            Button(languageManager.localized("cancel"), role: .cancel) { }
        } message: {
            Text(languageManager.localized("speech_recognition_desc"))
        }
        .alert(languageManager.localized("airplay_remote_unavailable"), isPresented: $showAirPlayAlert) {
            Button(languageManager.localized("got_it"), role: .cancel) { }
        } message: {
            Text(languageManager.localized("airplay_remote_unavailable_desc"))
        }
        .sheet(isPresented: $showQuickGuide) {
            TR_QuickGuideView(tvType: remoteVM.connectedTVType)
        }
        .onAppear {
            deviceManager.checkMirroringStatus()
            if selectedMode == .touchMouse {
                smStartAirMouseIfNeeded()
            }
        }
        .onDisappear {
            smStopAirMouse()
        }
        .onChange(of: selectedMode) { newMode in
            if newMode == .touchMouse && isTVConnected {
                smStartAirMouseIfNeeded()
            } else {
                smStopAirMouse()
            }
        }
        .onChange(of: isTVConnected) { connected in
            if connected && selectedMode == .touchMouse {
                smStartAirMouseIfNeeded()
            } else if !connected {
                smStopAirMouse()
            }
        }
    }
    
    // MARK: - Dismiss Keyboard Helper
    private func dismissKeyboard() {
        isKeyboardFocused = false
        isKeyboardVisible = false
        isKeyboardActive = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - 1. Top Header View (Power ON/OFF - Choose a TV / Connected - Settings)
    @ViewBuilder
    private func topHeaderView(isLandscape: Bool) -> some View {
        let btnSize: CGFloat = isIPad ? 50 : 44
        let sideWidth: CGFloat = isIPad ? 72 : 60
        
        HStack(alignment: .center) {
            // Power On/Off Button (Red Circle)
            Button(action: {
                dismissKeyboard()
                triggerHaptic()
                sendRemoteCommand(.POWER)
            }) {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "FF1A1A"))
                            .shadow(color: Color(hex: "FF1A1A").opacity(0.35), radius: 6, x: 0, y: 2)
                        
                        if let _ = UIImage(named: "ic_poweroff") {
                            Image("ic_poweroff")
                                .resizable()
                                .scaledToFit()
                                .frame(width: btnSize * 0.50, height: btnSize * 0.50)
                        } else {
                            Image(systemName: "power")
                                .font(.system(size: btnSize * 0.48, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: btnSize, height: btnSize)
                    
                    Text(languageManager.localized("on_off"))
                        .font(.inter(.bold, size: isIPad ? 12 : 10, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "111827"))
                }
                .frame(width: sideWidth)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94))
            
            Spacer(minLength: 4)
            
            // Center: Choose a TV / Connected Status (True Dead-Center)
            Button(action: {
                dismissKeyboard()
                triggerHaptic()
                onOpenDeviceDiscovery()
            }) {
                VStack(spacing: 3) {
                    let isAirplayActive = airPlayManager.isAirPlayConnected || deviceManager.isAirPlayConnected || AVAudioSession.sharedInstance().currentRoute.outputs.contains(where: { $0.portType == .airPlay })
                    let isSmartTVConnected = !isAirplayActive && (
                        (remoteVM.connectedTVType != nil && remoteVM.connectedTVType != .NONETV) ||
                        (connectivityVM.getConnectedTvType() != nil && connectivityVM.getConnectedTvType() != .NONETV) ||
                        (deviceManager.connectedDevice != nil && !deviceManager.connectedDevice!.isAirPlay)
                    )
                    let isConnected: Bool = isAirplayActive || isSmartTVConnected
                    
                    let activeName: String = {
                        if isAirplayActive {
                            return "AirPlay TV"
                        } else if isSmartTVConnected {
                            return remoteVM.deviceName ?? deviceManager.connectedDevice?.name ?? languageManager.localized("living_room_tv")
                        } else {
                            return "Choose a TV"
                        }
                    }()
                    
                    HStack(spacing: 4) {
                        Text(activeName)
                            .font(.inter(.bold, size: isIPad ? 17 : 14.5, autoScaleForPad: false))
                            .foregroundColor(Color(hex: "111827"))
                            .lineLimit(1)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: isIPad ? 13 : 11, weight: .bold))
                            .foregroundColor(Color(hex: "111827"))
                    }
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isConnected ? Color(hex: "00C853") : Color(hex: "9CA3AF"))
                            .frame(width: isIPad ? 7 : 5.5, height: isIPad ? 7 : 5.5)
                        
                        Text(isConnected ? languageManager.localized("connected") : languageManager.localized("not_connected"))
                            .font(.inter(.medium, size: isIPad ? 12 : 10.5, autoScaleForPad: false))
                            .foregroundColor(isConnected ? Color(hex: "00C853") : Color(hex: "9CA3AF"))
                    }
                }
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.96))
            
            Spacer(minLength: 4)
            
            // Right: TV Settings Button (Clean Liquid Glass Circle)
            Button(action: {
                dismissKeyboard()
                triggerHaptic()
                sendRemoteCommand(.SETTINGS)
            }) {
                VStack(spacing: 4) {
                    ZStack {
                        if let _ = UIImage(named: "ic_remote_setting") {
                            Image("ic_remote_setting")
                                .resizable()
                                .scaledToFit()
                                .frame(width: btnSize * 0.50, height: btnSize * 0.50)
                        } else {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: btnSize * 0.48, weight: .semibold))
                                .foregroundColor(Color(hex: "111827"))
                        }
                    }
                    .frame(width: btnSize, height: btnSize)
                    .glassCard(cornerRadius: btnSize / 2, isInteractive: true)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.0
                            )
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
                    
                    Text(languageManager.localized("settings"))
                        .font(.inter(.bold, size: isIPad ? 12 : 10, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "111827"))
                }
                .frame(width: sideWidth)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94))
        }
        .padding(.horizontal, 0)
    }
    
    // MARK: - Voice Status Bubble View
    private var voiceStatusBubbleView: some View {
        HStack(spacing: 8) {
            if voiceManager.isRecording {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
            let displayText: String = {
                let listeningText = languageManager.localized("listening")
                if showHoldSpeak {
                    return languageManager.localized("hold_and_speak")
                } else if voiceManager.isRecording && (voiceManager.recognizedText.isEmpty || voiceManager.recognizedText == "Listening..." || voiceManager.recognizedText == listeningText) {
                    return listeningText
                } else if !voiceManager.recognizedText.isEmpty {
                    return voiceManager.recognizedText
                } else {
                    return listeningText
                }
            }()
            Text(displayText)
                .font(.inter(.semiBold, size: isIPad ? 15 : 12.5, autoScaleForPad: false))
                .foregroundColor(Color(hex: "111827"))
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .glassCard(cornerRadius: 20, isInteractive: false)
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - 2. Upper Controls Section (VOL Pill - Center 5 Buttons - CH Pill)
    @ViewBuilder
    private func upperControlsSection(isLandscape: Bool) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // Left: Volume Pill
            verticalRockerPill(
                label: "VOL",
                isIPad: isIPad,
                onPlus: {
                    sendRemoteCommand(.VOLUMEUP)
                },
                onMinus: {
                    sendRemoteCommand(.VOLUMEDOWN)
                }
            )
            
            Spacer(minLength: 4)
            
            // Center: 5 Glass Buttons (Home, Mute, Mic, Back, Keypad)
            centerFiveButtonsView(isIPad: isIPad)
            
            Spacer(minLength: 4)
            
            // Right: Channel Pill
            verticalRockerPill(
                label: "CH",
                isIPad: isIPad,
                onPlus: {
                    sendRemoteCommand(.CHANNELUP)
                },
                onMinus: {
                    sendRemoteCommand(.CHANNELDOWN)
                }
            )
        }
        .padding(.horizontal, 0)
    }
    
    // MARK: - Vertical Rocker Pill (+ on Top, Label in Middle, - on Bottom)
    @ViewBuilder
    private func verticalRockerPill(
        label: String,
        isIPad: Bool,
        onPlus: @escaping () -> Void,
        onMinus: @escaping () -> Void
    ) -> some View {
        let width: CGFloat = isIPad ? 78 : 64
        let height: CGFloat = isIPad ? 172 : 160
        let iconSize: CGFloat = isIPad ? 20 : 16
        let btnHeight: CGFloat = height * 0.35
        
        VStack(spacing: 0) {
            // Plus Button (Supports continuous tap & long-press hold repeat)
            RepeatingTouchButton(
                action: {
                    dismissKeyboard()
                    triggerHaptic()
                    if isAirplayActive {
                        showAirPlayAlert = true
                        return
                    }
                    onPlus()
                },
                canRepeat: {
                    return !isAirplayActive && isTVConnected
                }
            ) {
                Image(systemName: "plus")
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(Color(hex: "111827"))
                    .frame(width: width, height: btnHeight)
                    .contentShape(Rectangle())
            }
            
            Spacer(minLength: 0)
            
            // Label (VOL or CH)
            Text(label)
                .font(.inter(.bold, size: isIPad ? 15 : 13, autoScaleForPad: false))
                .foregroundColor(Color(hex: "111827"))
            
            Spacer(minLength: 0)
            
            // Minus Button (Supports continuous tap & long-press hold repeat)
            RepeatingTouchButton(
                action: {
                    dismissKeyboard()
                    triggerHaptic()
                    if isAirplayActive {
                        showAirPlayAlert = true
                        return
                    }
                    onMinus()
                },
                canRepeat: {
                    return !isAirplayActive && isTVConnected
                }
            ) {
                Image(systemName: "minus")
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(Color(hex: "111827"))
                    .frame(width: width, height: btnHeight)
                    .contentShape(Rectangle())
            }
        }
        .frame(width: width, height: height)
        .glassCard(cornerRadius: width / 2, isInteractive: true)
        .overlay(
            RoundedRectangle(cornerRadius: width / 2, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Center 5 Buttons View (Home, Back, Mic, Mute, Keypad with enlarged glass squircle buttons)
    @ViewBuilder
    private func centerFiveButtonsView(isIPad: Bool) -> some View {
        let btnSize: CGFloat = isIPad ? 65 : 55
        let iconSize: CGFloat = isIPad ? 23 : 19.5
        let spacing: CGFloat = isIPad ? 16 : 12
        
        HStack(spacing: spacing) {
            // Left Column: Home (Top), Back (Bottom)
            VStack(spacing: spacing) {
                glassSquircleButton(
                    systemIcon: "house.fill",
                    assetIcon: "ic_remote_home",
                    size: btnSize,
                    iconSize: iconSize,
                    action: {
                        dismissKeyboard()
                        triggerHaptic()
                        sendRemoteCommand(.HOME)
                    }
                )
                
                glassSquircleButton(
                    systemIcon: "arrow.uturn.backward",
                    assetIcon: "ic_remote_back",
                    size: btnSize,
                    iconSize: iconSize,
                    action: {
                        dismissKeyboard()
                        triggerHaptic()
                        sendRemoteCommand(.BACK)
                    }
                )
            }
            
            // Center Column: Mic Button (Centered)
            glassMicSquircleButton(size: btnSize, iconSize: iconSize)
            
            // Right Column: Mute (Top), Keypad (Bottom)
            VStack(spacing: spacing) {
                glassSquircleButton(
                    systemIcon: "speaker.wave.2.fill",
                    assetIcon: "ic_mute",
                    size: btnSize,
                    iconSize: iconSize,
                    action: {
                        dismissKeyboard()
                        triggerHaptic()
                        sendRemoteCommand(.MUTE)
                    }
                )
                
                glassSquircleButton(
                    systemIcon: "circle.grid.3x3.fill",
                    assetIcon: "ic_numberPad",
                    size: btnSize,
                    iconSize: iconSize,
                    action: {
                        dismissKeyboard()
                        triggerHaptic()
                        if isAirplayActive {
                            showAirPlayAlert = true
                            return
                        }
                        if isMirroringActive { return }
                        if !isTVConnected {
                            onOpenDeviceDiscovery()
                            return
                        }
                        onOpenKeypad()
                    }
                )
            }
        }
    }
    
    // MARK: - Glass Squircle Button Helper
    @ViewBuilder
    private func glassSquircleButton(
        systemIcon: String,
        assetIcon: String?,
        size: CGFloat,
        iconSize: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                if let assetName = assetIcon, let _ = UIImage(named: assetName) {
                    Image(assetName)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .foregroundColor(Color(hex: "111827"))
                } else {
                    Image(systemName: systemIcon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(Color(hex: "111827"))
                }
            }
            .frame(width: size, height: size)
            .glassCard(cornerRadius: isIPad ? 18 : 15, isInteractive: true)
            .overlay(
                RoundedRectangle(cornerRadius: isIPad ? 18 : 15, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
    }
    
    // MARK: - Glass Mic Squircle Button with Speech Handling
    @ViewBuilder
    private func glassMicSquircleButton(size: CGFloat, iconSize: CGFloat) -> some View {
        let isRecording = voiceManager.isRecording || isLongPressing
        
        Button(action: {
            dismissKeyboard()
            triggerHaptic()
            if isAirplayActive {
                showAirPlayAlert = true
                return
            }
            if isMirroringActive { return }
            
            if ignoreNextTap {
                ignoreNextTap = false
                return
            }
            if remoteVM.connectedTVType == nil && deviceManager.connectedDevice == nil && !deviceManager.isAirPlayConnected {
                onOpenDeviceDiscovery()
                return
            }
            showHoldSpeak = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showHoldSpeak = false
            }
        }) {
            ZStack {
                if let _ = UIImage(named: "ic_mic") {
                    Image("ic_mic")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .foregroundColor(isRecording ? .white : Color(hex: "111827"))
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(isRecording ? .white : Color(hex: "111827"))
                }
            }
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: isIPad ? 18 : 15, style: .continuous)
                    .fill(isRecording ? AnyShapeStyle(TR_Theme.activeCircleGradient) : AnyShapeStyle(Color.clear))
            )
            .glassCard(cornerRadius: isIPad ? 18 : 15, isInteractive: true)
            .overlay(
                RoundedRectangle(cornerRadius: isIPad ? 18 : 15, style: .continuous)
                    .stroke(
                        isRecording ?
                            LinearGradient(
                                colors: [TR_Theme.primaryPink, TR_Theme.primaryPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: isRecording ? 2.0 : 1.0
                    )
            )
            .shadow(color: isRecording ? TR_Theme.primaryPink.opacity(0.55) : Color.black.opacity(0.03), radius: isRecording ? 8 : 5, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.2)
                .onEnded { _ in
                    if isAirplayActive {
                        showAirPlayAlert = true
                        return
                    }
                    if isMirroringActive { return }
                    ignoreNextTap = true
                    showHoldSpeak = false
                    if remoteVM.connectedTVType == nil && deviceManager.connectedDevice == nil && !deviceManager.isAirPlayConnected {
                        onOpenDeviceDiscovery()
                        return
                    }
                    dismissKeyboard()
                    voiceManager.micTouchDown()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    isLongPressing = false
                    if isMirroringActive { return }
                    if voiceManager.isRecording {
                        dismissKeyboard()
                        voiceManager.micTouchUp(remoteVM: remoteVM)
                    }
                }
        )
    }
    
    // MARK: - 3. Mode Switcher Bar (D-Pad, Touch/Gesture, Mouse, Keyboard)
    @ViewBuilder
    private func modeSwitcherBar(isLandscape: Bool) -> some View {
        let barHeight: CGFloat = isIPad ? 55 : 45
        
        HStack(spacing: 0) {
            ForEach(RemoteMode.allCases, id: \.self) { mode in
                let isSelected = selectedMode == mode
                
                Button(action: {
                    triggerHaptic()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedMode = mode
                        dismissKeyboard()
                    }
                    if mode == .keyboard {
                        if isMirroringActive { return }
                        onOpenKeyboard()
                    }
                }) {
                    ZStack {
                        if isSelected {
                            Capsule()
                                .fill(TR_Theme.activeCircleGradient)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 3)
                                .shadow(color: TR_Theme.primaryPink.opacity(0.4), radius: 6, x: 0, y: 2)
                        }
                        
                        modeIcon(for: mode, isSelected: isSelected)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: barHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94))
            }
        }
        .padding(isIPad ? 4 : 3)
        .glassCard(cornerRadius: barHeight / 2, isInteractive: true)
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 0)
    }
    
    // MARK: - Mode Icon Helper
    @ViewBuilder
    private func modeIcon(for mode: RemoteMode, isSelected: Bool) -> some View {
        let iconSize: CGFloat = isIPad ? 24 : 19
        
        switch mode {
        case .dpad:
            let imgName = isSelected ? "ic_control_selected" : "ic_control"
            if let _ = UIImage(named: imgName) {
                Image(imgName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
            } else {
                Image(systemName: "circle.grid.cross.fill")
                    .font(.system(size: iconSize, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : Color(hex: "7B8293"))
            }
        case .touchMouse:
            let imgName = isSelected ? "ic_mouse_selected" : "ic_mouse"
            if let _ = UIImage(named: imgName) {
                Image(imgName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
            } else {
                Image(systemName: "computermouse.fill")
                    .font(.system(size: iconSize, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : Color(hex: "7B8293"))
            }
        case .swipePad:
            let imgName = isSelected ? "ic_Smoothly_swipe_selected" : "ic_Smoothly_swipe"
            if let _ = UIImage(named: imgName) {
                Image(imgName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
            } else {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: iconSize, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : Color(hex: "7B8293"))
            }
        case .keyboard:
            let imgName = isSelected ? "ic_keyboard_selected" : "ic_keyboard"
            if let _ = UIImage(named: imgName) {
                Image(imgName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
            } else {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: iconSize, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : Color(hex: "7B8293"))
            }
        }
    }
    
    // MARK: - 4. Center Interactive Mode Controller
    @ViewBuilder
    private func centerModeController(isLandscape: Bool) -> some View {
        switch selectedMode {
        case .dpad:
            dpadControllerView(isLandscape: isLandscape)
        case .touchMouse:
            touchMouseTrackpadView
        case .swipePad:
            swipePadTrackpadView
        case .keyboard:
            keyboardCenterCardView
        }
    }
    
    // MARK: - D-Pad Controller with Rounded Annular Sector Petals & Center OK Button
    @ViewBuilder
    private func dpadControllerView(isLandscape: Bool) -> some View {
        let dialSize: CGFloat = isIPad ? (isLandscape ? 240 : 260) : 202
        let outerRadius: CGFloat = dialSize / 2
        let centerOkSize: CGFloat = isIPad ? 82 : 66
        let centerOkRadius: CGFloat = centerOkSize / 2
        let innerRadius: CGFloat = centerOkRadius + 15 // Uniform smooth gap framing the OK button
        let midRadius: CGFloat = (innerRadius + outerRadius) / 2
        let arrowSize: CGFloat = isIPad ? 22 : 17
        let cornerRadiusOut: CGFloat = isIPad ? 15 : 12
        let cornerRadiusIn: CGFloat = isIPad ? 10 : 8
        
        let glassStrokeGradient = LinearGradient(
            colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        ZStack {
            // Top Petal (Up)
            dpadPetalButton(
                centerAngle: 270,
                direction: .DPAD_UP,
                arrowSystemName: "arrowtriangle.up.fill",
                offset: CGSize(width: 0, height: -midRadius),
                innerRadius: innerRadius,
                outerRadius: outerRadius,
                cornerRadiusOut: cornerRadiusOut,
                cornerRadiusIn: cornerRadiusIn,
                dialSize: dialSize,
                arrowSize: arrowSize
            )
            
            // Bottom Petal (Down)
            dpadPetalButton(
                centerAngle: 90,
                direction: .DPAD_DOWN,
                arrowSystemName: "arrowtriangle.down.fill",
                offset: CGSize(width: 0, height: midRadius),
                innerRadius: innerRadius,
                outerRadius: outerRadius,
                cornerRadiusOut: cornerRadiusOut,
                cornerRadiusIn: cornerRadiusIn,
                dialSize: dialSize,
                arrowSize: arrowSize
            )
            
            // Left Petal (Left)
            dpadPetalButton(
                centerAngle: 180,
                direction: .DPAD_LEFT,
                arrowSystemName: "arrowtriangle.left.fill",
                offset: CGSize(width: -midRadius, height: 0),
                innerRadius: innerRadius,
                outerRadius: outerRadius,
                cornerRadiusOut: cornerRadiusOut,
                cornerRadiusIn: cornerRadiusIn,
                dialSize: dialSize,
                arrowSize: arrowSize
            )
            
            // Right Petal (Right)
            dpadPetalButton(
                centerAngle: 0,
                direction: .DPAD_RIGHT,
                arrowSystemName: "arrowtriangle.right.fill",
                offset: CGSize(width: midRadius, height: 0),
                innerRadius: innerRadius,
                outerRadius: outerRadius,
                cornerRadiusOut: cornerRadiusOut,
                cornerRadiusIn: cornerRadiusIn,
                dialSize: dialSize,
                arrowSize: arrowSize
            )
            
            // Center "OK" Button (Circular Gradient with Pink Glow & Specular Glass Rim)
            Button(action: {
                dismissKeyboard()
                triggerHaptic()
                sendRemoteCommand(.OK)
            }) {
                ZStack {
                    Circle()
                        .fill(TR_Theme.activeCircleGradient)
                        .overlay(
                            Circle()
                                .stroke(glassStrokeGradient, lineWidth: 1.2)
                        )
                        .shadow(color: TR_Theme.primaryPink.opacity(0.45), radius: 10, x: 0, y: 4)
                    
                    Text("OK")
                        .font(.inter(.bold, size: isIPad ? 22 : 18, autoScaleForPad: false))
                        .foregroundColor(.white)
                }
                .frame(width: centerOkSize, height: centerOkSize)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
        }
        .frame(width: dialSize, height: dialSize)
    }
    
    // MARK: - D-Pad Petal Button Helper with Pure Liquid Glass Effect
    @ViewBuilder
    private func dpadPetalButton(
        centerAngle: Double,
        direction: TR_RemoteKey,
        arrowSystemName: String,
        offset: CGSize,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        cornerRadiusOut: CGFloat,
        cornerRadiusIn: CGFloat,
        dialSize: CGFloat,
        arrowSize: CGFloat
    ) -> some View {
        let shape = RoundedAnnularSector(
            centerAngle: centerAngle,
            innerRadius: innerRadius,
            outerRadius: outerRadius,
            sweepAngle: 76.0,
            cornerRadiusOut: cornerRadiusOut,
            cornerRadiusIn: cornerRadiusIn
        )
        
        Button(action: {
            dismissKeyboard()
            triggerHaptic()
            sendRemoteCommand(direction)
        }) {
            ZStack {
                Color.clear
                    .frame(width: dialSize, height: dialSize)
                    .glassShape(shape, isInteractive: true)
                    .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                
                Image(systemName: arrowSystemName)
                    .font(.system(size: arrowSize, weight: .bold))
                    .foregroundColor(Color(hex: "1F242F"))
                    .offset(offset)
            }
            .frame(width: dialSize, height: dialSize)
            .contentShape(shape)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94))
    }
    
    // MARK: - Mode 1: Touch Mouse Trackpad
    private var touchMouseTrackpadView: some View {
        ZStack {
            // Center instruction text
            VStack(spacing: 4) {
                Text(languageManager.localized("mouse").uppercased())
                    .font(.inter(.bold, size: isIPad ? 15 : 13, autoScaleForPad: false))
                    .tracking(2.5)
                    .foregroundColor(Color(hex: "788292"))
                
                Text("Control Your TV with a Touch Mouse")
                    .font(.inter(.regular, size: isIPad ? 12 : 10.5, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "9CA3AF"))
            }
            .multilineTextAlignment(.center)
            .padding(.trailing, isIPad ? 46 : 38)
            .padding(.bottom, isIPad ? 44 : 36)
            
            // Main Trackpad Drag Gesture (moving cursor & click tap)
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dismissKeyboard()
                            if isAirplayActive {
                                showAirPlayAlert = true
                                return
                            }
                            if isMirroringActive { return }
                            guard isTVConnected else { return }
                            
                            let currentTime = Date().timeIntervalSince1970
                            if !isDragging {
                                lastPoint = value.location
                                lastTime = currentTime
                                isDragging = true
                                accumulatedDX = 0
                                accumulatedDY = 0
                                dragStartLocation = value.startLocation
                                return
                            }
                            
                            let dx = value.location.x - lastPoint.x
                            let dy = value.location.y - lastPoint.y
                            let dt = currentTime - lastTime
                            
                            handleTrackpadMovement(dx: dx, dy: dy, dt: dt)
                            
                            lastPoint = value.location
                            lastTime = currentTime
                        }
                        .onEnded { value in
                            if isAirplayActive {
                                showAirPlayAlert = true
                                return
                            }
                            if isMirroringActive { return }
                            guard isTVConnected else {
                                triggerHaptic()
                                onOpenDeviceDiscovery()
                                return
                            }
                            
                            let totalDist = hypot(value.location.x - dragStartLocation.x, value.location.y - dragStartLocation.y)
                            if totalDist < 12 {
                                triggerHaptic()
                                if remoteVM.connectedTVType == .LG || remoteVM.connectedTVType == .SAMSUNG {
                                    remoteVM.clickCursor()
                                } else {
                                    sendRemoteCommand(.OK)
                                }
                            }
                            
                            lastPoint = .zero
                            lastTime = 0
                            isDragging = false
                            accumulatedDX = 0
                            accumulatedDY = 0
                        }
                )
            
            // Vertical Scroll Strip (Trailing Right Side)
            VStack {
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    verticalScrollStrip
                }
            }
            
            // Horizontal Scroll Strip (Bottom Left Side)
            VStack {
                Spacer(minLength: 0)
                HStack {
                    horizontalScrollStrip
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassCard(cornerRadius: isIPad ? 24 : 20, isInteractive: true)
        .overlay(
            RoundedRectangle(cornerRadius: isIPad ? 24 : 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Vertical Scroll Strip
    private var verticalScrollStrip: some View {
        let stripWidth: CGFloat = isIPad ? 46 : 38
        
        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isScrollStripActive ? Color.blue.opacity(0.18) : Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.blue.opacity(isScrollStripActive ? 0.35 : 0.15), lineWidth: 1)
                )
                .padding(.vertical, 6)
            
            VStack(spacing: isIPad ? 50 : 36) {
                Image(systemName: "chevron.up")
                    .font(.system(size: isIPad ? 13 : 11, weight: .bold))
                    .foregroundColor(Color(hex: "6B7280"))
                
                Text("SCROLL")
                    .font(.system(size: isIPad ? 10 : 8.5, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(Color(hex: "6B7280"))
                    .rotationEffect(.degrees(90))
                    .fixedSize()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: isIPad ? 13 : 11, weight: .bold))
                    .foregroundColor(Color(hex: "6B7280"))
            }
            .allowsHitTesting(false)
            
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dismissKeyboard()
                            if isAirplayActive {
                                showAirPlayAlert = true
                                return
                            }
                            if isMirroringActive { return }
                            guard isTVConnected else { return }
                            
                            if !self.isScrollStripActive {
                                withAnimation(.easeIn(duration: 0.08)) {
                                    self.isScrollStripActive = true
                                }
                            }
                            let currentY = value.location.y
                            let currentTime = Date().timeIntervalSince1970
                            if self.lastScrollY == 0 {
                                self.lastScrollY = currentY
                                self.lastScrollTime = currentTime
                                return
                            }
                            let dy = currentY - self.lastScrollY
                            let dt = max(currentTime - self.lastScrollTime, 0.003)
                            self.lastScrollY = currentY
                            self.lastScrollTime = currentTime
                            processMouseScroll(dx: 0, dy: dy, dt: dt)
                        }
                        .onEnded { value in
                            if isAirplayActive {
                                showAirPlayAlert = true
                                return
                            }
                            if isMirroringActive { return }
                            guard isTVConnected else {
                                triggerHaptic()
                                onOpenDeviceDiscovery()
                                return
                            }
                            
                            let totalDist = hypot(value.translation.width, value.translation.height)
                            if totalDist < 8 {
                                let midY = CGFloat(100)
                                triggerHaptic()
                                if value.location.y < midY {
                                    remoteVM.scrollCursor(dx: 0, dy: 1)
                                } else {
                                    remoteVM.scrollCursor(dx: 0, dy: -1)
                                }
                            }
                            self.lastScrollY = 0
                            self.scrollAccumulatedDY = 0
                            if self.isScrollStripActive {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    self.isScrollStripActive = false
                                }
                            }
                        }
                )
        }
        .frame(width: stripWidth)
        .frame(maxHeight: .infinity)
        .padding(.trailing, 8)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
    
    // MARK: - Horizontal Scroll Strip
    private var horizontalScrollStrip: some View {
        let stripHeight: CGFloat = isIPad ? 42 : 36
        
        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHScrollStripActive ? Color.blue.opacity(0.18) : Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.blue.opacity(isHScrollStripActive ? 0.35 : 0.15), lineWidth: 1)
                )
                .padding(.horizontal, 6)
            
            HStack(spacing: isIPad ? 50 : 36) {
                Image(systemName: "chevron.left")
                    .font(.system(size: isIPad ? 13 : 11, weight: .bold))
                    .foregroundColor(Color(hex: "6B7280"))
                
                Text("SCROLL")
                    .font(.system(size: isIPad ? 10 : 8.5, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(Color(hex: "6B7280"))
                    .fixedSize()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: isIPad ? 13 : 11, weight: .bold))
                    .foregroundColor(Color(hex: "6B7280"))
            }
            .allowsHitTesting(false)
            
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dismissKeyboard()
                            if isAirplayActive {
                                showAirPlayAlert = true
                                return
                            }
                            if isMirroringActive { return }
                            guard isTVConnected else { return }
                            
                            if !self.isHScrollStripActive {
                                withAnimation(.easeIn(duration: 0.08)) {
                                    self.isHScrollStripActive = true
                                }
                            }
                            let currentX = value.location.x
                            let currentTime = Date().timeIntervalSince1970
                            if self.lastScrollX == 0 {
                                self.lastScrollX = currentX
                                self.lastHScrollTime = currentTime
                                return
                            }
                            let dx = currentX - self.lastScrollX
                            let dt = max(currentTime - self.lastHScrollTime, 0.003)
                            self.lastScrollX = currentX
                            self.lastHScrollTime = currentTime
                            processMouseScroll(dx: dx, dy: 0, dt: dt)
                        }
                        .onEnded { value in
                            if isAirplayActive {
                                showAirPlayAlert = true
                                return
                            }
                            if isMirroringActive { return }
                            guard isTVConnected else {
                                triggerHaptic()
                                onOpenDeviceDiscovery()
                                return
                            }
                            
                            let totalDist = hypot(value.translation.width, value.translation.height)
                            if totalDist < 8 {
                                let midX = CGFloat(100)
                                triggerHaptic()
                                if value.location.x < midX {
                                    remoteVM.scrollCursor(dx: 1, dy: 0)
                                } else {
                                    remoteVM.scrollCursor(dx: -1, dy: 0)
                                }
                            }
                            self.lastScrollX = 0
                            self.scrollAccumulatedDX = 0
                            if self.isHScrollStripActive {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    self.isHScrollStripActive = false
                                }
                            }
                        }
                )
        }
        .frame(height: stripHeight)
        .padding(.leading, 8)
        .padding(.trailing, isIPad ? 58 : 50)
        .padding(.bottom, 8)
    }
    
    // MARK: - Mouse Scroll Processing
    private func processMouseScroll(dx: CGFloat = 0, dy: CGFloat = 0, dt: TimeInterval) {
        if abs(dy) > 0.12 {
            if (dy > 0 && scrollAccumulatedDY < 0) || (dy < 0 && scrollAccumulatedDY > 0) {
                scrollAccumulatedDY = 0
            }
            scrollAccumulatedDY += dy * 1.2
        }
        if abs(dx) > 0.12 {
            if (dx > 0 && scrollAccumulatedDX < 0) || (dx < 0 && scrollAccumulatedDX > 0) {
                scrollAccumulatedDX = 0
            }
            scrollAccumulatedDX += dx * 1.2
        }
        
        let threshold: CGFloat = 10.0
        let now = Date().timeIntervalSince1970
        guard now - lastScrollTriggerTime >= 0.085 else { return }
        
        if abs(scrollAccumulatedDY) >= threshold {
            let isDown = scrollAccumulatedDY > 0
            scrollAccumulatedDY = 0
            lastScrollTriggerTime = now
            triggerHaptic()
            remoteVM.scrollCursor(dx: 0, dy: isDown ? -1 : 1)
        } else if abs(scrollAccumulatedDX) >= threshold {
            let isRight = scrollAccumulatedDX > 0
            scrollAccumulatedDX = 0
            lastScrollTriggerTime = now
            triggerHaptic()
            remoteVM.scrollCursor(dx: isRight ? -1 : 1, dy: 0)
        }
    }
    
    // MARK: - Mode 2: Swipe Pad Trackpad
    private var swipePadTrackpadView: some View {
        ZStack {
            Text(languageManager.localized("touchpad").uppercased())
                .font(.inter(.medium, size: isIPad ? 16 : 14, autoScaleForPad: false))
                .tracking(2.5)
                .foregroundColor(Color(hex: "788292"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassCard(cornerRadius: isIPad ? 24 : 20, isInteractive: true)
        .overlay(
            RoundedRectangle(cornerRadius: isIPad ? 24 : 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
            triggerHaptic()
            if isAirplayActive {
                showAirPlayAlert = true
                return
            }
            sendRemoteCommand(.OK)
        }
        .gesture(
            DragGesture(minimumDistance: 15)
                .onEnded { value in
                    dismissKeyboard()
                    triggerHaptic()
                    if isAirplayActive {
                        showAirPlayAlert = true
                        return
                    }
                    
                    let h: CGFloat = value.translation.width
                    let v: CGFloat = value.translation.height
                    if abs(h) > abs(v) {
                        if h > 25 { sendRemoteCommand(.DPAD_RIGHT) }
                        else if h < -25 { sendRemoteCommand(.DPAD_LEFT) }
                    } else {
                        if v > 25 { sendRemoteCommand(.DPAD_DOWN) }
                        else if v < -25 { sendRemoteCommand(.DPAD_UP) }
                    }
                }
        )
    }
    
    // MARK: - Mode 3: Interactive Keyboard Card
    private var keyboardCenterCardView: some View {
        ZStack {
            VStack(spacing: 4) {
                HStack(alignment: .center, spacing: 1) {
                    if keyboardInput.isEmpty {
                        Text("|")
                            .font(.system(size: isIPad ? 28 : 20, weight: .light, design: .monospaced))
                            .foregroundColor(cursorVisible ? Color(hex: "111827") : .clear)
                    } else {
                        Text(keyboardInput)
                            .font(.inter(.bold, size: isIPad ? 18 : 14.5, autoScaleForPad: false))
                            .foregroundColor(Color(hex: "111827"))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        
                        Text("|")
                            .font(.system(size: isIPad ? 20 : 16, weight: .light, design: .monospaced))
                            .foregroundColor(cursorVisible ? TR_Theme.primaryPurple : .clear)
                    }
                }
                .padding(.horizontal, 10)
                
                if !keyboardInput.isEmpty {
                    Button(action: {
                        triggerHaptic()
                        keyboardInput = ""
                        previousTextInput = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: isIPad ? 18 : 13))
                            .foregroundColor(Color(hex: "9CA3AF"))
                    }
                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.90))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassCard(cornerRadius: isIPad ? 24 : 18, isInteractive: true)
        .overlay(
            RoundedRectangle(cornerRadius: isIPad ? 24 : 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            triggerHaptic()
            onOpenKeyboard()
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                cursorVisible.toggle()
            }
        }
    }
    
    // MARK: - 5. Bottom 3 Action Buttons (GUIDE, INPUT, CHANNEL)
    @ViewBuilder
    private func bottomActionButtons(isLandscape: Bool) -> some View {
        let btnHeight: CGFloat = isIPad ? 44 : 36
        
        HStack(spacing: isIPad ? 14 : 10) {
            // Guide Button
            glassActionCapsuleButton(
                title: languageManager.localized("guide").uppercased(),
                height: btnHeight,
                action: {
                    dismissKeyboard()
                    triggerHaptic()
                    if isAirplayActive {
                        showAirPlayAlert = true
                        return
                    }
                    if isMirroringActive { return }
                    showQuickGuide = true
                }
            )
            
            // Input Button (Hidden when Android TV is connected)
            if !isAndroidTVConnected {
                glassActionCapsuleButton(
                    title: languageManager.localized("input").uppercased(),
                    height: btnHeight,
                    action: {
                        dismissKeyboard()
                        triggerHaptic()
                        if isAirplayActive {
                            showAirPlayAlert = true
                            return
                        }
                        if isMirroringActive { return }
                        if !isTVConnected {
                            onOpenDeviceDiscovery()
                            return
                        }
                        onOpenInputSource()
                    }
                )
            }
            
            // Channel Button
            glassActionCapsuleButton(
                title: languageManager.localized("channel").uppercased(),
                height: btnHeight,
                action: {
                    dismissKeyboard()
                    triggerHaptic()
                    if isAirplayActive {
                        showAirPlayAlert = true
                        return
                    }
                    if isMirroringActive { return }
                    if !isTVConnected {
                        onOpenDeviceDiscovery()
                        return
                    }
                    onOpenChannels()
                }
            )
        }
        .padding(.horizontal, 0)
    }
    
    // MARK: - Glass Action Capsule Button Helper
    @ViewBuilder
    private func glassActionCapsuleButton(title: String, height: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.inter(.bold, size: isIPad ? 14 : 12, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "111827"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .glassCard(cornerRadius: height / 2, isInteractive: true)
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94))
    }
    
    // MARK: - Air Mouse Motion Control
    private func smStartAirMouseIfNeeded() {
        guard selectedMode == .touchMouse, isTVConnected else {
            smStopAirMouse()
            return
        }
        smMotionManager.startAirMouseUpdates { dx, dy, dt in
            if isMirroringActive { return }
            guard isTVConnected else {
                smStopAirMouse()
                return
            }
            guard !isDragging && !isScrollStripActive && !isHScrollStripActive else { return }
            handleTrackpadMovement(dx: dx, dy: dy, dt: dt)
        }
    }
    
    private func smStopAirMouse() {
        smMotionManager.stopAirMouseUpdates()
    }
    
    // MARK: - Touch Mouse Movement with Dynamic Velocity
    private func handleTrackpadMovement(dx: CGFloat, dy: CGFloat, dt: TimeInterval) {
        if isAirplayActive {
            showAirPlayAlert = true
            return
        }
        
        switch remoteVM.connectedTVType {
        case .LG, .SAMSUNG:
            let finalDX = Float(dx * 1.35)
            let finalDY = Float(dy * 1.35)
            remoteVM.moveCursor(dx: finalDX, dy: finalDY)
            
        default:
            accumulatedDX += dx
            accumulatedDY += dy
            
            let smDragThreshold: CGFloat = isAndroidTVConnected ? 48.0 : 40.0
            accumulatedDX = min(max(accumulatedDX, -smDragThreshold * 1.5), smDragThreshold * 1.5)
            accumulatedDY = min(max(accumulatedDY, -smDragThreshold * 1.5), smDragThreshold * 1.5)
            
            let currentTime = Date().timeIntervalSince1970
            let minInterval: TimeInterval = isAndroidTVConnected ? 0.32 : 0.28
            guard currentTime - smLastDpadTriggerTime >= minInterval else {
                return
            }
            
            if abs(accumulatedDX) >= smDragThreshold || abs(accumulatedDY) >= smDragThreshold {
                smLastDpadTriggerTime = currentTime
                
                if abs(accumulatedDX) > abs(accumulatedDY) {
                    if accumulatedDX > 0 {
                        sendRemoteCommand(.DPAD_RIGHT)
                    } else {
                        sendRemoteCommand(.DPAD_LEFT)
                    }
                } else {
                    if accumulatedDY > 0 {
                        sendRemoteCommand(.DPAD_DOWN)
                    } else {
                        sendRemoteCommand(.DPAD_UP)
                    }
                }
                
                accumulatedDX = 0
                accumulatedDY = 0
            }
        }
    }
    
    // MARK: - Keyboard Real-time Typing Handler
    private func handleTextInputChange(_ newValue: String) {
        if isMirroringActive {
            keyboardInput = ""
            return
        }

        if isAirplayActive {
            showAirPlayAlert = true
            return
        }
        
        if newValue.count < previousTextInput.count {
            let diff = previousTextInput.count - newValue.count
            for _ in 0..<diff {
                remoteVM.sendBackspace()
            }
        } else if newValue.count > previousTextInput.count {
            let addedText = String(newValue.suffix(newValue.count - previousTextInput.count))
            remoteVM.typeTextOnTV(addedText)
        }
        previousTextInput = newValue
    }
    
    // MARK: - Command Execution
    private let freeKeys: Set<TR_RemoteKey> = [
        .POWER,
        .HOME,
        .DPAD_UP,
        .DPAD_DOWN,
        .DPAD_LEFT,
        .DPAD_RIGHT,
        .VOLUMEUP,
        .VOLUMEDOWN
    ]
    
    private func sendRemoteCommand(_ key: TR_RemoteKey) {
        if isMirroringActive {
            triggerHaptic()
            return
        }
        triggerHaptic()
        
        if isAirplayActive {
            showAirPlayAlert = true
            return
        }
        
        if !isTVConnected {
            onOpenDeviceDiscovery()
            return
        }
        
        if key == .VOLUMEUP {
            TVVolumeManager.shared.sendVolumeUp()
            return
        }
        if key == .VOLUMEDOWN {
            TVVolumeManager.shared.sendVolumeDown()
            return
        }
        if key == .MUTE {
            TVVolumeManager.shared.toggleMute()
            return
        }
        
        remoteVM.sendCommand(key)
    }
    
    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Xcode Preview
struct RemoteControlView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Image("BG")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            RemoteControlView(
                isKeyboardActive: .constant(false),
                onOpenSettings: {},
                onOpenDeviceDiscovery: {},
                onOpenKeypad: {},
                onOpenKeyboard: {},
                onOpenInputSource: {},
                onOpenChannels: {}
            )
        }
    }
}

// MARK: - Repeating Touch Button (Supports continuous tap & long-press hold repeat for Volume / Channels)
struct RepeatingTouchButton<Content: View>: View {
    let action: () -> Void
    var canRepeat: (() -> Bool)? = nil
    let content: () -> Content
    
    @State private var isPressed = false
    @State private var timer: Timer? = nil
    
    init(
        action: @escaping () -> Void,
        canRepeat: (() -> Bool)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.action = action
        self.canRepeat = canRepeat
        self.content = content
    }
    
    var body: some View {
        content()
            .scaleEffect(isPressed ? 0.88 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            action()
                            if canRepeat?() ?? true {
                                startRepeating()
                            }
                        }
                    }
                    .onEnded { _ in
                        stopRepeating()
                        isPressed = false
                    }
            )
    }
    
    private func startRepeating() {
        stopRepeating()
        // Wait 0.35s before starting repeated triggers
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { _ in
            guard self.isPressed else { return }
            guard self.canRepeat?() ?? true else {
                self.stopRepeating()
                return
            }
            self.action()
            // Repeat every 0.15s while still pressed
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
                guard self.isPressed else {
                    self.stopRepeating()
                    return
                }
                guard self.canRepeat?() ?? true else {
                    self.stopRepeating()
                    return
                }
                self.action()
            }
        }
    }
    
    private func stopRepeating() {
        timer?.invalidate()
        timer = nil
    }
}
