//
//  TR_OnboardingView.swift
//  TV Remote
//
//  Created by iOS Developer on 15/09/2026.
//

import SwiftUI

struct TR_OnboardingView: View {
    @ObservedObject var languageManager = TR_LanguageManager.shared
    var onFinish: () -> Void
    
    @State private var currentPage: Int = 0
    
    init(initialPage: Int = 0, onFinish: @escaping () -> Void = {}) {
        self.onFinish = onFinish
        self._currentPage = State(initialValue: initialPage)
    }
    
    struct IntroPageData {
        let image: String
        let titlePlainKey: String
        let titleHighlightKey: String
        let subtitleKey: String
    }
    
    private let pages: [IntroPageData] = [
        IntroPageData(
            image: "intro_1",
            titlePlainKey: "intro_1_title_plain",
            titleHighlightKey: "intro_1_title_highlight",
            subtitleKey: "intro_1_subtitle"
        ),
        IntroPageData(
            image: "intro_2",
            titlePlainKey: "intro_2_title_plain",
            titleHighlightKey: "intro_2_title_highlight",
            subtitleKey: "intro_2_subtitle"
        ),
        IntroPageData(
            image: "intro_3",
            titlePlainKey: "intro_3_title_plain",
            titleHighlightKey: "intro_3_title_highlight",
            subtitleKey: "intro_3_subtitle"
        )
    ]
    
    // Background color matching Figma: #EBF1FD
    private let themeBgColor = Color(hex: "EBF1FD")
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let isIPad = UIDevice.isIPad
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            
            let titleSize: CGFloat = isIPad ? (isLandscape ? 28 : 34) : (isLandscape ? 22 : 28)
            let subtitleSize: CGFloat = isIPad ? (isLandscape ? 16 : 17) : (isLandscape ? 13 : 14.5)
            let buttonSize: CGFloat = isIPad ? 60 : 50
            let horizontalPadding: CGFloat = isIPad ? (isLandscape ? 56 : 40) : 24
            
            ZStack(alignment: .bottom) {
                // 1. Fullscreen TabView of Intro Slides (Pinned to Top)
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        ZStack(alignment: .top) {
                            Image(pages[index].image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: screenWidth, height: isIPad ? screenHeight * 0.80 : screenHeight * 0.80, alignment: .top)
                                .clipped()
                                .ignoresSafeArea(edges: .top)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea(edges: .top)
                
                // 2. Bottom Content & Controls Overlay (#EBF1FD Background with smooth upward shadow & blend)
                VStack(spacing: 0) {
                    // Smooth tall gradient blend from artwork into #EBF1FD background (eliminates any border line)
                    LinearGradient(
                        stops: [
                            .init(color: themeBgColor.opacity(0.00), location: 0.10),
                            .init(color: themeBgColor.opacity(0.19), location: 0.20),
                            .init(color: themeBgColor.opacity(0.30), location: 0.30),
                            .init(color: themeBgColor.opacity(0.40), location: 0.45),
                            .init(color: themeBgColor.opacity(0.78), location: 0.72),
                            .init(color: themeBgColor.opacity(0.96), location: 0.90),
                            .init(color: themeBgColor, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 30)
                    .allowsHitTesting(false)
                    
                    VStack(spacing: isIPad ? 22 : 16) {
                        // Two-Tone Title & Subtitle
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Text(languageManager.localized(pages[currentPage].titlePlainKey))
                                    .font(.inter(.bold, size: titleSize, autoScaleForPad: false))
                                    .foregroundColor(Color(hex: "111827"))
                                
                                Text(languageManager.localized(pages[currentPage].titleHighlightKey))
                                    .font(.inter(.bold, size: titleSize, autoScaleForPad: false))
                                    .foregroundColor(TR_Theme.primaryPink)
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            
                            Text(languageManager.localized(pages[currentPage].subtitleKey))
                                .font(.inter(.regular, size: subtitleSize, autoScaleForPad: false))
                                .foregroundColor(Color(hex: "6B7280"))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, isIPad ? 40 : 20)
                        }
                        .padding(.horizontal, horizontalPadding)
                        
                        // Bottom Controls Row: 3 Page Dots on Left + 50x50 Gradient Next Button on Right
                        HStack(alignment: .center) {
                            // 3 Page Dots
                            HStack(spacing: 8) {
                                ForEach(0..<pages.count, id: \.self) { dotIndex in
                                    Circle()
                                        .fill(currentPage == dotIndex ? TR_Theme.primaryPink : Color(hex: "CBD5E1"))
                                        .frame(width: currentPage == dotIndex ? 8 : 7.5, height: currentPage == dotIndex ? 8 : 7.5)
                                }
                            }
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                            
                            Spacer()
                            
                            // 50x50 Circular Next Button with #8E03A1 -> #E25F89 Gradient
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                                    if currentPage < pages.count - 1 {
                                        currentPage += 1
                                    } else {
                                        languageManager.completeOnboarding()
                                        onFinish()
                                    }
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(TR_Theme.brandGradientDiagonal)
                                        .frame(width: buttonSize, height: buttonSize)
                                        .shadow(color: TR_Theme.primaryPink.opacity(0.40), radius: 10, x: 0, y: 4)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: isIPad ? 20 : 17, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, 4)
                        .padding(.bottom, isLandscape ? 12 : (isIPad ? 28 : 20))
                    }
                    .background(themeBgColor)
                }
                .shadow(color: themeBgColor.opacity(0.95), radius: 25, x: 0, y: -15)
                .background(themeBgColor.ignoresSafeArea(edges: .bottom))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(themeBgColor.ignoresSafeArea())
    }
}

// MARK: - Xcode Canvas Previews
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TR_OnboardingView(initialPage: 0, onFinish: {})
                .previewDisplayName("Intro Screen 1")
            
            TR_OnboardingView(initialPage: 1, onFinish: {})
                .previewDisplayName("Intro Screen 2")
            
            TR_OnboardingView(initialPage: 2, onFinish: {})
                .previewDisplayName("Intro Screen 3")
        }
    }
}
