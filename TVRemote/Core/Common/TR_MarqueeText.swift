//
//  TR_MarqueeText.swift
//  TV Remote
//

import SwiftUI

struct TR_MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    var speed: Double = 30.0 // Points per second
    
    @State private var textWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var isAnimating: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            let containerWidth = geo.size.width
            let shouldScroll = textWidth > containerWidth && containerWidth > 0
            
            ZStack(alignment: .leading) {
                if shouldScroll {
                    HStack(spacing: 36) {
                        Text(text)
                            .font(font)
                            .foregroundColor(color)
                            .lineLimit(1)
                            .fixedSize()
                        
                        Text(text)
                            .font(font)
                            .foregroundColor(color)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .offset(x: offset)
                    .onAppear {
                        runAnimation(containerWidth: containerWidth)
                    }
                } else {
                    Text(text)
                        .font(font)
                        .foregroundColor(color)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: containerWidth, alignment: .leading)
            .clipped()
            .onChange(of: geo.size.width) { newWidth in
                if textWidth > newWidth {
                    runAnimation(containerWidth: newWidth)
                } else {
                    offset = 0
                }
            }
        }
        .frame(height: 20)
        .background(
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize()
                .background(
                    GeometryReader { textGeo in
                        Color.clear.preference(key: TextWidthPreferenceKey.self, value: textGeo.size.width)
                    }
                )
                .hidden()
        )
        .onPreferenceChange(TextWidthPreferenceKey.self) { width in
            self.textWidth = width
        }
    }
    
    private func runAnimation(containerWidth: CGFloat) {
        guard textWidth > containerWidth, containerWidth > 0 else { return }
        let distance = textWidth + 36
        let duration = Double(distance) / speed
        
        offset = 0
        withAnimation(
            .linear(duration: duration)
            .repeatForever(autoreverses: false)
            .delay(1.2)
        ) {
            offset = -distance
        }
    }
}

private struct TextWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
