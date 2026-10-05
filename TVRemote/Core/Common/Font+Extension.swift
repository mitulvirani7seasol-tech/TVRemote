//
//  Font+Extension.swift
//  TV Remote
//

import SwiftUI

extension Font {
    enum InterWeight {
        case light
        case regular
        case medium
        case semiBold
        case bold
        case extraBold
        case black
        
        var postscriptName: String {
            switch self {
            case .light: return "Inter24pt-Light"
            case .regular: return "Inter24pt-Regular"
            case .medium: return "Inter24pt-Medium"
            case .semiBold: return "Inter24pt-SemiBold"
            case .bold: return "Inter24pt-Bold"
            case .extraBold: return "Inter24pt-ExtraBold"
            case .black: return "Inter24pt-Black"
            }
        }
        
        var systemWeight: Font.Weight {
            switch self {
            case .light: return .light
            case .regular: return .regular
            case .medium: return .medium
            case .semiBold: return .semibold
            case .bold: return .bold
            case .extraBold: return .heavy
            case .black: return .black
            }
        }
    }
    
    static func inter(_ weight: InterWeight = .regular, size: CGFloat, autoScaleForPad: Bool = true) -> Font {
        let finalSize = (autoScaleForPad && UIDevice.isIPad) ? round(size * 1.5) : size
        if UIFont(name: weight.postscriptName, size: finalSize) != nil {
            return .custom(weight.postscriptName, size: finalSize)
        } else {
            return .system(size: finalSize, weight: weight.systemWeight)
        }
    }
}
