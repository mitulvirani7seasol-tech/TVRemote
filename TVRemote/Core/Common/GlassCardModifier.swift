//
//  TR_GlassCardModifier.swift
//  TV Remote
//
//  Created by Kushang kaklotar on 22/09/26.
//

import Foundation
import SwiftUI

// MARK: - Custom Rounded Corners Shape
public struct CustomRoundedCorners: Shape {
    public var radius: CGFloat = 30
    public var corners: UIRectCorner = [.topLeft, .topRight]

    public init(radius: CGFloat = 30, corners: UIRectCorner = [.topLeft, .topRight]) {
        self.radius = radius
        self.corners = corners
    }

    public func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - View Extensions
extension View {
    func glassModifier(
        cornerRadius: CGFloat = 30,
        color: Color = Color(.clear)
    ) -> some View {
        modifier(
            GlassModifier(
                cornerRadius: cornerRadius,
                color: color
            )
        )
    }
    
    func glassCard(
        cornerRadius: CGFloat = 30,
        color: Color = Color(.clear),
        isInteractive: Bool = true
    ) -> some View {
        modifier(
            GlassModifier(
                cornerRadius: cornerRadius,
                color: color
            )
        )
    }
    
    func glassTabBarModifier(
        cornerRadius: CGFloat = 30,
        color: Color = Color.clear
    ) -> some View {
        modifier(
            GlassTabBarModifier(
                cornerRadius: cornerRadius,
                color: color
            )
        )
    }
    
    func glassShape<S: Shape>(
        _ shape: S,
        color: Color = Color.clear,
        isInteractive: Bool = true
    ) -> some View {
        modifier(
            GlassShapeModifier(
                shape: shape,
                color: color,
                isInteractive: isInteractive
            )
        )
    }
}

// MARK: - iOS Default Liquid Glass TR_Tab Bar Modifier (Apple Native Ultra Thin Material)
public struct GlassTabBarModifier: ViewModifier {
    var cornerRadius: CGFloat = 30
    var color: Color = Color.clear
    
    public init(cornerRadius: CGFloat = 30, color: Color = Color.clear) {
        self.cornerRadius = cornerRadius
        self.color = color
    }
    
    public func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(color)
                .glassEffect(
                    .clear.interactive(),
                    in: RoundedRectangle(cornerRadius: cornerRadius)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.65), location: 0.0),
                                    .init(color: Color.white.opacity(0.15), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                )
        } else {
            content
                .background(color)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.70),
                                    Color.white.opacity(0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
    }
}

// MARK: - Glass Back Button Component
public struct GlassBackButton: View {
    public var size: CGFloat
    public var iconSize: CGFloat
    public var action: () -> Void
    
    public init(
        size: CGFloat = 40,
        iconSize: CGFloat = 16,
        action: @escaping () -> Void
    ) {
        self.size = size
        self.iconSize = iconSize
        self.action = action
    }
    
    public init(
        isIPad: Bool,
        action: @escaping () -> Void
    ) {
        self.size = isIPad ? 46 : 40
        self.iconSize = isIPad ? 19 : 16
        self.action = action
    }
    
    public init(
        size: CGFloat,
        isIPad: Bool,
        action: @escaping () -> Void
    ) {
        self.size = size
        self.iconSize = isIPad ? 20 : 16
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            HapticFeedback.generate(.light)
            action()
        }) {
            ZStack {
                Image(systemName: "arrow.left")
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: size, height: size)
            .glassModifier(cornerRadius: size / 2)
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
        .contentShape(Circle())
    }
}

// MARK: - Interactive Scale Button Style (Scale + Liquid Glass Brightness + Haptic on Press)
struct ScaleButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.94
    var opacityAmount: CGFloat = 0.88
    var brightnessAmount: Double = 0.08

    func makeBody(configuration: Configuration) -> some View {
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

// MARK: - Glass Modifier
struct GlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 30
    var color: Color = Color(.clear)

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(color)
                .cornerRadius(cornerRadius)
                .glassEffect(
                    .clear.interactive(),
                    in: RoundedRectangle(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(color)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.70),
                                    Color.white.opacity(0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
    }
}

// MARK: - Glass Shape Modifier
public struct GlassShapeModifier<S: Shape>: ViewModifier {
    var shape: S
    var color: Color = Color.clear
    var isInteractive: Bool = true

    public init(shape: S, color: Color = Color.clear, isInteractive: Bool = true) {
        self.shape = shape
        self.color = color
        self.isInteractive = isInteractive
    }

    public func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(color)
                .glassEffect(
                    isInteractive ? .clear.interactive() : .clear,
                    in: shape
                )
                .clipShape(shape)
                .overlay(
                    shape.stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.85),
                                Color.white.opacity(0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
                )
        } else {
            content
                .background(color)
                .background(
                    shape.fill(Color.white.opacity(0.18))
                )
                .clipShape(shape)
                .overlay(
                    shape.stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.70),
                                Color.white.opacity(0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
                )
        }
    }
}

// MARK: - Backward Compatibility Alias
typealias TR_GlassCardModifier = GlassModifier

// MARK: - TR_Blur Component
struct TR_Blur: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterialLight
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        view.isUserInteractionEnabled = false
        return view
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - Reusable Share Sheet Component
public struct TR_ShareSheet: UIViewControllerRepresentable {
    public var activityItems: [Any]
    public var applicationActivities: [UIActivity]? = nil
    public var excludedActivityTypes: [UIActivity.ActivityType]? = nil
    public var callback: UIActivityViewController.CompletionWithItemsHandler? = nil

    public init(
        activityItems: [Any],
        applicationActivities: [UIActivity]? = nil,
        excludedActivityTypes: [UIActivity.ActivityType]? = nil,
        callback: UIActivityViewController.CompletionWithItemsHandler? = nil
    ) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
        self.excludedActivityTypes = excludedActivityTypes
        self.callback = callback
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = callback
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
