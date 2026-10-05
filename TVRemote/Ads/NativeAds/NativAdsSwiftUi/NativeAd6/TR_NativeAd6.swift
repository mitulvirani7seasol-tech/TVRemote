//
//  TR_NativeAd6.swift
//  TV Remote Casting
//
//  Created by Ronik Hirpara on 18/10/25.
//

import Foundation
import SwiftUI

struct TR_NativeAd6: View {
    @StateObject private var nativeViewModel = TR_NativeAdViewModel()
    @AppStorage(TR_SessionKeys.isPro) var isPro = false
    @State var hasLoadedOnce = false

    var body: some View {
        VStack{
            if !isPro{
                if let _ = nativeViewModel.smallNativeAd {
                    TR_NativeAd6Container(nativeViewModel: nativeViewModel)
                        .frame(height: isIpad() ? 110 : 95)
                        .background(Color.white.opacity(0.50))
                        .cornerRadius(8)
                }else if nativeViewModel.didFailToSmallLoad {
                    Color.clear
                        .frame(height: 0)
                        .animation(.easeOut(duration: 0.3), value: nativeViewModel.didFailToSmallLoad)
                }  else {
                    TR_ShimmerPlaceholderView()
                        .frame(height: isIpad() ? 110 : 82)
                        .padding(.horizontal, 8)
                }
            }
        }
            .onAppear {
                if !hasLoadedOnce {
                    nativeViewModel.refreshSmallNative()
                    hasLoadedOnce = true
                }
            }
    }
    
    private func refreshAd() {
        nativeViewModel.refreshSmallNative()
    }
}

private struct TR_NativeAd6Container: UIViewRepresentable {
    typealias UIViewType = TR_GoogleNativeAdsCustomeView6
    
    @ObservedObject var nativeViewModel: TR_NativeAdViewModel
    
    func makeUIView(context: Context) -> TR_GoogleNativeAdsCustomeView6 {
        return TR_GoogleNativeAdsCustomeView6.instanceFromNib() as! TR_GoogleNativeAdsCustomeView6
    }
    
    func updateUIView(_ nativeAdView: TR_GoogleNativeAdsCustomeView6, context: Context) {
        guard let nativeAd = nativeViewModel.smallNativeAd else { return }
        
        nativeAdView.nativeAd = nativeAd
        nativeAdView.setup()
    }
}
