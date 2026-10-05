//
//  KeyboardSheetView.swift
//  TV Remote
//
//  Created by iOS Developer on 02/10/2026.
//

import SwiftUI

enum KeyboardInputMode {
    case letters
    case numbers
    case emoji
}

struct KeyboardSheetView: View {
    @Binding var typedText: String
    var isTVConnected: Bool
    var onKeyTyped: ((String) -> Void)? = nil
    var onBackspace: (() -> Void)? = nil
    var onSend: ((String) -> Void)? = nil
    var onOpenConnectTV: (() -> Void)? = nil
    var onDismiss: () -> Void
    
    @ObservedObject private var languageManager = TR_LanguageManager.shared
    @State private var previousText: String = ""
    @State private var inputMode: KeyboardInputMode = .letters
    @State private var isShiftActive: Bool = true // First character is capital
    @State private var isPermanentlyCapsLocked: Bool = false
    @State private var isCursorVisible: Bool = true
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { horizontalSizeClass == .regular }
    
    private let letterRow1: [String] = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    private let letterRow2: [String] = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    private let letterRow3: [String] = ["Z", "X", "C", "V", "B", "N", "M"]
    
    private let numberRow1: [String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    private let numberRow2: [String] = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]
    private let numberRow3: [String] = [".", ",", "?", "!", "'"]
    
    private let commonEmojis: [String] = [
        "😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "😇",
        "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚",
        "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🤩",
        "🥳", "😏", "😒", "😞", "😔", "😟", "😕", "🙁", "😣", "😖",
        "😫", "😩", "🥺", "😢", "😭", "😤", "😠", "😡", "🤯", "😳",
        "🥵", "🥶", "😱", "😨", "😰", "😥", "😓", "🤗", "🤔", "🤭",
        "🤫", "🤥", "😶", "😐", "😑", "😬", "🙄", "😯", "😦", "😧",
        "😮", "😲", "🥱", "😴", "🤤", "😪", "😵", "🤐", "🥴", "🤢",
        "👏", "👍", "👎", "👊", "✊", "🤛", "🤜", "🤞", "✌️", "🤟",
        "🤘", "👌", "🤌", "🤏", "👈", "👉", "👆", "👇", "☝️", "✋",
        "👋", "🤙", "💪", "🙏", "❤️", "🧡", "💛", "💚", "💙", "💜",
        "🖤", "🤍", "🤎", "💔", "❣️", "💕", "💞", "💓", "💗", "💖",
        "🔥", "✨", "🎉", "🎊", "💯", "🍿", "🎬", "📺", "🎵", "⭐"
    ]
    
    private let glassStrokeGradient = LinearGradient(
        colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private var isUppercase: Bool {
        isShiftActive || isPermanentlyCapsLocked
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header (Keyboard Icon + Title + Subtitle + Close 'X' Button)
            headerView
                .padding(.top, 16)
            
            // "Type here..." Frosted Glass Input Field Box (No native keyboard popup)
            inputBoxView
            
            // Main Keyboard Views based on Mode
            switch inputMode {
            case .letters:
                lettersKeyboardView
            case .numbers:
                numbersKeyboardView
            case .emoji:
                emojiKeyboardView
            }
        }
        .padding(.horizontal, isIPad ? 24 : 14)
        .padding(.bottom, isIPad ? 32 : 24)
        .frame(maxWidth: isIPad ? 520 : .infinity)
        .background(
            ZStack {
                // Pure Liquid Glass Background
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
            typedText = ""
            previousText = ""
            isShiftActive = true // Capitalize first letter
            isPermanentlyCapsLocked = false
            inputMode = .letters
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                isCursorVisible.toggle()
            }
        }
        .onDisappear {
            typedText = ""
            previousText = ""
        }
        .onChange(of: typedText) { newText in
            if newText.count > previousText.count {
                let added = String(newText.suffix(newText.count - previousText.count))
                onKeyTyped?(added)
            } else if newText.count < previousText.count {
                let diff = previousText.count - newText.count
                for _ in 0..<diff {
                    onBackspace?()
                }
            }
            previousText = newText
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            // Keyboard Icon
            Image(systemName: "keyboard.fill")
                .font(.system(size: isIPad ? 22 : 18, weight: .bold))
                .foregroundColor(Color(hex: "111827"))
            
            // Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(languageManager.localized("keyboard"))
                    .font(.inter(.bold, size: isIPad ? 19 : 16.5, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "111827"))
                
                Text(languageManager.localized("type_and_search_tv"))
                    .font(.inter(.regular, size: isIPad ? 13 : 11.5, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "788292"))
            }
            
            Spacer()
            
            // Close 'X' Glass Button
            Button(action: {
                triggerHaptic()
                typedText = ""
                previousText = ""
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
            // Text Display with Non-shifting Blinking Cursor
            if typedText.isEmpty {
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(LinearGradient(colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")], startPoint: .top, endPoint: .bottom))
                        .frame(width: 2, height: 18)
                        .opacity(isCursorVisible ? 1.0 : 0.0)
                    
                    Text(languageManager.localized("type_here"))
                        .font(.inter(.regular, size: isIPad ? 16 : 14.5, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
            } else {
                HStack(spacing: 2) {
                    Text(typedText)
                        .font(.inter(.semiBold, size: isIPad ? 16 : 14.5, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "111827"))
                        .lineLimit(1)
                    
                    RoundedRectangle(cornerRadius: 1)
                        .fill(LinearGradient(colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")], startPoint: .top, endPoint: .bottom))
                        .frame(width: 2, height: 18)
                        .opacity(isCursorVisible ? 1.0 : 0.0)
                }
            }
            
            Spacer(minLength: 4)
            
            // Clear text button (if typed)
            if !typedText.isEmpty {
                Button(action: {
                    triggerHaptic()
                    typedText = ""
                    previousText = ""
                    isShiftActive = true // Re-enable capitalization for next input
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: isIPad ? 18 : 15))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.90))
            }
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
    
    // MARK: - 1. Letters Keyboard View
    private var lettersKeyboardView: some View {
        VStack(spacing: 8) {
            qwertyRow(keys: letterRow1)
            qwertyRow(keys: letterRow2)
            
            // Row 3: Shift + Letters + Delete
            HStack(spacing: 5) {
                shiftKeyButton
                
                ForEach(letterRow3, id: \.self) { (k: String) in
                    letterKeyButton(key: k)
                }
                
                deleteKeyButton
            }
            
            // Row 4: [123] | [😊] | [space] | [Send]
            bottomControlRow
        }
    }
    
    // MARK: - 2. Numbers Keyboard View
    private var numbersKeyboardView: some View {
        VStack(spacing: 8) {
            qwertyRow(keys: numberRow1)
            qwertyRow(keys: numberRow2)
            
            HStack(spacing: 5) {
                ForEach(numberRow3, id: \.self) { (k: String) in
                    symbolKeyButton(label: k)
                }
                
                deleteKeyButton
            }
            
            // Row 4: [ABC] | [😊] | [space] | [Send]
            bottomControlRow
        }
    }
    
    // MARK: - 3. Emoji Keyboard View
    private var emojiKeyboardView: some View {
        VStack(spacing: 8) {
            // Scrollable Emoji Grid (4 rows high)
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: isIPad ? 10 : 7), spacing: 8) {
                    ForEach(commonEmojis, id: \.self) { emoji in
                        Button(action: {
                            triggerHaptic()
                            typedText.append(emoji)
                        }) {
                            Text(emoji)
                                .font(.system(size: isIPad ? 28 : 24))
                                .frame(maxWidth: .infinity)
                                .frame(height: isIPad ? 46 : 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.30))
                                )
                        }
                        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.90))
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: isIPad ? 210 : 160)
            
            // Row 4: [ABC] | [😊 Active] | [space] | [Send]
            bottomControlRow
        }
    }
    
    // MARK: - Shift Key Button with Auto-Cap & CapsLock
    private var shiftKeyButton: some View {
        Button(action: {
            triggerHaptic()
            if isPermanentlyCapsLocked {
                isPermanentlyCapsLocked = false
                isShiftActive = false
            } else if isShiftActive {
                // Double tap / second tap -> Turn on Caps Lock
                isPermanentlyCapsLocked = true
            } else {
                isShiftActive = true
            }
        }) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isUppercase ? Color.white.opacity(0.85) : Color.white.opacity(0.40))
                .frame(width: isIPad ? 46 : 38, height: isIPad ? 48 : 42)
                .glassCard(cornerRadius: 10, isInteractive: true)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(glassStrokeGradient, lineWidth: 0.9)
                )
                .overlay(
                    VStack(spacing: 1) {
                        Image(systemName: isPermanentlyCapsLocked ? "capslock.fill" : "arrow.up")
                            .font(.system(size: isIPad ? 17 : 14, weight: isUppercase ? .bold : .regular))
                            .foregroundColor(Color(hex: "111827"))
                    }
                )
                .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
    }
    
    // MARK: - Delete Key Button
    private var deleteKeyButton: some View {
        Button(action: {
            triggerHaptic()
            if !typedText.isEmpty {
                typedText.removeLast()
            }
            if typedText.isEmpty || typedText.hasSuffix(" ") {
                isShiftActive = true // Next letter will be capitalized
            }
        }) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.40))
                .frame(width: isIPad ? 52 : 44, height: isIPad ? 48 : 42)
                .glassCard(cornerRadius: 10, isInteractive: true)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(glassStrokeGradient, lineWidth: 0.9)
                )
                .overlay(
                    Image(systemName: "delete.backward.fill")
                        .font(.system(size: isIPad ? 17 : 14))
                        .foregroundColor(Color(hex: "111827"))
                )
                .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
    }
    
    // MARK: - Bottom Control Row ([123 / ABC], [Emoji], [Space], [Send])
    private var bottomControlRow: some View {
        HStack(spacing: 6) {
            // 123 / ABC Toggle
            Button(action: {
                triggerHaptic()
                if inputMode == .numbers {
                    inputMode = .letters
                } else {
                    inputMode = .numbers
                }
            }) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(inputMode == .numbers ? Color.white.opacity(0.75) : Color.white.opacity(0.40))
                    .frame(width: isIPad ? 54 : 46, height: isIPad ? 48 : 42)
                    .glassCard(cornerRadius: 10, isInteractive: true)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(glassStrokeGradient, lineWidth: 0.9)
                    )
                    .overlay(
                        Text(inputMode == .numbers ? "ABC" : "123")
                            .font(.inter(.semiBold, size: isIPad ? 15 : 13.5, autoScaleForPad: false))
                            .foregroundColor(Color(hex: "111827"))
                    )
                    .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
            
            // Emoji / Smile Toggle Button
            Button(action: {
                triggerHaptic()
                if inputMode == .emoji {
                    inputMode = .letters
                } else {
                    inputMode = .emoji
                }
            }) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(inputMode == .emoji ? Color.white.opacity(0.75) : Color.white.opacity(0.40))
                    .frame(width: isIPad ? 48 : 40, height: isIPad ? 48 : 42)
                    .glassCard(cornerRadius: 10, isInteractive: true)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(glassStrokeGradient, lineWidth: 0.9)
                    )
                    .overlay(
                        Group {
                            if inputMode == .emoji {
                                Text("ABC")
                                    .font(.inter(.semiBold, size: isIPad ? 14 : 12, autoScaleForPad: false))
                                    .foregroundColor(Color(hex: "111827"))
                            } else {
                                Image(systemName: "face.smiling.fill")
                                    .font(.system(size: isIPad ? 18 : 15))
                                    .foregroundColor(Color(hex: "111827"))
                            }
                        }
                    )
                    .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
            
            // Space Button (Automatically resets shift to Capital for next word)
            Button(action: {
                triggerHaptic()
                typedText.append(" ")
                if !isPermanentlyCapsLocked {
                    isShiftActive = true // Next word starts with Capital
                }
            }) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .frame(height: isIPad ? 48 : 42)
                    .glassCard(cornerRadius: 10, isInteractive: true)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(glassStrokeGradient, lineWidth: 0.9)
                    )
                    .overlay(
                        Text(languageManager.localized("space"))
                            .font(.inter(.regular, size: isIPad ? 15 : 13.5, autoScaleForPad: false))
                            .foregroundColor(Color(hex: "4B5563"))
                    )
                    .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94))
            
            // Send Button (Pink/Purple Gradient Glow)
            Button(action: {
                handleSendAction()
            }) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(TR_Theme.activeCircleGradient)
                    .frame(width: isIPad ? 96 : 82, height: isIPad ? 48 : 42)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(glassStrokeGradient, lineWidth: 1.0)
                    )
                    .overlay(
                        Text(languageManager.localized("send"))
                            .font(.inter(.bold, size: isIPad ? 16 : 14, autoScaleForPad: false))
                            .foregroundColor(.white)
                    )
                    .shadow(color: TR_Theme.primaryPink.opacity(0.40), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
        }
    }
    
    // MARK: - Row & Key Helpers
    @ViewBuilder
    private func qwertyRow(keys: [String]) -> some View {
        HStack(spacing: 5) {
            ForEach(keys, id: \.self) { (k: String) in
                if inputMode == .numbers {
                    symbolKeyButton(label: k)
                } else {
                    letterKeyButton(key: k)
                }
            }
        }
    }
    
    @ViewBuilder
    private func letterKeyButton(key: String) -> some View {
        let displayLetter = isUppercase ? key.uppercased() : key.lowercased()
        
        Button(action: {
            triggerHaptic()
            typedText.append(displayLetter)
            
            // Auto-capitalization: turn off Shift after first letter if not permanently locked
            if isShiftActive && !isPermanentlyCapsLocked {
                isShiftActive = false
            }
        }) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.40))
                .frame(maxWidth: .infinity)
                .frame(height: isIPad ? 48 : 42)
                .glassCard(cornerRadius: 10, isInteractive: true)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(glassStrokeGradient, lineWidth: 0.9)
                )
                .overlay(
                    Text(displayLetter)
                        .font(.inter(.medium, size: isIPad ? 19 : 16.5, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "111827"))
                )
                .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
    }
    
    @ViewBuilder
    private func symbolKeyButton(label: String) -> some View {
        Button(action: {
            triggerHaptic()
            typedText.append(label)
        }) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.40))
                .frame(maxWidth: .infinity)
                .frame(height: isIPad ? 48 : 42)
                .glassCard(cornerRadius: 10, isInteractive: true)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(glassStrokeGradient, lineWidth: 0.9)
                )
                .overlay(
                    Text(label)
                        .font(.inter(.medium, size: isIPad ? 19 : 16.5, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "111827"))
                )
                .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
    }
    
    // MARK: - Send Action Handler
    private func handleSendAction() {
        triggerHaptic()
        let textToSend = typedText
        typedText = ""
        previousText = ""
        if !isTVConnected {
            onDismiss()
            onOpenConnectTV?()
        } else {
            onSend?(textToSend)
            onDismiss()
        }
    }
    
    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
