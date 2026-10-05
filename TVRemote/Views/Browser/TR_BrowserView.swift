//
//  TR_BrowserView.swift
//  TV Remote
//

import SwiftUI

struct TR_BrowserView: View {
    @ObservedObject var languageManager = TR_LanguageManager.shared
    @StateObject private var browserVM = BrowserViewModel()
    @EnvironmentObject var adVm: TR_AdCountViewModel
    @AppStorage(TR_SessionKeys.isPro) var isPro = false
    
    var onBack: () -> Void
    var onCastTapped: (() -> Void)? = nil
    var onOpenURL: (String) -> Void
    
    @State private var searchInput: String = ""
    @State private var showPremium: Bool = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { UIDevice.isIPad || horizontalSizeClass == .regular }
    
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let screenHeight = geo.size.height
            let horizontalPadding: CGFloat = isIPad ? (isLandscape ? 36 : 24) : 16
            
            VStack(spacing: 0) {
                // 1. Top Custom Navigation Header (Back on Left, Title "Web" in Center, Cast on Right)
                topNavigationBar(isIPad: isIPad, horizontalPadding: horizontalPadding)
                    .padding(.top, isIPad ? 16 : 8)
                    .padding(.bottom, isIPad ? 12 : 8)
                
                // 2. Search / Enter URL Bar (Top Positioned)
                searchBar(isIPad: isIPad, horizontalPadding: horizontalPadding)
                    .padding(.bottom, isIPad ? 16 : 10)
                
                // 3. 2-Column Quick Access Grid (8 Items - Fixed & Scroll Disabled)
                quickAccessGrid(isIPad: isIPad, isLandscape: isLandscape, screenHeight: screenHeight, horizontalPadding: horizontalPadding)
                
                Spacer(minLength: 0)
                
                // 4. Bottom Browser Navigation Toolbar (4-button Design)
                bottomFloatingToolbar(isIPad: isIPad, horizontalPadding: horizontalPadding)
                    .padding(.bottom, isIPad ? 24 : 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(
            Image("BG")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        )
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationBarHidden(true)
        .enableNativeSwipeBack()
    }
    
    // MARK: - 1. Top Navigation Bar (Back, "Web", Cast with ic_cast)
    @ViewBuilder
    private func topNavigationBar(isIPad: Bool, horizontalPadding: CGFloat) -> some View {
        HStack(alignment: .center) {
            // Back Button
            GlassBackButton(isIPad: isIPad, action: onBack)
            
            Spacer()
            
            // Screen Title: "Web"
            Text(languageManager.localized("web"))
                .font(.inter(.bold, size: isIPad ? 22 : 18, autoScaleForPad: false))
                .foregroundColor(Color(hex: "111827"))
            
            Spacer()
            
            // Cast Button with Liquid Glass Container
            Button(action: {
                HapticFeedback.generate(.light)
                onCastTapped?()
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
    }
    
    // MARK: - 2. 2-Column Quick Access Grid (8 Items matching Design, Non-Scrolling)
    @ViewBuilder
    private func quickAccessGrid(isIPad: Bool, isLandscape: Bool, screenHeight: CGFloat, horizontalPadding: CGFloat) -> some View {
        let columnCount = isIPad ? (isLandscape ? 4 : 3) : 2
        let gridSpacing: CGFloat = isIPad ? 18 : 14
        let cardHeight: CGFloat = isIPad ? 150 : 125
        let iconSize: CGFloat = isIPad ? 64 : 52
        let columns = Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnCount)
        
        LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(browserVM.quickAccessItems) { item in
                Button(action: {
                    HapticFeedback.generate(.medium)
                    handleOptionSelected(item.urlString)
                }) {
                    VStack(spacing: isIPad ? 12 : 10) {
                        // App Icon
                        if let _ = UIImage(named: item.iconImageName) {
                            Image(item.iconImageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: iconSize, height: iconSize)
                                .clipShape(RoundedRectangle(cornerRadius: isIPad ? 14 : 12, style: .continuous))
                        } else {
                            Image(systemName: "globe")
                                .font(.system(size: isIPad ? 32 : 26))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: iconSize, height: iconSize)
                        }
                        
                        // App Name
                        Text(item.name)
                            .font(.inter(.semiBold, size: isIPad ? 16 : 14, autoScaleForPad: false))
                            .foregroundColor(Color(hex: "111827"))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: cardHeight)
                    .contentShape(RoundedRectangle(cornerRadius: isIPad ? 24 : 20, style: .continuous))
                    .glassCard(cornerRadius: isIPad ? 24 : 20, isInteractive: true)
                    .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
                .contentShape(RoundedRectangle(cornerRadius: isIPad ? 24 : 20, style: .continuous))
            }
        }
        .padding(.horizontal, horizontalPadding)
    }
    
    // MARK: - 3. Search / Enter URL Bar
    @ViewBuilder
    private func searchBar(isIPad: Bool, horizontalPadding: CGFloat) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: isIPad ? 18 : 15, weight: .medium))
                .foregroundColor(Color(hex: "9CA3AF"))
            
            TextField(languageManager.localized("search_or_enter_url"), text: $searchInput, onCommit: {
                submitSearch()
            })
            .font(.inter(.regular, size: isIPad ? 15 : 13, autoScaleForPad: false))
            .foregroundColor(Color(hex: "111827"))
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .keyboardType(.webSearch)
            
            Button(action: {
                submitSearch()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: isIPad ? 17 : 14, weight: .medium))
                    .foregroundColor(Color(hex: "9CA3AF"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, isIPad ? 16 : 14)
        .frame(height: isIPad ? 50 : 42)
        .glassCard(cornerRadius: isIPad ? 18 : 14)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        .padding(.horizontal, horizontalPadding)
    }
    
    // MARK: - 4. Bottom Floating Navigation Toolbar (4-button Design)
    @ViewBuilder
    private func bottomFloatingToolbar(isIPad: Bool, horizontalPadding: CGFloat) -> some View {
        HStack {
            // 1. Back
            Button(action: {
                HapticFeedback.generate(.light)
                onBack()
            }) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: isIPad ? 20 : 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
            
            // 2. Forward
            Button(action: {}) {
                Image(systemName: "chevron.forward")
                    .font(.system(size: isIPad ? 20 : 16, weight: .semibold))
                    .foregroundColor(Color(hex: "9CA3AF"))
                    .frame(maxWidth: .infinity)
            }
            .disabled(true)
            .buttonStyle(.plain)
            
            // 3. Share
            Button(action: {
                HapticFeedback.generate(.light)
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: isIPad ? 20 : 16, weight: .semibold))
                    .foregroundColor(Color(hex: "7E8B9B"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
            
            // 4. Tabs / Windows
            Button(action: {
                HapticFeedback.generate(.light)
                onBack()
            }) {
                Image(systemName: "square.on.square")
                    .font(.system(size: isIPad ? 20 : 16, weight: .semibold))
                    .foregroundColor(Color(hex: "7E8B9B"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
        }
        .padding(.horizontal, isIPad ? 20 : 14)
        .frame(height: isIPad ? 52 : 44)
        .glassCard(cornerRadius: isIPad ? 22 : 18)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.horizontal, horizontalPadding)
    }
    
    private var isWebOSTVConnected: Bool {
        TR_DeviceConnectivityViewModel.shared.getConnectedTvType() == .LG
            || TR_RemoteViewModel.shared.connectedTVType == .LG
            || TR_DeviceConnectivityViewModel.shared.connectSDKDiscoveryModel.isConnectedToLG
            || (TR_RemoteViewModel.shared.currentTVManager is TR_LGControlManager)
    }
    
    private func handleOptionSelected(_ urlString: String) {
        let isConnected = TR_DeviceConnectivityViewModel.shared.isDeviceConnected
            || TR_RemoteViewModel.shared.isConnectedSuccessfully
            || TR_AirPlayManager.shared.isAirPlayConnected
            
        guard isConnected else {
            onCastTapped?()
            return
        }
        
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let validURLString: String
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            validURLString = trimmed
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            validURLString = "https://\(trimmed)"
        } else {
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            validURLString = "https://www.google.com/search?q=\(encoded)"
        }
        
        if isWebOSTVConnected, let url = URL(string: validURLString) {
            TR_DeviceConnectivityViewModel.shared.connectSDKDiscoveryModel.sendMediaToLGTVWeb(mediaUrl: url)
        }
        
        onOpenURL(validURLString)
    }
    
    private func submitSearch() {
        let trimmed = searchInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        handleOptionSelected(trimmed)
    }
}
