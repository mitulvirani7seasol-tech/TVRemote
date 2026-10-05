//
//  AirPlayGuideDialog.swift
//  TV Remote
//

import SwiftUI
import AVKit

struct AirPlayGuideDialog: View {
    var onOpenPicker: (() -> Void)? = nil
    var onDismiss: () -> Void
    
    @ObservedObject private var languageManager = TR_LanguageManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { UIDevice.isIPad || horizontalSizeClass == .regular }
    
    private var brandGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "4F6BFF"), location: 0.0),
                .init(color: Color(hex: "2B44EA"), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Close Button Row
            HStack {
                Spacer()
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "9CA3AF"))
                        .padding(8)
                        .background(Circle().fill(Color(hex: "F3F4F6")))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Header: Icon & Title
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(brandGradient)
                        .frame(width: isIPad ? 68 : 58, height: isIPad ? 68 : 58)
                        .shadow(color: Color(hex: "2B44EA").opacity(0.35), radius: 10, x: 0, y: 4)
                    
                    Image(systemName: "airplayvideo")
                        .font(.system(size: isIPad ? 30 : 26, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(languageManager.localized("airplay_guide_title"))
                    .font(.inter(.bold, size: isIPad ? 22 : 18, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "111827"))
                    .multilineTextAlignment(.center)
                
                Text(languageManager.localized("airplay_guide_desc"))
                    .font(.inter(.regular, size: isIPad ? 14 : 12, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "6B7280"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .padding(.top, 4)
            .padding(.bottom, 18)
            
            // 3 Easy Steps
            VStack(spacing: 12) {
                stepRow(
                    stepNumber: "1",
                    icon: "arrow.down.forward.and.arrow.up.backward",
                    title: languageManager.localized("airplay_step_1_title"),
                    desc: languageManager.localized("airplay_step_1_desc")
                )
                
                stepRow(
                    stepNumber: "2",
                    icon: "rectangle.on.rectangle",
                    title: languageManager.localized("airplay_step_2_title"),
                    desc: languageManager.localized("airplay_step_2_desc")
                )
                
                stepRow(
                    stepNumber: "3",
                    icon: "tv.fill",
                    title: languageManager.localized("airplay_step_3_title"),
                    desc: languageManager.localized("airplay_step_3_desc")
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 22)
            
            // Action Buttons
            VStack(spacing: 10) {
                if let onOpenPicker = onOpenPicker {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onOpenPicker()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "airplayaudio")
                                .font(.system(size: 15, weight: .bold))
                            Text(languageManager.localized("open_airplay_picker"))
                                .font(.inter(.bold, size: isIPad ? 16 : 14, autoScaleForPad: false))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: isIPad ? 52 : 46)
                        .background(brandGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color(hex: "2B44EA").opacity(0.35), radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDismiss()
                }) {
                    Text(languageManager.localized("got_it"))
                        .font(.inter(.bold, size: isIPad ? 16 : 14, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "4F6BFF"))
                        .frame(maxWidth: .infinity)
                        .frame(height: isIPad ? 46 : 40)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: isIPad ? 420 : 340)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 10)
        )
    }
    
    @ViewBuilder
    private func stepRow(stepNumber: String, icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "EEF2FF"))
                    .frame(width: 38, height: 38)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "4F6BFF"))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.inter(.semiBold, size: isIPad ? 15 : 13, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "111827"))
                
                Text(desc)
                    .font(.inter(.regular, size: isIPad ? 13 : 11, autoScaleForPad: false))
                    .foregroundColor(Color(hex: "6B7280"))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "F9FAFB"))
        )
    }
}
