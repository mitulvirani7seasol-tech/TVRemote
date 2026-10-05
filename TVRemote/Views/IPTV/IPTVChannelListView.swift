//
//  IPTVChannelListView.swift
//  TV Remote
//

import SwiftUI

struct IPTVChannelListView: View {
    @ObservedObject var languageManager = TR_LanguageManager.shared
    @ObservedObject var deviceManager = DeviceConnectionManager.shared
    @EnvironmentObject var adVm: TR_AdCountViewModel
    @AppStorage(TR_SessionKeys.isPro) var isPro = false
    
    let title: String
    let channels: [TR_Channel]
    var onBack: () -> Void
    var onCastTapped: (() -> Void)? = nil
    var onSelectChannel: (_ channels: [TR_Channel], _ index: Int) -> Void
    @State private var showPremium = false
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { UIDevice.isIPad || horizontalSizeClass == .regular }
    
    private var isTVConnected: Bool {
        deviceManager.isActuallyConnected
    }
    
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let horizontalPadding: CGFloat = isIPad ? (isLandscape ? 36 : 24) : 16
            
            VStack(spacing: 0) {
                // 1. Top Navigation Header
                topNavigationBar(isIPad: isIPad, horizontalPadding: horizontalPadding)
                    .padding(.top, isIPad ? 16 : 8)
                    .padding(.bottom, isIPad ? 14 : 10)
                
                // 2. Channels 3-Column Grid
                if channels.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tv.slash")
                            .font(.system(size: isIPad ? 54 : 42))
                            .foregroundColor(Color(hex: "9CA3AF"))
                        Text(languageManager.localized("no_channels_found"))
                            .font(.inter(.semiBold, size: isIPad ? 18 : 16, autoScaleForPad: false))
                            .foregroundColor(Color(hex: "6B7280"))
                    }
                    Spacer()
                } else {
                    channelsGridView(isIPad: isIPad, isLandscape: isLandscape, horizontalPadding: horizontalPadding)
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
    }
    
    // MARK: - 1. Top Navigation Bar
    @ViewBuilder
    private func topNavigationBar(isIPad: Bool, horizontalPadding: CGFloat) -> some View {
        HStack(alignment: .center) {
            // Back Button
            GlassBackButton(isIPad: isIPad, action: onBack)
            
            Spacer()
            
            // Screen Title: "IPTV" (Matching Image 3)
            Text(title.isEmpty ? languageManager.localized("iptv") : title)
                .font(.inter(.bold, size: isIPad ? 22 : 18, autoScaleForPad: false))
                .foregroundColor(Color(hex: "111827"))
                .lineLimit(1)
            
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
    
    // MARK: - 2. 3-Column Channels Grid (Matching Image 3)
    @ViewBuilder
    private func channelsGridView(isIPad: Bool, isLandscape: Bool, horizontalPadding: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                let columnCount = isIPad ? (isLandscape ? 5 : 4) : 3
                let gridSpacing: CGFloat = isIPad ? 14 : 10
                let columns = Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnCount)
                
                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    ForEach(Array(channels.enumerated()), id: \.element.id) { index, channel in
                        channelGridCard(channel: channel, isIPad: isIPad) {
                            HapticFeedback.generate(.medium)
                            guard isTVConnected else {
                                onCastTapped?()
                                return
                            }
                            onSelectChannel(channels, index)
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
            }
            .padding(.top, 4)
            .padding(.bottom, 34)
        }
    }
    
    // MARK: - Channel Grid Card (Whole Card Selectable with Spring 0.92)
    @ViewBuilder
    private func channelGridCard(channel: TR_Channel, isIPad: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: isIPad ? 8 : 6) {
                // Channel Logo Container
                ZStack {
                    if let logo = channel.logo, let url = URL(string: logo), !logo.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: isIPad ? 48 : 38, height: isIPad ? 48 : 38)
                            case .failure(_), .empty:
                                Image(systemName: "tv.fill")
                                    .font(.system(size: isIPad ? 26 : 22))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            @unknown default:
                                Image(systemName: "tv.fill")
                                    .font(.system(size: isIPad ? 26 : 22))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                    } else {
                        Image(systemName: "tv.fill")
                            .font(.system(size: isIPad ? 26 : 22))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .frame(width: isIPad ? 52 : 42, height: isIPad ? 52 : 42)
                .padding(.top, isIPad ? 14 : 12)
                
                // Channel Name
                Text(channel.name ?? "Channel")
                    .font(.inter(.semiBold, size: isIPad ? 14 : 12, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "111827"))
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
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
}
