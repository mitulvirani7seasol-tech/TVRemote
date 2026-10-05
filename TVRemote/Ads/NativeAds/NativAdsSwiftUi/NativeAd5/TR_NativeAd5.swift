//
//  TR_NativeAd6.swift
//  TV Remote Casting
//
//  Created by Ronik Hirpara on 18/10/25.
//

import Foundation
import SwiftUI

struct TR_NativeAd5: View {
    @StateObject private var nativeViewModel = TR_NativeAdViewModel()
    @AppStorage(TR_SessionKeys.isPro) var isPro = false
    @State var hasLoadedOnce = false

    var body: some View {
        VStack{
            if !isPro{
                if let _ = nativeViewModel.secondSmallNativeAd {
                    TR_NativeAd5Container(nativeViewModel: nativeViewModel)
                        .frame(height: isIpad() ? 110 : 82)
                        .background(Color.white.opacity(0.50))
                        .cornerRadius(8)
                }else if nativeViewModel.didFailToSmallNativeLoad {
                    Color.clear
                        .frame(height: 0)
                        .animation(.easeOut(duration: 0.3), value: nativeViewModel.didFailToSmallNativeLoad)
                }  else {
                    TR_ShimmerPlaceholderView()
                        .frame(height: isIpad() ? 110 : 82)
                        .padding(.horizontal, 8)
                }
            }
        }
            .onAppear {
                if !hasLoadedOnce {
                    nativeViewModel.refreshSecondSmallNative()
                    hasLoadedOnce = true
                }
            }
    }
    
    private func refreshAd() {
        nativeViewModel.refreshSecondSmallNative()
    }
}

private struct TR_NativeAd5Container: UIViewRepresentable {
    typealias UIViewType = TR_GoogleNativeAdsCustomeView5
    
    @ObservedObject var nativeViewModel: TR_NativeAdViewModel
    
    func makeUIView(context: Context) -> TR_GoogleNativeAdsCustomeView5 {
        return TR_GoogleNativeAdsCustomeView5.instanceFromNib() as! TR_GoogleNativeAdsCustomeView5
    }
    
    func updateUIView(_ nativeAdView: TR_GoogleNativeAdsCustomeView5, context: Context) {
        guard let nativeAd = nativeViewModel.secondSmallNativeAd else { return }
        
        nativeAdView.nativeAd = nativeAd
        nativeAdView.setup()
    }
}
