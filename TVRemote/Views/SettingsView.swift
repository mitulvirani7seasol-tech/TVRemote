//
//  SettingsView.swift
//  TV Remote
//
//  Created by iOS Developer on 01/10/2026.
//

import SwiftUI
import SafariServices
import StoreKit

enum SettingsItem: String, CaseIterable, Identifiable {
    case language = "Language"
    case rateApp = "Rate App"
    case shareApp = "Share App"
    case privacyPolicy = "Privacy Policy"
    case terms = "Terms & Condition"
    case eula = "EULA"
    
    var id: String { rawValue }
    
    var assetName: String {
        switch self {
        case .language: return "ic_Language"
        case .rateApp: return "ic_Rate_App"
        case .shareApp: return "ic_Share_App"
        case .privacyPolicy: return "ic_Privacy_Policy"
        case .terms: return "ic_Terms_Condition"
        case .eula: return "ic_EULA"
        }
    }
    
    @MainActor
    func localizedTitle(languageManager: TR_LanguageManager) -> String {
        switch self {
        case .language:
            return languageManager.localized("change_language")
        case .rateApp:
            return languageManager.localized("rate_app")
        case .shareApp:
            return languageManager.localized("share_app")
        case .privacyPolicy:
            return languageManager.localized("privacy_policy")
        case .terms:
            return languageManager.localized("terms_condition")
        case .eula:
            return languageManager.localized("eula")
        }
    }
}

struct SettingsView: View {
    @ObservedObject var languageManager = TR_LanguageManager.shared
    @ObservedObject var deviceManager = DeviceConnectionManager.shared
    
    var onBack: (() -> Void)? = nil
    var onOpenLanguage: () -> Void
    var onCastTapped: () -> Void
    
    @State private var safariURL: URL?
    @State private var showSafari: Bool = false
    @State private var showShareSheet: Bool = false
    
    private var isConnected: Bool {
        deviceManager.isActuallyConnected
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let isIPad = UIDevice.isIPad
            let horizontalPadding: CGFloat = isIPad ? (isLandscape ? 48 : 32) : 20
            let columnsCount = isIPad ? (isLandscape ? 4 : 3) : 2
            let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: columnsCount)
            
            VStack(spacing: 0) {
                // Top Header Bar
                HStack(spacing: 12) {
                    if let onBack = onBack {
                        GlassBackButton(isIPad: isIPad) {
                            onBack()
                        }
                    }
                    
                    Text(languageManager.localized("settings"))
                        .font(.inter(.bold, size: isIPad ? 28 : 24, autoScaleForPad: false))
                        .foregroundColor(TR_Theme.textPrimary)
                    
                    Spacer()
                    
                    // Cast Button with Liquid Glass Container
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onCastTapped()
                    }) {
                        ZStack {
                            Image("ic_cast")
                                .resizable()
                                .scaledToFit()
                                .frame(width: isIPad ? 24 : 20, height: isIPad ? 24 : 20)
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
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
                    }
                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, isIPad ? 20 : 12)
                .padding(.bottom, isIPad ? 20 : 16)
                
                // 2-Column Grid of Liquid Glass Settings Cards (6 Items)
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(SettingsItem.allCases) { item in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                handleItemTap(item)
                            }) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .top) {
                                        // Custom Icon with Frosted Glass Circular Background (50x50 container, 28x28 icon)
                                        ZStack {
                                            Circle()
                                                .fill(Color.white.opacity(0.40))
                                                .frame(width: isIPad ? 56 : 50, height: isIPad ? 56 : 50)
                                                .glassModifier(cornerRadius: (isIPad ? 56 : 50) / 2)
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
//                                                .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                                            
                                            Image(item.assetName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: isIPad ? 32 : 28, height: isIPad ? 32 : 28)
                                        }
                                        
                                        Spacer()
                                        
                                        // Chevron with Frosted Glass Circular Background (24x24)
                                        ZStack {
                                            Circle()
                                                .fill(Color.white.opacity(0.35))
                                                .frame(width: isIPad ? 28 : 24, height: isIPad ? 28 : 24)
                                                .glassModifier(cornerRadius: (isIPad ? 28 : 24) / 2)
                                                .overlay(
                                                    Circle()
                                                        .stroke(
                                                            LinearGradient(
                                                                colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            ),
                                                            lineWidth: 0.8
                                                        )
                                                )
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: isIPad ? 11 : 9.5, weight: .bold))
                                                .foregroundColor(Color(hex: "9CA3AF"))
                                        }
                                    }
//                                    .padding(.top, 12)
//                                    Spacer(minLength: 0)
                                    
                                    Text(item.localizedTitle(languageManager: languageManager))
                                        .font(.inter(.bold, size: isIPad ? 20 : 16, autoScaleForPad: false))
                                        .foregroundColor(TR_Theme.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                        .minimumScaleFactor(0.85)
                                }
                                .padding(.horizontal, isIPad ? 18 : 14)
                                .padding(.vertical, isIPad ? 18 : 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: isIPad ? 140 : 120)
                                .glassCard(cornerRadius: isIPad ? 22 : 18, isInteractive: true)
                                .overlay(
                                    RoundedRectangle(cornerRadius: isIPad ? 22 : 18, style: .continuous)
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
                                .contentShape(RoundedRectangle(cornerRadius: isIPad ? 22 : 18, style: .continuous))
                            }
                            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.96))
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 4)
                    .padding(.bottom, 120)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .enableNativeSwipeBack()
        .sheet(isPresented: $showSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareURL = URL(string: APPURL) {
                ShareActivityView(activityItems: ["Check out TV Remote for Smart TVs!", shareURL])
            }
        }
    }
    
    private func rateApp() {
        if let url = URL(string: REVIEW_LINK), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
    
    private func handleItemTap(_ item: SettingsItem) {
        switch item {
        case .language:
            onOpenLanguage()
        case .rateApp:
            rateApp()
        case .shareApp:
            showShareSheet = true
        case .privacyPolicy:
            if let url = URL(string: PRIVACYPOLICY) {
                safariURL = url
                showSafari = true
            }
        case .terms:
            if let url = URL(string: TEARMS) {
                safariURL = url
                showSafari = true
            }
        case .eula:
            if let url = URL(string: EULA) {
                safariURL = url
                showSafari = true
            }
        }
    }
}

// MARK: - Safari & Share Representables
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct ShareActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Previews
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Image("BG")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            SettingsView(
                onOpenLanguage: {},
                onCastTapped: {}
            )
        }
    }
}
