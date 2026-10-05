//
//  SwipeBackModifier.swift
//  TV Remote
//

import SwiftUI
import UIKit

// MARK: - Global Retained Interactive Pop Gesture Delegate
final class GlobalPopGestureCoordinator: NSObject, UIGestureRecognizerDelegate {
    static let shared = GlobalPopGestureCoordinator()
    
    var canPopHandler: (() -> Bool)? = nil
    var onBlockedHandler: (() -> Void)? = nil
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let canPop = canPopHandler {
            if !canPop() {
                DispatchQueue.main.async {
                    self.onBlockedHandler?()
                }
                return false
            }
        }
        
        // Always allow gesture if more than 1 view controller exists in the stack
        if let nav = findActiveNavigationController() {
            return nav.viewControllers.count > 1
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    private func findActiveNavigationController() -> UINavigationController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        
        if let nav = rootVC as? UINavigationController {
            return nav
        }
        
        var current = rootVC
        while let presented = current.presentedViewController {
            if let nav = presented as? UINavigationController {
                return nav
            }
            current = presented
        }
        return nil
    }
}

// MARK: - Life-Cycle Aware UIViewController for Pop Gesture
final class EnableNativeSwipeBackViewController: UIViewController {
    var canPop: (() -> Bool)?
    var onBlocked: (() -> Void)?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configurePopGesture()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configurePopGesture()
    }
    
    private func configurePopGesture() {
        if let nav = navigationController {
            nav.interactivePopGestureRecognizer?.isEnabled = true
            GlobalPopGestureCoordinator.shared.canPopHandler = canPop
            GlobalPopGestureCoordinator.shared.onBlockedHandler = onBlocked
            nav.interactivePopGestureRecognizer?.delegate = GlobalPopGestureCoordinator.shared
        }
    }
}

// MARK: - Native iOS Interactive Pop Gesture Helper for NavigationStack
struct EnableNativeSwipeBackHelper: UIViewControllerRepresentable {
    var canPop: (() -> Bool)? = nil
    var onBlocked: (() -> Void)? = nil
    
    func makeUIViewController(context: Context) -> EnableNativeSwipeBackViewController {
        let vc = EnableNativeSwipeBackViewController()
        vc.canPop = canPop
        vc.onBlocked = onBlocked
        vc.view.backgroundColor = .clear
        return vc
    }
    
    func updateUIViewController(_ uiViewController: EnableNativeSwipeBackViewController, context: Context) {
        uiViewController.canPop = canPop
        uiViewController.onBlocked = onBlocked
        GlobalPopGestureCoordinator.shared.canPopHandler = canPop
        GlobalPopGestureCoordinator.shared.onBlockedHandler = onBlocked
        if let nav = uiViewController.navigationController {
            nav.interactivePopGestureRecognizer?.isEnabled = true
            nav.interactivePopGestureRecognizer?.delegate = GlobalPopGestureCoordinator.shared
        }
    }
}

// MARK: - Disable Native Pop Gesture Helper for NavigationStack
final class DisableNativeSwipeBackViewController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        disableGesture()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        disableGesture()
    }
    
    private func disableGesture() {
        if let nav = navigationController {
            nav.interactivePopGestureRecognizer?.isEnabled = false
            GlobalPopGestureCoordinator.shared.canPopHandler = { false }
        }
    }
}

struct DisableNativeSwipeBackHelper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> DisableNativeSwipeBackViewController {
        let vc = DisableNativeSwipeBackViewController()
        vc.view.backgroundColor = .clear
        return vc
    }
    
    func updateUIViewController(_ uiViewController: DisableNativeSwipeBackViewController, context: Context) {
        if let nav = uiViewController.navigationController {
            nav.interactivePopGestureRecognizer?.isEnabled = false
            GlobalPopGestureCoordinator.shared.canPopHandler = { false }
        }
    }
}

struct ClearFullScreenBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            var parent: UIView? = view
            while let current = parent {
                current.backgroundColor = .clear
                parent = current.superview
            }
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            var parent: UIView? = uiView
            while let current = parent {
                current.backgroundColor = .clear
                parent = current.superview
            }
        }
    }
}

// Custom Drag Dismiss Modifier for FullScreenCover Modals (Photo/Video/Audio Players)
struct InteractiveSwipeBackModifier: ViewModifier {
    let edgeThreshold: CGFloat
    let onDismiss: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    
    init(edgeThreshold: CGFloat = 80, onDismiss: @escaping () -> Void) {
        self.edgeThreshold = edgeThreshold
        self.onDismiss = onDismiss
    }
    
    func body(content: Content) -> some View {
        content
            .offset(x: dragOffset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .global)
                    .onChanged { value in
                        if (value.startLocation.x <= edgeThreshold || isDragging) && value.translation.width > 0 {
                            if abs(value.translation.height) < (value.translation.width * 0.85) || isDragging {
                                isDragging = true
                                dragOffset = max(0, value.translation.width)
                            }
                        }
                    }
                    .onEnded { value in
                        if isDragging || value.startLocation.x <= edgeThreshold {
                            if value.translation.width > 70 || value.predictedEndTranslation.width > 150 {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    dragOffset = UIScreen.main.bounds.width
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                                    onDismiss()
                                }
                            } else {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    dragOffset = 0
                                }
                            }
                        }
                        isDragging = false
                    }
            )
    }
}

extension View {
    // For NavigationStack pushed views (TR_StartDrawingView, TR_DrawingView, PhotosGalleryView, SettingsView)
    func enableNativeSwipeBack(canPop: (() -> Bool)? = nil, onBlocked: (() -> Void)? = nil) -> some View {
        self.background(EnableNativeSwipeBackHelper(canPop: canPop, onBlocked: onBlocked))
    }
    
    func disableNativeSwipeBack() -> some View {
        self.background(DisableNativeSwipeBackHelper())
    }
    
    // For FullScreenCover modals (Players)
    func interactiveSwipeBack(edgeThreshold: CGFloat = 80, onDismiss: @escaping () -> Void) -> some View {
        modifier(InteractiveSwipeBackModifier(edgeThreshold: edgeThreshold, onDismiss: onDismiss))
    }
    
    @ViewBuilder
    func transparentModalBackground() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(.clear)
                .background(ClearFullScreenBackground())
        } else {
            self.background(ClearFullScreenBackground())
        }
    }
}
