//
//  LanguageSelectionView.swift
//  TV Remote
//
//  Created by iOS Developer on 15/09/2026.
//

import SwiftUI

struct LanguageSelectionView: View {
    @ObservedObject var languageManager = TR_LanguageManager.shared
    var onContinue: () -> Void
    
    @State private var selectedLanguage: LanguageItem
    
    init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
        self._selectedLanguage = State(initialValue: TR_LanguageManager.shared.currentLanguage)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let isIPad = UIDevice.isIPad
            let horizontalPadding: CGFloat = isIPad ? (isLandscape ? 48 : 32) : 18
            let columnsCount = isIPad ? (isLandscape ? 4 : 3) : 2
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: columnsCount)
            
            VStack(spacing: 0) {
                // Top Bar: "Languages" on Left, "Done" Pill Button on Right
                topBar(isIPad: isIPad, horizontalPadding: horizontalPadding)
                    .padding(.top, isIPad ? 24 : 12)
                    .padding(.bottom, isIPad ? 20 : 14)
                
                // 2-Column Grid of Liquid Glass Language Cards
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(LanguageItem.allLanguages) { item in
                            languageGridCard(item: item, isIPad: isIPad)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 4)
                    .padding(.bottom, isIPad ? 32 : 24)
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
        .enableNativeSwipeBack()
        .onAppear {
            selectedLanguage = languageManager.currentLanguage
        }
    }
    
    // MARK: - Top Bar (Title & "Done" Button)
    @ViewBuilder
    private func topBar(isIPad: Bool, horizontalPadding: CGFloat) -> some View {
        HStack(alignment: .center) {
            Text(languageManager.localized("languages", langCode: selectedLanguage.code))
                .font(.inter(.bold, size: isIPad ? 32 : 26, autoScaleForPad: false))
                .foregroundColor(Color(hex: "111827"))
            
            Spacer()
            
            // "Done" Pill Button with Figma #8E03A1 -> #E25F89 Gradient
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                languageManager.selectLanguage(selectedLanguage)
                withAnimation(.easeInOut(duration: 0.3)) {
                    onContinue()
                }
            }) {
                Text(languageManager.localized("done", langCode: selectedLanguage.code))
                    .font(.inter(.bold, size: isIPad ? 17 : 14.5, autoScaleForPad: false))
                    .foregroundColor(.white)
                    .padding(.horizontal, isIPad ? 28 : 22)
                    .padding(.vertical, isIPad ? 10 : 8)
                    .background(TR_Theme.brandGradient)
                    .clipShape(Capsule())
                    .shadow(color: TR_Theme.primaryPink.opacity(0.35), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94))
        }
        .padding(.horizontal, horizontalPadding)
    }
    
    // MARK: - Individual 2-Column Liquid Glass Card
    @ViewBuilder
    private func languageGridCard(item: LanguageItem, isIPad: Bool) -> some View {
        let isSelected = selectedLanguage.id == item.id
        let flagSize: CGFloat = isIPad ? 40 : 34
        let cornerRadius: CGFloat = isIPad ? 22 : 18
        
        Button(action: {
            HapticFeedback.generate(.light)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                selectedLanguage = item
            }
        }) {
            VStack(alignment: .leading, spacing: isIPad ? 14 : 10) {
                // Top Row: Circular Flag on Left + Radio Checkmark on Right
                HStack(alignment: .top) {
                    // Flag circle
                    Image(item.flagImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: flagSize, height: flagSize)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1.5)
                    
                    Spacer()
                    
                    // Radio Button Selection Indicator
                    if isSelected {
                        ZStack {
                            Circle()
                                .fill(TR_Theme.brandGradientDiagonal)
                                .frame(width: isIPad ? 24 : 22, height: isIPad ? 24 : 22)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: isIPad ? 12 : 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    } else {
                        Circle()
                            .stroke(Color(hex: "D1D5DB"), lineWidth: 1.5)
                            .frame(width: isIPad ? 24 : 22, height: isIPad ? 24 : 22)
                    }
                }
                
                // Bottom Column: Language Name & Native Subtitle
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.inter(.bold, size: isIPad ? 17 : 15, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "111827"))
                        .lineLimit(1)
                    
                    Text(item.nativeName)
                        .font(.inter(.regular, size: isIPad ? 14 : 12.5, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "6B7280"))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, isIPad ? 16 : 14)
            .padding(.vertical, isIPad ? 16 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Group {
                    if isSelected {
                        Color.white.opacity(0.60)
                    } else {
                        Color.clear
                    }
                }
            )
            .glassCard(cornerRadius: cornerRadius, isInteractive: true)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isSelected
                            ? LinearGradient(colors: [TR_Theme.primaryPurple, TR_Theme.primaryPink], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: isSelected ? 1.5 : 1.0
                    )
            )
            .shadow(
                color: isSelected ? TR_Theme.primaryPink.opacity(0.20) : Color.black.opacity(0.03),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: 2
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
    }
}

#Preview {
    LanguageSelectionView { }
}
