//
//  LottieView.swift
//  TV Remote
//

import SwiftUI

/// Ultra-smooth, crash-proof native loader matching the exact Splash.json design
struct AppLottieView: View {
    var animationName: String = "loading bar"
    
    @State private var isAnimating: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let barWidth = totalWidth * 0.45
            
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color(hex: "E2E8F0").opacity(0.8))
                    .frame(height: 5)
                
                // Animated Active Gradient Bar
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#8E03A1"), Color(hex: "#E25F89")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: barWidth, height: 5)
                    .offset(x: isAnimating ? (totalWidth - barWidth) : 0)
                    .shadow(color: Color(hex: "#8E03A1").opacity(0.4), radius: 4, x: 0, y: 1)
            }
        }
        .frame(height: 5)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.1)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

