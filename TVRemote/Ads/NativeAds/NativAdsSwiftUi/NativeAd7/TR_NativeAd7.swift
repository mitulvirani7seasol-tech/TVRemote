//
//  NativeAd3.swift
//  TV Remote Casting
//
//  Created by Ronik Hirpara on 17/10/25.
//

import Foundation
import ShimmerSwift
import SwiftUI


struct TR_NativeAd7: View {
    @StateObject private var nativeViewModel = TR_NativeAdViewModel()
    @AppStorage(TR_SessionKeys.isPro) var isPro = false
    @State var hasLoadedOnce = false

    var body: some View {
        VStack {
            if !isPro {
                if let _ = nativeViewModel.nativeAd {
                    TR_NativeAd7Container(nativeViewModel: nativeViewModel)
                        .frame(height: isIpad() ? 240 : 210)
                        .background(Color.white.opacity(0.50))
                        .cornerRadius(8)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.3), value: nativeViewModel.nativeAd)
                } else {
                    EmptyView()
                }
            }
        }
        .onAppear {
            if !hasLoadedOnce {
                nativeViewModel.refreshAd()
                hasLoadedOnce = true
            }
        }
    }
}



//struct TR_NativeAd7: View {
//    @StateObject private var nativeViewModel = TR_NativeAdViewModel()
//    @AppStorage(TR_SessionKeys.isPro) var isPro = false
//
//    var body: some View {
//        VStack {
//            if !isPro {
//                if let _ = nativeViewModel.nativeAd {
//                    TR_NativeAd7Container(nativeViewModel: nativeViewModel)
//                        .frame(height: 190)
//                        .background(Color.white.opacity(0.5))
//                } else {
//                    TR_ShimmerPlaceholderView()
//                        .frame(height: 190)
//                        .padding(.horizontal, 8)
//                }
//            }
//        }
//        .onAppear {
//            nativeViewModel.refreshAd()
//        }
//    }
//}

struct TR_ShimmerPlaceholderView: UIViewRepresentable {
    func makeUIView(context: Context) -> ShimmeringView {
        let shimmerView = ShimmeringView()
        shimmerView.frame = .zero
        shimmerView.isShimmering = true
        
        // Create a content UIView (could be skeleton UI: e.g., gray boxes)
        let content = UIView()
        content.backgroundColor = hexStringToUIColor(hex: "#BDBDBD")
        content.alpha = 0.5
        content.layer.cornerRadius = 8
        
        shimmerView.contentView = content
        
        return shimmerView
    }

    func updateUIView(_ uiView: ShimmeringView, context: Context) {
        // nothing dynamic for now
    }
}




private struct TR_NativeAd7Container: UIViewRepresentable {
    typealias UIViewType = TR_GoogleNativeAdsCustomeView7
    
    @ObservedObject var nativeViewModel: TR_NativeAdViewModel
    
    func makeUIView(context: Context) -> TR_GoogleNativeAdsCustomeView7 {
        return TR_GoogleNativeAdsCustomeView7.instanceFromNib() as! TR_GoogleNativeAdsCustomeView7
    }
    
    func updateUIView(_ nativeAdView: TR_GoogleNativeAdsCustomeView7, context: Context) {
        guard let nativeAd = nativeViewModel.nativeAd else { return }
        
        nativeAdView.nativeAd = nativeAd
        nativeAdView.setup()
    }
}

