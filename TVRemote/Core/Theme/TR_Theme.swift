//
//  TR_Theme.swift
//  TVRemote
//
//  Created by iOS Developer on 01/10/2026.
//

import SwiftUI

struct TR_Theme {
    // MARK: - Figma Color Palette (#8E03A1 -> #E25F89)
    static let primaryPurple = Color(hex: "8E03A1")
    static let primaryPink = Color(hex: "E25F89")
    static let accentRed = Color(hex: "FF3B30")
    static let connectedGreen = Color(hex: "34C759")
    
    static let glassBackground = Color.white.opacity(0.55)
    static let glassBorder = Color.white.opacity(0.75)
    static let glassHighlight = Color.white.opacity(0.90)
    static let textPrimary = Color(hex: "111827")
    static let textSecondary = Color(hex: "8E8E93")
    
    // MARK: - Brand Gradients
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [primaryPurple, primaryPink],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    static var brandGradientDiagonal: LinearGradient {
        LinearGradient(
            colors: [primaryPurple, primaryPink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var activeCircleGradient: LinearGradient {
        LinearGradient(
            colors: [primaryPurple, primaryPink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var glassCardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.55),
                Color.white.opacity(0.25)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var glassButtonGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.65),
                Color.white.opacity(0.35)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var softBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "F4F6FC"),
                Color(hex: "EAEFFB")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Glassmorphism View Modifiers
struct TR_FigmaGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    var strokeColor: Color = TR_Theme.glassBorder
    var lineWidth: CGFloat = 1.0
    var opacity: CGFloat = 0.4
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(opacity))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.8), Color.white.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: lineWidth
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

struct TR_FigmaGlassButtonModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var isPressed: Bool = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(isPressed ? 0.6 : 0.45))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1.0)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
}

extension View {
    func trGlassCard(cornerRadius: CGFloat = 24, strokeColor: Color = TR_Theme.glassBorder, opacity: CGFloat = 0.4) -> some View {
        self.modifier(TR_FigmaGlassCardModifier(cornerRadius: cornerRadius, strokeColor: strokeColor, opacity: opacity))
    }
    
    func trGlassButton(cornerRadius: CGFloat = 20, isPressed: Bool = false) -> some View {
        self.modifier(TR_FigmaGlassButtonModifier(cornerRadius: cornerRadius, isPressed: isPressed))
    }
    
    func trBackground() -> some View {
        self.background(
            ZStack {
                Image("TR_BG")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            }
        )
    }
}
