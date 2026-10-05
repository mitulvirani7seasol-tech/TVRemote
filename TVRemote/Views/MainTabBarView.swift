//
//  MainTabBarView.swift
//  TVRemote
//
//  Created by iOS Developer on 01/10/2026.
//

import SwiftUI

enum TabSelection: Int, CaseIterable {
    case remote = 0
    case casting = 1
    case settings = 2
}

struct MainTabBarView: View {
    @ObservedObject var languageManager = TR_LanguageManager.shared
    @Binding var selectedTab: TabSelection
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { UIDevice.isIPad || horizontalSizeClass == .regular }
    
    var body: some View {
        HStack(spacing: 0) {
            // Tab 0: Remote
            tabButton(
                tab: .remote,
                title: languageManager.localized("remote_tab"),
                selectedIcon: "ic_remote_selected",
                unselectedIcon: "ic_remote_unselect"
            )
            
            // Tab 1: Casting
            tabButton(
                tab: .casting,
                title: languageManager.localized("casting"),
                selectedIcon: "ic_casting_select",
                unselectedIcon: "ic_casting_unselect"
            )
            
            // Tab 2: Settings
            tabButton(
                tab: .settings,
                title: languageManager.localized("settings"),
                selectedIcon: "ic_setting_select",
                unselectedIcon: "ic_setting_unselect"
            )
        }
        .padding(.horizontal, 16)
        .frame(height: 72)
        .glassTabBarModifier(cornerRadius: 36)
        .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
        .padding(.horizontal, isIPad ? 60 : 20)
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private func tabButton(tab: TabSelection, title: String, selectedIcon: String, unselectedIcon: String) -> some View {
        let isSelected = selectedTab == tab
        
        Button(action: {
            if selectedTab != tab {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    selectedTab = tab
                }
            }
        }) {
            VStack(spacing: 4) {
                if isSelected {
                    ZStack {
                        Circle()
                            .fill(TR_Theme.activeCircleGradient)
                            .frame(width: 50, height: 50)
                            .shadow(color: TR_Theme.primaryPink.opacity(0.4), radius: 8, x: 0, y: 4)
                        
                        Image(selectedIcon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .foregroundColor(.white)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    VStack(spacing: 3) {
                        Image(unselectedIcon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(TR_Theme.textSecondary)
                        
                        Text(title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(TR_Theme.textSecondary)
                    }
                    .frame(height: 48)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    struct TabBarPreviewContainer: View {
        @State private var selectedTab: TabSelection = .remote
        
        var body: some View {
            ZStack(alignment: .bottom) {
                Image("BG")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                
                MainTabBarView(selectedTab: $selectedTab)
                    .padding(.bottom, 8)
            }
        }
    }
    
    return TabBarPreviewContainer()
}


