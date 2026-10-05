//
//  TR_NativeAd9.swift
//  TV Remote Casting
//
//  Created by Parthiv Akbari on 17/10/25.
//

import Foundation
import ShimmerSwift
import SwiftUI

struct TR_NativeAd9: View {
    @StateObject private var nativeViewModel = TR_NativeAdViewModel()
    @AppStorage(TR_SessionKeys.isPro) var isPro = false
    @State var hasLoadedOnce = false
    
    var body: some View {
        VStack {
            if !isPro {
                if let _ = nativeViewModel.secondNativeAd {
                    TR_NativeAd9Container(nativeViewModel: nativeViewModel)
                        .frame(height: isIpad() ? 240 : 210)
                        .background(Color.white.opacity(0.50))
                        .cornerRadius(8)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.3), value: nativeViewModel.secondNativeAd)
                } else if nativeViewModel.didFailToSecondLoad {
                    Color.clear
                        .frame(height: 0)
                        .animation(.easeOut(duration: 0.3), value: nativeViewModel.didFailToSecondLoad)
                } else {
                    TR_ShimmerPlaceholderView()
                        .frame(height: isIpad() ? 240 : 210)
                        .padding(.horizontal, 8)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: nativeViewModel.secondNativeAd)
                }
            }
        }
        .onAppear {
            if !hasLoadedOnce {
                nativeViewModel.refreshSecondNative()
                hasLoadedOnce = true
            }
        }
    }
}

private struct TR_NativeAd9Container: UIViewRepresentable {
    typealias UIViewType = TR_GoogleNativeAdsCustomeView9
    
    @ObservedObject var nativeViewModel: TR_NativeAdViewModel
    
    func makeUIView(context: Context) -> TR_GoogleNativeAdsCustomeView9 {
        return TR_GoogleNativeAdsCustomeView9.instanceFromNib() as! TR_GoogleNativeAdsCustomeView9
    }
    
    func updateUIView(_ nativeAdView: TR_GoogleNativeAdsCustomeView9, context: Context) {
        guard let nativeAd = nativeViewModel.secondNativeAd else { return }
        
        nativeAdView.nativeAd = nativeAd
        nativeAdView.setup()
    }
}

