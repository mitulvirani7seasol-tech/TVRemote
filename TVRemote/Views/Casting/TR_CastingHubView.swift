//
//  TR_CastingHubView.swift
//  TVRemote
//
//  Created by iOS Developer on 01/10/2026.
//

import SwiftUI

// MARK: - Cast Card Item Definition
enum CastCardItem: String, CaseIterable, Identifiable {
    case photos = "photos"
    case videos = "videos"
    case music = "music"
    case web = "web"
    case youtube = "youtube"
    case iptv = "iptv"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .photos: return "ic_cast_photo"
        case .videos: return "ic_cast_Video"
        case .music: return "ic_cast_music"
        case .web: return "ic_cast_web"
        case .youtube: return "ic_cast_youtube"
        case .iptv: return "ic_cast_iptv"
        }
    }
    
    @MainActor func localizedTitle(languageManager: TR_LanguageManager) -> String {
        switch self {
        case .photos: return languageManager.localized("photos")
        case .videos: return languageManager.localized("videos")
        case .music: return languageManager.localized("music")
        case .web: return languageManager.localized("web")
        case .youtube: return languageManager.localized("youtube")
        case .iptv: return languageManager.localized("iptv")
        }
    }
    
    @MainActor func localizedSubtitle(languageManager: TR_LanguageManager) -> String {
        switch self {
        case .photos: return languageManager.localized("cast_your_memories")
        case .videos: return languageManager.localized("big_screen_experience")
        case .music: return languageManager.localized("feel_the_rhythm")
        case .web: return languageManager.localized("browse_on_tv")
        case .youtube: return languageManager.localized("watch_together")
        case .iptv: return languageManager.localized("live_tv_streaming")
        }
    }
}

struct TR_CastingHubView: View {
    @ObservedObject var languageManager = TR_LanguageManager.shared
    @ObservedObject var deviceManager = DeviceConnectionManager.shared
    
    var onSelectFeature: (String) -> Void
    var onOpenConnectToTV: () -> Void
    var onOpenSettings: () -> Void
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { UIDevice.isIPad || horizontalSizeClass == .regular }
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let horizontalPadding: CGFloat = isIPad ? (isLandscape ? 48 : 32) : 20
            let columnsCount = isIPad ? (isLandscape ? 4 : 3) : 2
            let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: columnsCount)
            
            VStack(spacing: 0) {
                // Top Header Bar
                HStack(alignment: .center) {
                    Text(languageManager.localized("casting"))
                        .font(.inter(.bold, size: isIPad ? 28 : 24, autoScaleForPad: false))
                        .foregroundColor(TR_Theme.textPrimary)
                    
                    Spacer()
                    
                    // Cast Button with Liquid Glass Container
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onOpenConnectToTV()
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
                
                // 2-Column Grid of Liquid Glass Casting Cards (6 Items)
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(CastCardItem.allCases) { item in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onSelectFeature(item.rawValue)
                            }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .top) {
                                        // 3D Custom Icon from Tab_cast
                                        Image(item.iconName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: isIPad ? 52 : 44, height: isIPad ? 52 : 44)
                                        
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
                                    
                                    Spacer(minLength: 4)
                                    
                                    Text(item.localizedTitle(languageManager: languageManager))
                                        .font(.inter(.bold, size: isIPad ? 19 : 15.5, autoScaleForPad: false))
                                        .foregroundColor(Color(hex: "111827"))
                                        .lineLimit(1)
                                    
                                    Text(item.localizedSubtitle(languageManager: languageManager))
                                        .font(.inter(.regular, size: isIPad ? 13 : 11.5, autoScaleForPad: false))
                                        .foregroundColor(Color(hex: "788292"))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, isIPad ? 18 : 14)
                                .padding(.vertical, isIPad ? 18 : 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: isIPad ? 144 : 124)
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
                            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.95))
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 4)
                    .padding(.bottom, 120)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
