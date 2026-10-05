//
//  ContentView.swift
//  TVRemote
//
//  Created by Kushang kaklotar on 01/10/26.
//

import SwiftUI

enum AppFlowState {
    case splash
    case language
    case intro
    case main
}

struct ContentView: View {
    @StateObject private var languageManager = TR_LanguageManager.shared
    @State private var flowState: AppFlowState = .splash
    
    var body: some View {
        ZStack {
            switch flowState {
            case .splash:
                SplashScreenView {
                    if !languageManager.hasSelectedLanguage {
                        flowState = .language
                    } else if !languageManager.hasCompletedOnboarding {
                        flowState = .intro
                    } else {
                        flowState = .main
                    }
                }
                .transition(.opacity)
                
            case .language:
                LanguageSelectionView {
                    flowState = .intro
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                
            case .intro:
                TR_OnboardingView {
                    flowState = .main
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                
            case .main:
                MainDashboardView(onOpenLanguage: {
                    flowState = .language
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: flowState)
    }
}
