//
//  InputSourceSheetView.swift
//  TV Remote
//

import SwiftUI
import ConnectSDK

enum TVInputSource: String, CaseIterable, Identifiable {
    case hdmi1 = "HDMI 1"
    case hdmi2 = "HDMI 2"
    case hdmi3 = "HDMI 3"
    case av1 = "AV 1"
    case av2 = "AV 2"
    case av3 = "AV 3"
    
    var id: String { rawValue }
    
    var isAV: Bool {
        self == .av1 || self == .av2 || self == .av3
    }
    
    var displayLabel: String {
        switch self {
        case .hdmi1: return "HDMI 1"
        case .hdmi2: return "HDMI 2"
        case .hdmi3: return "HDMI 3"
        case .av1, .av2, .av3: return "AV"
        }
    }
}

struct InputSourceSheetView: View {
    @ObservedObject var languageManager = TR_LanguageManager.shared
    @Binding var selectedSource: TVInputSource
    var onDismiss: () -> Void
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { UIDevice.isIPad || horizontalSizeClass == .regular }
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Indicator
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 38, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 14)
            
            // Header: Title & Subtitle + Close Button
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(languageManager.localized("inputs"))
                        .font(.inter(.bold, size: isIPad ? 22 : 19, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "111827"))
                    
                    Text(languageManager.localized("select_input_source"))
                        .font(.inter(.medium, size: isIPad ? 14 : 12.5, autoScaleForPad: false))
                        .foregroundColor(Color(hex: "6B7280"))
                }
                
                Spacer()
                
                Button(action: {
                    triggerHaptic()
                    onDismiss()
                }) {
                    Circle()
                        .fill(Color.white.opacity(0.65))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "4B5563"))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            
            // 3x2 Grid of Inputs
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(TVInputSource.allCases) { source in
                    sourceCard(source: source)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, isIPad ? 32 : 28)
        }
        .frame(maxWidth: isIPad ? 480 : .infinity)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color.white.opacity(0.35))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .clipShape(CustomRoundedCorners(radius: 32, corners: [.topLeft, .topRight]))
        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: -6)
    }
    
    @ViewBuilder
    private func sourceCard(source: TVInputSource) -> some View {
        let isSelected: Bool = selectedSource == source
        let cardHeight: CGFloat = isIPad ? 104 : 94
        
        Button(action: {
            triggerHaptic()
            selectedSource = source
            switchPortOnTV(source)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                onDismiss()
            }
        }) {
            VStack(spacing: 8) {
                if source.isAV {
                    if let _ = UIImage(named: "ic_AV") {
                        Image("ic_AV")
                            .renderingMode(isSelected ? .template : .original)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 26)
                            .foregroundColor(isSelected ? .white : Color(hex: "111827"))
                    } else {
                        Image(systemName: "cable.connector")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(isSelected ? .white : Color(hex: "111827"))
                    }
                } else {
                    if isSelected, let _ = UIImage(named: "ic_HDMI_Selected") {
                        Image("ic_HDMI_Selected")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 26)
                    } else if let _ = UIImage(named: "ic_HDMI") {
                        Image("ic_HDMI")
                            .renderingMode(isSelected ? .template : .original)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 26)
                            .foregroundColor(isSelected ? .white : Color(hex: "111827"))
                    } else {
                        Image(systemName: "tv.and.mediabox")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(isSelected ? .white : Color(hex: "111827"))
                    }
                }
                
                Text(source.displayLabel)
                    .font(.inter(.bold, size: isIPad ? 14 : 13, autoScaleForPad: false))
                    .foregroundColor(isSelected ? .white : Color(hex: "111827"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight)
            .background(
                Group {
                    if isSelected {
                        TR_Theme.activeCircleGradient
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.55))
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: isSelected ?
                                [Color.white.opacity(0.9), Color.white.opacity(0.4)] :
                                [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .shadow(
                color: isSelected ? TR_Theme.primaryPink.opacity(0.35) : Color.black.opacity(0.04),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: isSelected ? 3 : 2
            )
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94))
    }
    
    private func switchPortOnTV(_ source: TVInputSource) {
        let remoteVM = TR_RemoteViewModel.shared
        if DeviceConnectionManager.shared.isMirroringActive || UIScreen.main.isCaptured || (UserDefaults(suiteName: TR_AppStrings.groupID)?.bool(forKey: "isBroadcasting") == true) {
            print("⚠️ Port switch ignored because TV Remote is active.")
            return
        }
        if remoteVM.connectedTVType == .ANDROID {
            remoteVM.switchToAndroidPort(source)
        } else if remoteVM.connectedTVType == .LG {
            let portName = source.rawValue.lowercased()
            if let matchingPort = remoteVM.lgPorts.first(where: { ($0.name ?? "").lowercased().contains(portName) || ($0.id ?? "").lowercased().contains(portName) }) {
                remoteVM.switchToLGPort(matchingPort)
            } else if let firstPort = remoteVM.lgPorts.first {
                remoteVM.switchToLGPort(firstPort)
            }
        } else if remoteVM.connectedTVType == .SAMSUNG {
            let portName = source.rawValue.lowercased()
            if let matchingPort = remoteVM.samsungPorts.first(where: { $0.name.lowercased().contains(portName) || $0.id.lowercased().contains(portName) }) {
                remoteVM.switchToSamsungPort(matchingPort)
            } else if let firstPort = remoteVM.samsungPorts.first {
                remoteVM.switchToSamsungPort(firstPort)
            }
        }
    }
    
    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
