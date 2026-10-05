//
//  KeypadSheetView.swift
//  TV Remote
//
//  Created by iOS Developer on 02/10/2026.
//

import SwiftUI

struct KeypadSheetView: View {
    @Binding var channelInput: String
    var isTVConnected: Bool = true
    var onOpenConnectTV: (() -> Void)? = nil
    var onDismiss: () -> Void
    
    @ObservedObject private var languageManager = TR_LanguageManager.shared
    @State private var isCursorVisible: Bool = true
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { horizontalSizeClass == .regular }
    
    private let glassStrokeGradient = LinearGradient(
        colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let numGrid: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"]
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Header (Keypad Icon + Title + Subtitle + Close 'X' Button)
            headerView
                .padding(.top, 16)
            
            // "Type here..." Frosted Glass Input Box (No native keyboard popup)
            inputBoxView
            
            // 3x4 Number Keypad Grid
            keypadGridLayoutView
        }
        .padding(.horizontal, isIPad ? 24 : 16)
        .padding(.bottom, isIPad ? 32 : 24)
        .frame(maxWidth: isIPad ? 500 : .infinity)
        .background(
            ZStack {
                // Pure Liquid Glass Container
                CustomRoundedCorners(radius: 32, corners: [.topLeft, .topRight])
                    .fill(.ultraThinMaterial)
                
                CustomRoundedCorners(radius: 32, corners: [.topLeft, .topRight])
                    .fill(Color.white.opacity(0.35))
            }
            .clipShape(CustomRoundedCorners(radius: 32, corners: [.topLeft, .topRight]))
            .overlay(
                CustomRoundedCorners(radius: 32, corners: [.topLeft, .topRight])
                    .stroke(glassStrokeGradient, lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: -6)
            .ignoresSafeArea(edges: .bottom)
        )
        .onAppear {
            channelInput = ""
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                isCursorVisible.toggle()
            }
        }
        .onDisappear {
            channelInput = ""
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            // Keypad Icon
            Image(systemName: "circle.grid.3x3.fill")
                .font(.system(size: isIPad ? 22 : 18, weight: .bold))
                .foregroundColor(Color(hex: "111827"))
            
            // Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(languageManager.localized("keypad"))
                    .font(.inter(.bold, size: isIPad ? 19 : 16.5, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "111827"))
                
                Text(languageManager.localized("enter_numbers_quickly"))
                    .font(.inter(.regular, size: isIPad ? 13 : 11.5, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "788292"))
            }
            
            Spacer()
            
            // Close 'X' Button
            Button(action: {
                triggerHaptic()
                channelInput = ""
                onDismiss()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.50))
                        .frame(width: isIPad ? 36 : 32, height: isIPad ? 36 : 32)
                        .glassCard(cornerRadius: 18, isInteractive: true)
                        .overlay(
                            Circle()
                                .stroke(glassStrokeGradient, lineWidth: 1.0)
                        )
                        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: isIPad ? 13 : 11.5, weight: .bold))
                        .foregroundColor(Color(hex: "111827"))
                }
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Input Box View
    private var inputBoxView: some View {
        HStack(spacing: 8) {
            // Text Display with Blinking Cursor
            if channelInput.isEmpty {
                HStack(spacing: 2) {
                    if isCursorVisible {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(LinearGradient(colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")], startPoint: .top, endPoint: .bottom))
                            .frame(width: 2, height: 18)
                    }
                    
                    Text(languageManager.localized("type_here"))
                        .font(.inter(.regular, size: isIPad ? 16 : 14.5, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
            } else {
                HStack(spacing: 2) {
                    Text(channelInput)
                        .font(.inter(.bold, size: isIPad ? 18 : 16, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "111827"))
                        .lineLimit(1)
                    
                    if isCursorVisible {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(LinearGradient(colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")], startPoint: .top, endPoint: .bottom))
                            .frame(width: 2, height: 18)
                    }
                }
            }
            
            Spacer(minLength: 4)
            
            // Clear text button (if typed)
            if !channelInput.isEmpty {
                Button(action: {
                    triggerHaptic()
                    channelInput = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: isIPad ? 18 : 15))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.90))
            }
            
            // Mic icon
            Image(systemName: "mic.fill")
                .font(.system(size: isIPad ? 17 : 14, weight: .medium))
                .foregroundColor(Color(hex: "6B7280"))
        }
        .padding(.horizontal, 16)
        .frame(height: isIPad ? 52 : 46)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.40))
        )
        .glassCard(cornerRadius: 16, isInteractive: false)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(glassStrokeGradient, lineWidth: 1.0)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
    }
    
    // MARK: - Keypad Grid Layout View (4 Rows x 3 Columns)
    private var keypadGridLayoutView: some View {
        let keyHeight: CGFloat = isIPad ? 68 : 56
        
        return VStack(spacing: 12) {
            // Rows 1-3: Numbers 1 to 9
            ForEach(numGrid, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { num in
                        numberKeyButton(num: num, height: keyHeight)
                    }
                }
            }
            
            // Row 4: [Delete], [0], [Enter]
            HStack(spacing: 12) {
                // Delete Key
                Button(action: {
                    triggerHaptic()
                    if !channelInput.isEmpty {
                        channelInput.removeLast()
                    }
                    if isTVConnected {
                        TR_RemoteViewModel.shared.sendBackspace()
                    }
                }) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.40))
                        .frame(maxWidth: .infinity)
                        .frame(height: keyHeight)
                        .glassCard(cornerRadius: 16, isInteractive: true)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(glassStrokeGradient, lineWidth: 1.0)
                        )
                        .overlay(
                            Image(systemName: "delete.backward.fill")
                                .font(.system(size: isIPad ? 22 : 18))
                                .foregroundColor(Color(hex: "111827"))
                        )
                        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94))
                
                // 0 Key
                numberKeyButton(num: "0", height: keyHeight)
                
                // Enter Button (Pink/Purple Gradient)
                Button(action: {
                    handleEnterAction()
                }) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(TR_Theme.activeCircleGradient)
                        .frame(maxWidth: .infinity)
                        .frame(height: keyHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(glassStrokeGradient, lineWidth: 1.0)
                        )
                        .overlay(
                            Text(languageManager.localized("enter_btn"))
                                .font(.inter(.bold, size: isIPad ? 19 : 16.5, autoScaleForPad: false))
                                .foregroundColor(.white)
                        )
                        .shadow(color: TR_Theme.primaryPink.opacity(0.40), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
            }
        }
    }
    
    // MARK: - Number Key Button Helper
    @ViewBuilder
    private func numberKeyButton(num: String, height: CGFloat) -> some View {
        Button(action: {
            triggerHaptic()
            if channelInput.count < 8 {
                channelInput.append(num)
            }
            if isTVConnected {
                TR_RemoteViewModel.shared.sendSingleDigit(num)
            }
        }) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.40))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .glassCard(cornerRadius: 16, isInteractive: true)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(glassStrokeGradient, lineWidth: 1.0)
                )
                .overlay(
                    Text(num)
                        .font(.inter(.bold, size: isIPad ? 26 : 22, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "111827"))
                )
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94))
    }
    
    // MARK: - Enter Action Handler
    private func handleEnterAction() {
        triggerHaptic()
        if !isTVConnected {
            channelInput = ""
            onDismiss()
            onOpenConnectTV?()
        } else {
            TR_RemoteViewModel.shared.sendCommand(.OK)
            channelInput = ""
            onDismiss()
        }
    }
    
    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
