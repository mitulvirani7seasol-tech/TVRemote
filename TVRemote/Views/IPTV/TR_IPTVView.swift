//
//  TR_IPTVView.swift
//  TV Remote
//

import SwiftUI

struct TR_IPTVView: View {
    @ObservedObject var languageManager = TR_LanguageManager.shared
    @StateObject private var iptvVM = TR_IPTVViewModel()
    @EnvironmentObject var adVm: TR_AdCountViewModel
    @AppStorage(TR_SessionKeys.isPro) var isPro = false
    
    var onBack: () -> Void
    var onCastTapped: (() -> Void)? = nil
    var onSelectChannels: (_ title: String, _ channels: [TR_Channel]) -> Void
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { UIDevice.isIPad || horizontalSizeClass == .regular }
    
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let horizontalPadding: CGFloat = isIPad ? (isLandscape ? 36 : 24) : 16
            
            VStack(spacing: 0) {
                // 1. Top Custom Navigation Header
                topNavigationBar(isIPad: isIPad, horizontalPadding: horizontalPadding)
                    .padding(.top, isIPad ? 16 : 8)
                    .padding(.bottom, isIPad ? 12 : 8)
                
                // 2. Top Segmented Switcher (Country / Category)
                segmentedHeaderPicker(isIPad: isIPad)
                    .padding(.bottom, isIPad ? 18 : 14)
                
                // 3. Main Content
                if iptvVM.isLoading && !iptvVM.isDataLoaded {
                    Spacer()
                    ProgressView()
                        .scaleEffect(isIPad ? 1.6 : 1.3)
                        .tint(Color(hex: "8E03A1"))
                    Spacer()
                } else {
                    mainContentView(isIPad: isIPad, isLandscape: isLandscape, horizontalPadding: horizontalPadding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            Image("BG")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        )
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(true)
        .enableNativeSwipeBack()
        .onAppear {
            iptvVM.loadAllData()
        }
    }
    
    // MARK: - 1. Top Navigation Bar
    @ViewBuilder
    private func topNavigationBar(isIPad: Bool, horizontalPadding: CGFloat) -> some View {
        HStack(alignment: .center) {
            // Back Button
            GlassBackButton(isIPad: isIPad, action: onBack)
            
            Spacer()
            
            // Title: "IPTV"
            Text(languageManager.localized("iptv"))
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
    
    // MARK: - 2. Top Segmented Header Picker (Country vs Category with Ultra-Thin Glass)
    @ViewBuilder
    private func segmentedHeaderPicker(isIPad: Bool) -> some View {
        let totalWidth: CGFloat = isIPad ? 320 : 256
        let barHeight: CGFloat = isIPad ? 60 : 54
        let pillHeight: CGFloat = isIPad ? 50 : 44
        let segmentWidth: CGFloat = (totalWidth - 8) / 2
        
        ZStack {
            // Sliding Magenta/Pink Gradient Active Pill
            HStack {
                if iptvVM.selectedSection == .categories {
                    Spacer(minLength: 0)
                }
                
                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(hex: "8E03A1"), location: 0.0),
                                .init(color: Color(hex: "E25F89"), location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: segmentWidth, height: pillHeight)
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.60), Color.white.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color(hex: "E25F89").opacity(0.40), radius: 8, x: 0, y: 2)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: iptvVM.selectedSection)
                
                if iptvVM.selectedSection == .countries {
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 4)
            
            // Interactive Tab Buttons
            HStack(spacing: 0) {
                // Country Button
                Button(action: {
                    HapticFeedback.generate(.light)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        iptvVM.selectedSection = .countries
                    }
                }) {
                    HStack(spacing: 6) {
                        let isSelected = iptvVM.selectedSection == .countries
                        Image(isSelected ? "ic_country_selected" : "ic_country")
                            .resizable()
                            .scaledToFit()
                            .frame(width: isIPad ? 20 : 16, height: isIPad ? 20 : 16)
                        
                        Text(languageManager.localized("country"))
                            .font(.inter(isSelected ? .bold : .semiBold, size: isIPad ? 15 : 13, autoScaleForPad: false))
                            .foregroundColor(isSelected ? .white : Color(hex: "7E8B9B"))
                    }
                    .frame(width: segmentWidth, height: barHeight)
                    .contentShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
                
                // Category Button
                Button(action: {
                    HapticFeedback.generate(.light)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        iptvVM.selectedSection = .categories
                    }
                }) {
                    HStack(spacing: 6) {
                        let isSelected = iptvVM.selectedSection == .categories
                        Image(isSelected ? "ic_category_selected" : "ic_category")
                            .resizable()
                            .scaledToFit()
                            .frame(width: isIPad ? 20 : 16, height: isIPad ? 20 : 16)
                        
                        Text(languageManager.localized("category"))
                            .font(.inter(isSelected ? .bold : .semiBold, size: isIPad ? 15 : 13, autoScaleForPad: false))
                            .foregroundColor(isSelected ? .white : Color(hex: "7E8B9B"))
                    }
                    .frame(width: segmentWidth, height: barHeight)
                    .contentShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
            }
        }
        .frame(width: totalWidth, height: barHeight)
        .glassCard(cornerRadius: 32, isInteractive: false)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - 3. Main Content View
    @ViewBuilder
    private func mainContentView(isIPad: Bool, isLandscape: Bool, horizontalPadding: CGFloat) -> some View {
        TabView(selection: $iptvVM.selectedSection) {
            // Countries Page (3-Column Grid)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    let columnCount = isIPad ? (isLandscape ? 5 : 4) : 3
                    let gridSpacing: CGFloat = isIPad ? 14 : 10
                    let columns = Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnCount)
                    
                    LazyVGrid(columns: columns, spacing: gridSpacing) {
                        ForEach(iptvVM.countries) { country in
                            countryGridCard(country: country, isIPad: isIPad)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                }
                .padding(.top, 4)
                .padding(.bottom, 34)
            }
            .tag(IPTVSectionType.countries)
            
            // Categories Page (Full-Width Rows)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    let columnCount = isIPad ? (isLandscape ? 3 : 2) : 1
                    let gridSpacing: CGFloat = isIPad ? 14 : 10
                    let columns = Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnCount)
                    
                    LazyVGrid(columns: columns, spacing: gridSpacing) {
                        ForEach(iptvVM.categories) { category in
                            categoryRowCard(category: category, isIPad: isIPad)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                }
                .padding(.top, 4)
                .padding(.bottom, 34)
            }
            .tag(IPTVSectionType.categories)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
    
    // MARK: - Country Grid Card (Whole Card Selectable with Spring Compression & Crisp Haptic)
    @ViewBuilder
    private func countryGridCard(country: TR_IPTVCountryModelElement, isIPad: Bool) -> some View {
        Button(action: {
            HapticFeedback.generate(.light)
            onSelectChannels(country.country ?? "Channels", country.channels ?? [])
        }) {
            VStack(spacing: isIPad ? 8 : 6) {
                // Circular Flag Container
                ZStack {
                    if let flagURL = country.resolvedFlagURL {
                        AsyncImage(url: flagURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: isIPad ? 52 : 42, height: isIPad ? 52 : 42)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
                            default:
                                flagFallbackView(country: country, isIPad: isIPad)
                            }
                        }
                    } else {
                        flagFallbackView(country: country, isIPad: isIPad)
                    }
                }
                .frame(width: isIPad ? 52 : 42, height: isIPad ? 52 : 42)
                .padding(.top, isIPad ? 14 : 12)
                
                // Country Name
                Text(country.country ?? "Country")
                    .font(.inter(.semiBold, size: isIPad ? 14 : 12, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "111827"))
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                
                // Channel Count: "+250"
                let count = country.channels?.count ?? 0
                Text("+\(count)")
                    .font(.inter(.regular, size: isIPad ? 12 : 11, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "6B7280"))
                    .lineLimit(1)
                    .padding(.bottom, isIPad ? 14 : 12)
            }
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: isIPad ? 20 : 18, style: .continuous))
            .glassCard(cornerRadius: isIPad ? 20 : 18, isInteractive: true)
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
        .contentShape(RoundedRectangle(cornerRadius: isIPad ? 20 : 18, style: .continuous))
    }
    
    // MARK: - Flag Fallback
    private func countryEmoji(for code: String?) -> String? {
        guard let code = code?.lowercased(), code.count == 2 else { return nil }
        let base: UInt32 = 127397
        var s = ""
        for v in code.uppercased().unicodeScalars {
            if let scalar = UnicodeScalar(base + v.value) {
                s.unicodeScalars.append(scalar)
            }
        }
        return s
    }
    
    @ViewBuilder
    private func flagFallbackView(country: TR_IPTVCountryModelElement, isIPad: Bool) -> some View {
        if let emoji = countryEmoji(for: country.resolvedCountryCode) {
            Text(emoji)
                .font(.system(size: isIPad ? 36 : 28))
        } else {
            Image(systemName: "globe")
                .font(.system(size: isIPad ? 28 : 22))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    // MARK: - Category Row Card (Whole Card Selectable with Spring Compression & Crisp Haptic)
    @ViewBuilder
    private func categoryRowCard(category: TR_IPTVCategoryModelElement, isIPad: Bool) -> some View {
        Button(action: {
            HapticFeedback.generate(.light)
            onSelectChannels(category.category ?? "Channels", category.channels ?? [])
        }) {
            HStack(alignment: .center) {
                // Category Name
                Text(category.category?.capitalized ?? "Category")
                    .font(.inter(.semiBold, size: isIPad ? 16 : 14, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "111827"))
                    .lineLimit(1)
                
                Spacer()
                
                // Channel Count: "+250"
                let count = category.channels?.count ?? 0
                Text("+\(count)")
                    .font(.inter(.medium, size: isIPad ? 14 : 12, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "6B7280"))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, isIPad ? 20 : 16)
            .padding(.vertical, isIPad ? 16 : 14)
            .contentShape(RoundedRectangle(cornerRadius: isIPad ? 18 : 16, style: .continuous))
            .glassCard(cornerRadius: isIPad ? 18 : 16, isInteractive: true)
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
        .contentShape(RoundedRectangle(cornerRadius: isIPad ? 18 : 16, style: .continuous))
    }
}
