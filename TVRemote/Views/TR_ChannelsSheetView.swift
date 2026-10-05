//
//  TR_ChannelsSheetView.swift
//  TVRemote
//
//  Created by iOS Developer on 01/10/2026.
//

import SwiftUI

// MARK: - TV Channel Item Model
struct TR_ChannelItem: Identifiable, Hashable {
    let id: String
    let name: String
    let imageName: String
    let systemIcon: String
    
    static func == (lhs: TR_ChannelItem, rhs: TR_ChannelItem) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }
}

struct TR_ChannelsSheetView: View {
    @ObservedObject var languageManager = TR_LanguageManager.shared
    @ObservedObject var remoteVM = TR_RemoteViewModel.shared
    var isTVConnected: Bool = false
    var onOpenConnectTV: (() -> Void)? = nil
    var onClose: () -> Void
    var onSelectChannel: ((TR_TVApps) -> Void)? = nil
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { UIDevice.isIPad || horizontalSizeClass == .regular }
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    // MARK: - Effective TV Type Resolution
    private var effectiveTvType: TR_TelevisionType? {
        if let type = remoteVM.connectedTVType, type != .NONETV {
            return type
        }
        if let type = TR_DeviceConnectivityViewModel.shared.getConnectedTvType(), type != .NONETV {
            return type
        }
        if let dev = DeviceConnectionManager.shared.connectedDevice {
            if dev.isAirPlay { return .AIRPLAY }
            let lowerName = (dev.name + " " + dev.model).lowercased()
            if lowerName.contains("samsung") || lowerName.contains("tizen") { return .SAMSUNG }
            if lowerName.contains("lg") || lowerName.contains("webos") { return .LG }
            if lowerName.contains("roku") { return .ROKU }
            if lowerName.contains("fire") { return .FIRE }
            if lowerName.contains("android") || lowerName.contains("google") { return .ANDROID }
        }
        return nil
    }
    
    private var isActuallyConnected: Bool {
        isTVConnected || DeviceConnectionManager.shared.isActuallyConnected || (effectiveTvType != nil && effectiveTvType != .NONETV)
    }
    
    // MARK: - Dynamic Channels Based on Connected TV
    private var channelsForCurrentTV: [TR_ChannelItem] {
        guard isActuallyConnected, let tvType = effectiveTvType else {
            return defaultPopularChannels
        }
        
        switch tvType {
        case .LG:
            return [
                TR_ChannelItem(id: "com.webos.app.lgchannels", name: "LG Channels", imageName: "LG Channels", systemIcon: "tv.fill"),
                TR_ChannelItem(id: "netflix", name: "Netflix", imageName: "Netflix", systemIcon: "film.fill"),
                TR_ChannelItem(id: "amazon", name: "Prime Video", imageName: "Prime Video", systemIcon: "play.tv.fill"),
                TR_ChannelItem(id: "hotstar", name: "Disney+", imageName: "JioHotstar", systemIcon: "sparkles.tv.fill"),
                TR_ChannelItem(id: "youtube.leanback.v4", name: "YouTube", imageName: "Youtube", systemIcon: "play.rectangle.fill"),
                TR_ChannelItem(id: "spotify-beehive", name: "Spotify", imageName: "Spotify", systemIcon: "music.note.tv.fill"),
                TR_ChannelItem(id: "com.apple.appletv", name: "Apple TV", imageName: "Apple TV", systemIcon: "appletv.fill"),
                TR_ChannelItem(id: "com.zee5.app", name: "ZEE5", imageName: "ZEE5", systemIcon: "tv.fill"),
                TR_ChannelItem(id: "com.twin.app.gamingportal", name: "Gaming Portal", imageName: "LG Gaming Portal", systemIcon: "gamecontroller.fill"),
                TR_ChannelItem(id: "com.webos.app.discovery", name: "Apps", imageName: "Apps", systemIcon: "square.grid.2x2.fill"),
                TR_ChannelItem(id: "com.webos.app.homeoffice", name: "Home Office", imageName: "Home Office", systemIcon: "briefcase.fill"),
                TR_ChannelItem(id: "com.webos.app.totalmusic", name: "Music", imageName: "Music", systemIcon: "music.note"),
                TR_ChannelItem(id: "com.webos.app.homeconnect", name: "Home Hub", imageName: "Home Hub", systemIcon: "house.fill"),
                TR_ChannelItem(id: "com.webos.app.learning", name: "Learning", imageName: "Learning", systemIcon: "book.fill"),
                TR_ChannelItem(id: "com.webos.app.browser", name: "Web Browser", imageName: "Web Browser", systemIcon: "globe"),
                TR_ChannelItem(id: "com.webos.app.mediadiscovery", name: "Media Player", imageName: "Media Player", systemIcon: "play.circle.fill")
            ]
            
        case .SAMSUNG:
            var samsungList: [TR_ChannelItem] = []
            
            // If the connected Samsung TV returned installed apps dynamically
            for app in remoteVM.samsungTVApps {
                let img = imageForAppName(app.name)
                samsungList.append(TR_ChannelItem(id: app.id, name: app.name, imageName: img, systemIcon: "tv.fill"))
            }
            
            // Standard curated Samsung apps
            let defaultSamsung: [TR_ChannelItem] = [
                TR_ChannelItem(id: "samsung_tv_plus", name: "Samsung TV", imageName: "Samsung TV", systemIcon: "tv.fill"),
                TR_ChannelItem(id: "111299001912", name: "YouTube", imageName: "Youtube", systemIcon: "play.rectangle.fill"),
                TR_ChannelItem(id: "11101200001", name: "Netflix", imageName: "Netflix", systemIcon: "film.fill"),
                TR_ChannelItem(id: "3201512006785", name: "Prime Video", imageName: "Prime Video", systemIcon: "play.tv.fill"),
                TR_ChannelItem(id: "111399002203", name: "Disney+", imageName: "JioHotstar", systemIcon: "sparkles.tv.fill"),
                TR_ChannelItem(id: "3201807016597", name: "Apple TV", imageName: "Apple TV", systemIcon: "appletv.fill"),
                TR_ChannelItem(id: "3201606009684", name: "Spotify", imageName: "Spotify", systemIcon: "music.note.tv.fill"),
                TR_ChannelItem(id: "org.tizen.browser", name: "Web Browser", imageName: "Web Browser", systemIcon: "globe"),
                TR_ChannelItem(id: "paramount", name: "Paramount+", imageName: "Paramount", systemIcon: "tv.fill"),
                TR_ChannelItem(id: "espn", name: "ESPN", imageName: "ESPN", systemIcon: "sportscourt.fill"),
                TR_ChannelItem(id: "hulu", name: "Hulu", imageName: "Hulu", systemIcon: "play.circle.fill"),
                TR_ChannelItem(id: "peacock", name: "Peacock", imageName: "Peacock", systemIcon: "tv.circle.fill")
            ]
            
            for item in defaultSamsung {
                if !samsungList.contains(where: { $0.name.lowercased() == item.name.lowercased() || $0.id == item.id }) {
                    samsungList.append(item)
                }
            }
            return samsungList
            
        case .FIRE:
            return [
                TR_ChannelItem(id: "com.amazon.firetv.youtube", name: "YouTube", imageName: "Youtube", systemIcon: "play.rectangle.fill"),
                TR_ChannelItem(id: "com.netflix.ninja", name: "Netflix", imageName: "Netflix", systemIcon: "film.fill"),
                TR_ChannelItem(id: "com.amazon.avod", name: "Prime Video", imageName: "Prime Video", systemIcon: "play.tv.fill"),
                TR_ChannelItem(id: "com.spotify.tv.android", name: "Spotify", imageName: "Spotify", systemIcon: "music.note.tv.fill"),
                TR_ChannelItem(id: "com.disney.disneyplus", name: "Disney+", imageName: "JioHotstar", systemIcon: "sparkles.tv.fill"),
                TR_ChannelItem(id: "com.cbs.app", name: "Paramount+", imageName: "Paramount", systemIcon: "tv.fill"),
                TR_ChannelItem(id: "com.espn.score_center", name: "ESPN", imageName: "ESPN", systemIcon: "sportscourt.fill"),
                TR_ChannelItem(id: "com.hulu.livingroomplus", name: "Hulu", imageName: "Hulu", systemIcon: "play.circle.fill"),
                TR_ChannelItem(id: "com.peacocktv.peacockandroid", name: "Peacock", imageName: "Peacock", systemIcon: "tv.circle.fill")
            ]
            
        case .ROKU:
            return [
                TR_ChannelItem(id: "837", name: "YouTube", imageName: "Youtube", systemIcon: "play.rectangle.fill"),
                TR_ChannelItem(id: "12", name: "Netflix", imageName: "Netflix", systemIcon: "film.fill"),
                TR_ChannelItem(id: "22297", name: "Spotify", imageName: "Spotify", systemIcon: "music.note.tv.fill"),
                TR_ChannelItem(id: "291097", name: "Disney+", imageName: "JioHotstar", systemIcon: "sparkles.tv.fill"),
                TR_ChannelItem(id: "31440", name: "Paramount+", imageName: "Paramount", systemIcon: "tv.fill"),
                TR_ChannelItem(id: "34376", name: "ESPN", imageName: "ESPN", systemIcon: "sportscourt.fill"),
                TR_ChannelItem(id: "2285", name: "Hulu", imageName: "Hulu", systemIcon: "play.circle.fill"),
                TR_ChannelItem(id: "593099", name: "Peacock", imageName: "Peacock", systemIcon: "tv.circle.fill"),
                TR_ChannelItem(id: "13", name: "Prime Video", imageName: "Prime Video", systemIcon: "play.tv.fill")
            ]
            
        case .ANDROID:
            return [
                TR_ChannelItem(id: "https://www.youtube.com/", name: "YouTube", imageName: "Youtube", systemIcon: "play.rectangle.fill"),
                TR_ChannelItem(id: "https://www.netflix.com/title", name: "Netflix", imageName: "Netflix", systemIcon: "film.fill"),
                TR_ChannelItem(id: "https://www.primevideo.com/", name: "Prime Video", imageName: "Prime Video", systemIcon: "play.tv.fill"),
                TR_ChannelItem(id: "https://open.spotify.com/", name: "Spotify", imageName: "Spotify", systemIcon: "music.note.tv.fill"),
                TR_ChannelItem(id: "https://www.disneyplus.com/", name: "Disney+", imageName: "JioHotstar", systemIcon: "sparkles.tv.fill"),
                TR_ChannelItem(id: "https://www.paramountplus.com/", name: "Paramount+", imageName: "Paramount", systemIcon: "tv.fill"),
                TR_ChannelItem(id: "https://www.espn.com/watch/", name: "ESPN", imageName: "ESPN", systemIcon: "sportscourt.fill"),
                TR_ChannelItem(id: "https://play.google.com/store/apps/details?id=com.hulu.livingroomplus", name: "Hulu", imageName: "Hulu", systemIcon: "play.circle.fill"),
                TR_ChannelItem(id: "https://www.peacocktv.com/", name: "Peacock", imageName: "Peacock", systemIcon: "tv.circle.fill")
            ]
            
        case .AIRPLAY, .NONETV:
            return defaultPopularChannels
        }
    }
    
    private var defaultPopularChannels: [TR_ChannelItem] {
        [
            TR_ChannelItem(id: "youtube", name: "YouTube", imageName: "Youtube", systemIcon: "play.rectangle.fill"),
            TR_ChannelItem(id: "netflix", name: "Netflix", imageName: "Netflix", systemIcon: "film.fill"),
            TR_ChannelItem(id: "prime", name: "Prime Video", imageName: "Prime Video", systemIcon: "play.tv.fill"),
            TR_ChannelItem(id: "spotify", name: "Spotify", imageName: "Spotify", systemIcon: "music.note.tv.fill"),
            TR_ChannelItem(id: "disney", name: "Disney+", imageName: "JioHotstar", systemIcon: "sparkles.tv.fill"),
            TR_ChannelItem(id: "paramount", name: "Paramount+", imageName: "Paramount", systemIcon: "tv.fill"),
            TR_ChannelItem(id: "espn", name: "ESPN", imageName: "ESPN", systemIcon: "sportscourt.fill"),
            TR_ChannelItem(id: "hulu", name: "Hulu", imageName: "Hulu", systemIcon: "play.circle.fill"),
            TR_ChannelItem(id: "peacock", name: "Peacock", imageName: "Peacock", systemIcon: "tv.circle.fill")
        ]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Indicator
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 38, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 14)
            
            // Header: Title & Subtitle + Close Button
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(languageManager.localized("channels"))
                        .font(.inter(.bold, size: isIPad ? 22 : 19, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "111827"))
                    
                    Text(languageManager.localized("quick_access_to_apps"))
                        .font(.inter(.medium, size: isIPad ? 14 : 12.5, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "6B7280"))
                }
                
                Spacer()
                
                Button(action: {
                    triggerHaptic()
                    onClose()
                }) {
                    Circle()
                        .fill(Color.white.opacity(0.65))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "4B5563"))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            
            // Grid of Channels
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(channelsForCurrentTV) { channel in
                        channelCard(channel: channel)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, isIPad ? 32 : 28)
            }
            .frame(maxHeight: isIPad ? 420 : 340)
        }
        .frame(maxWidth: isIPad ? 480 : .infinity)
        .background(
            ZStack {
                CustomRoundedCorners(radius: 32, corners: [.topLeft, .topRight])
                    .fill(.ultraThinMaterial)
                
                CustomRoundedCorners(radius: 32, corners: [.topLeft, .topRight])
                    .fill(Color.white.opacity(0.35))
            }
            .clipShape(CustomRoundedCorners(radius: 32, corners: [.topLeft, .topRight]))
            .overlay(
                CustomRoundedCorners(radius: 32, corners: [.topLeft, .topRight])
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: -6)
            .ignoresSafeArea(edges: .bottom)
        )
    }
    
    @ViewBuilder
    private func channelCard(channel: TR_ChannelItem) -> some View {
        let cardHeight: CGFloat = isIPad ? 114 : 100
        let iconSize: CGFloat = isIPad ? 56 : 46
        
        Button(action: {
            triggerHaptic()
            launchChannelItem(channel)
        }) {
            VStack(spacing: 7) {
                if let _ = UIImage(named: channel.imageName) {
                    Image(channel.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.red.opacity(0.12))
                            .frame(width: iconSize, height: iconSize)
                        
                        Image(systemName: channel.systemIcon)
                            .font(.system(size: iconSize * 0.52))
                            .foregroundColor(.red)
                    }
                }
                
                Text(channel.name)
                    .font(.inter(.semiBold, size: isIPad ? 13.5 : 12, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "111827"))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight)
            .glassCard(cornerRadius: 18, isInteractive: true)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.90), Color.white.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.1
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
    }
    
    // MARK: - App Launching Dispatcher
    private func launchChannelItem(_ item: TR_ChannelItem) {
        if let tvApp = TR_TVApps(rawValue: item.name.lowercased()) ?? TR_TVApps(rawValue: item.id.lowercased()), let onSelectChannel = onSelectChannel {
            onSelectChannel(tvApp)
            onClose()
            return
        }
        
        guard isActuallyConnected, let tvType = effectiveTvType else {
            if let onOpenConnectTV = onOpenConnectTV {
                onOpenConnectTV()
            } else {
                onClose()
            }
            return
        }
        
        if remoteVM.connectedTVType == nil {
            remoteVM.connectedTVType = tvType
        }
        
        let lowerName = item.name.lowercased()
        let lowerId = item.id.lowercased()
        let matchingTVApp: TR_TVApps? = TR_TVApps(rawValue: lowerName) ?? TR_TVApps(rawValue: lowerId)
            ?? (lowerName.contains("youtube") ? .youtube :
                lowerName.contains("netflix") ? .netflix :
                lowerName.contains("prime") || lowerName.contains("amazon") ? .prime :
                lowerName.contains("spotify") ? .spotify :
                lowerName.contains("disney") || lowerName.contains("hotstar") ? .disney :
                lowerName.contains("paramount") ? .paramount :
                lowerName.contains("espn") ? .eSPN :
                lowerName.contains("hulu") ? .hulu :
                lowerName.contains("peacock") ? .peacock : nil)
        
        switch tvType {
        case .LG:
            if let lgManager = remoteVM.currentTVManager as? TR_LGControlManager {
                if lgManager.selectedDevice == nil {
                    lgManager.selectedDevice = TR_DeviceConnectivityViewModel.shared.connectSDKDiscoveryModel.selectedLGDevice ?? DeviceConnectionManager.shared.connectedDevice?.connectableDevice
                }
                
                if lowerName.contains("youtube") {
                    lgManager.LaunchYoutube()
                } else if lowerName.contains("netflix") {
                    lgManager.LauchNetfliz()
                } else if lowerName.contains("prime") || lowerName.contains("amazon") {
                    lgManager.LauchPrime()
                } else if lowerName.contains("browser") || item.id == "com.webos.app.browser" {
                    lgManager.launchBrowser(urlString: "https://www.google.com")
                } else {
                    lgManager.LaunchApp(url: item.id)
                    lgManager.sendSSAPCommand(target: "ssap://system.launcher/launch", payload: ["id": item.id])
                }
            } else if let tvApp = matchingTVApp {
                remoteVM.launchApp(tvApp)
            }
            
        case .SAMSUNG:
            if item.id == "samsung_tv_plus" || lowerName.contains("samsung tv") {
                remoteVM.launchSamsungInstalledApp(TR_TVApp(id: "org.tizen.samsungtvplus", name: "Samsung TV"))
                (remoteVM.currentTVManager as? TR_SamsungControlManager)?.TR_KeyPress(keyCode: .channelList)
            } else if !item.id.isEmpty && item.id != item.name && !item.id.contains("http") {
                remoteVM.launchSamsungInstalledApp(TR_TVApp(id: item.id, name: item.name))
            } else if let tvApp = matchingTVApp {
                remoteVM.launchApp(tvApp)
            } else {
                remoteVM.launchSamsungInstalledApp(TR_TVApp(id: item.id, name: item.name))
            }
            
        case .FIRE:
            if let fireManager = remoteVM.currentTVManager as? TR_FireControlManager {
                fireManager.launchAppOnRemote(appId: item.id) { _ in }
            }
            if let tvApp = matchingTVApp {
                remoteVM.launchApp(tvApp)
            }
            
        case .ROKU:
            if let rokuManager = remoteVM.currentTVManager as? TR_RokuControlManager {
                rokuManager.launchApp(item.id)
            }
            if let tvApp = matchingTVApp {
                remoteVM.launchApp(tvApp)
            }
            
        case .ANDROID:
            if let androidManager = remoteVM.currentTVManager as? TR_AndroidControlManager {
                if item.id.hasPrefix("http") {
                    androidManager.launchMediaOnRemoteScreen(url: item.id)
                } else if let tvApp = matchingTVApp {
                    androidManager.launchMediaOnRemoteScreen(url: tvApp.deepLinkURL)
                } else {
                    androidManager.launchMediaOnRemoteScreen(url: item.id)
                }
            }
            if let tvApp = matchingTVApp {
                remoteVM.launchApp(tvApp)
            }
            
        case .AIRPLAY, .NONETV:
            break
        }
        
        onClose()
    }
    
    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func imageForAppName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("youtube") { return "Youtube" }
        if lower.contains("netflix") { return "Netflix" }
        if lower.contains("prime") || lower.contains("amazon") { return "Prime Video" }
        if lower.contains("disney") || lower.contains("hotstar") { return "JioHotstar" }
        if lower.contains("spotify") { return "Spotify" }
        if lower.contains("apple") { return "Apple TV" }
        if lower.contains("zee") { return "ZEE5" }
        if lower.contains("paramount") { return "Paramount" }
        if lower.contains("espn") { return "ESPN" }
        if lower.contains("hulu") { return "Hulu" }
        if lower.contains("peacock") { return "Peacock" }
        if lower.contains("samsung") { return "Samsung TV" }
        if lower.contains("browser") || lower.contains("web") { return "Web Browser" }
        if lower.contains("game") || lower.contains("gaming") { return "LG Gaming Portal" }
        if lower.contains("music") { return "Music" }
        if lower.contains("office") { return "Home Office" }
        if lower.contains("hub") { return "Home Hub" }
        if lower.contains("learn") { return "Learning" }
        if lower.contains("media") || lower.contains("player") { return "Media Player" }
        if lower.contains("lg") { return "LG Channels" }
        return "Apps"
    }
}
