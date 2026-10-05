//
//  TR_QuickGuideView.swift
//  TV Remote
//

import SwiftUI

// MARK: - Models for Voice Commands Guide
struct TR_VoiceCommandApp: Identifiable {
    let id: String
    let name: String
    let phrases: [String]
    
    init(name: String, phrases: [String]) {
        self.id = name
        self.name = name
        self.phrases = phrases
    }
}

struct TR_VoiceCommandSection: Identifiable {
    let id: String
    let title: String
    let iconName: String
    let items: [TR_VoiceCommandApp]
    
    init(title: String, iconName: String, items: [TR_VoiceCommandApp]) {
        self.id = title
        self.title = title
        self.iconName = iconName
        self.items = items
    }
}

// MARK: - Voice TR_Command Guide Data Provider
enum TR_VoiceCommandGuide {
    
    // MARK: - 🎬 Applications (Universal + TR_TV-specific)
    static func applications(for tvType: TR_TelevisionType?) -> [TR_VoiceCommandApp] {
        var apps: [TR_VoiceCommandApp] = [
            TR_VoiceCommandApp(
                name: "YouTube",
                phrases: ["youtube", "you tube", "utube", "open youtube", "launch youtube", "start youtube", "go to youtube"]
            ),
            TR_VoiceCommandApp(
                name: "Netflix",
                phrases: ["netflix", "net flix", "open netflix", "launch netflix", "start netflix", "go to netflix"]
            ),
            TR_VoiceCommandApp(
                name: "Prime Video",
                phrases: ["prime video", "prime", "amazon prime", "amazon", "open prime", "launch prime video", "open amazon prime"]
            ),
            TR_VoiceCommandApp(
                name: "Spotify",
                phrases: ["spotify", "open spotify", "launch spotify", "play spotify", "start spotify"]
            )
        ]
        
        switch tvType {
        case .SAMSUNG:
            apps.append(contentsOf: [
                TR_VoiceCommandApp(
                    name: "Browser",
                    phrases: ["browser", "internet browser", "explorer", "internet explorer", "web browser", "open browser", "launch browser", "open internet"]
                ),
                TR_VoiceCommandApp(
                    name: "Apple TV",
                    phrases: ["apple tv", "open apple tv", "launch apple tv", "apple tv app"]
                ),
                TR_VoiceCommandApp(
                    name: "Samsung TV Plus",
                    phrases: ["samsung tv plus", "tv plus", "live tv", "channel guide", "tv channels", "open tv plus", "samsung channels"]
                )
            ])
            
        case .LG:
            apps.append(contentsOf: [
                TR_VoiceCommandApp(
                    name: "LG Channels",
                    phrases: ["lg channels", "channels", "channel guide", "live channels", "open channels"]
                ),
                TR_VoiceCommandApp(
                    name: "Disney+ Hotstar",
                    phrases: ["disney", "disney plus", "hotstar", "disney plus hotstar", "jio hotstar", "open disney plus"]
                ),
                TR_VoiceCommandApp(
                    name: "Apple TV",
                    phrases: ["apple tv", "open apple tv", "launch apple tv", "apple tv app"]
                ),
                TR_VoiceCommandApp(
                    name: "Zee5",
                    phrases: ["zee5", "zee", "zee five", "open zee5", "zeefive"]
                ),
                TR_VoiceCommandApp(
                    name: "Gaming Portal",
                    phrases: ["lg gaming portal", "gaming portal", "game portal", "games", "open gaming portal", "lggamingportal"]
                ),
                TR_VoiceCommandApp(
                    name: "Apps",
                    phrases: ["apps menu", "open apps", "show all apps", "app store", "all apps", "apps list"]
                ),
                TR_VoiceCommandApp(
                    name: "Home Office",
                    phrases: ["home office", "office mode", "open home office", "office app"]
                ),
                TR_VoiceCommandApp(
                    name: "Music",
                    phrases: ["lg music", "music app", "open lg music", "music"]
                ),
                TR_VoiceCommandApp(
                    name: "Home Hub",
                    phrases: ["home hub", "smart hub", "open home hub"]
                ),
                TR_VoiceCommandApp(
                    name: "Learning",
                    phrases: ["learning", "education", "learn", "learning app", "open learning"]
                ),
                TR_VoiceCommandApp(
                    name: "Browser",
                    phrases: ["browser", "internet browser", "explorer", "internet explorer", "web browser", "open browser"]
                ),
                TR_VoiceCommandApp(
                    name: "Media Player",
                    phrases: ["media player", "media", "player", "open media player", "local media"]
                )
            ])
            
        default:
            apps.append(contentsOf: [
                TR_VoiceCommandApp(
                    name: "Disney+ Hotstar",
                    phrases: ["disney", "disney plus", "hotstar", "disney plus hotstar", "jio hotstar", "open disney plus"]
                ),
                TR_VoiceCommandApp(
                    name: "Apple TV",
                    phrases: ["apple tv", "open apple tv", "launch apple tv", "apple tv app"]
                ),
                TR_VoiceCommandApp(
                    name: "Browser",
                    phrases: ["browser", "internet browser", "web browser", "open browser"]
                )
            ])
        }
        
        return apps
    }
    
    // MARK: - 🎮 Remote / Navigation Commands
    static let remoteCommands: [TR_VoiceCommandApp] = [
        TR_VoiceCommandApp(
            name: "Volume Up",
            phrases: [
                "volume up", "increase volume", "louder", "raise volume",
                "turn up the volume", "turn it up", "volume plus", "make it louder",
                "sound up", "increase the volume", "boost volume", "raise the volume",
                "turn volume up", "up the volume", "more volume", "higher volume"
            ]
        ),
        TR_VoiceCommandApp(
            name: "Volume Down",
            phrases: [
                "volume down", "decrease volume", "lower volume", "quieter",
                "turn down the volume", "turn it down", "volume minus", "make it quieter",
                "sound down", "decrease the volume", "reduce volume", "lower the volume",
                "turn volume down", "down the volume", "less volume", "softer", "turn it low"
            ]
        ),
        TR_VoiceCommandApp(
            name: "Mute",
            phrases: [
                "mute", "silence", "mute it", "turn off sound", "turn off the volume",
                "no sound", "silence it", "stop the sound", "volume off",
                "mute the tv", "quiet please", "shut off the sound"
            ]
        ),
        TR_VoiceCommandApp(
            name: "Home",
            phrases: [
                "home", "go home", "exit", "home screen", "go to home",
                "main menu", "take me home", "go to main menu", "home button", "return home"
            ]
        ),
        TR_VoiceCommandApp(
            name: "Back",
            phrases: [
                "back", "go back", "previous", "go to previous",
                "take me back", "return", "undo", "previous screen", "step back"
            ]
        ),
        TR_VoiceCommandApp(
            name: "Navigate Up",
            phrases: ["up", "move up", "go up", "scroll up", "navigate up", "up arrow"]
        ),
        TR_VoiceCommandApp(
            name: "Navigate Down",
            phrases: ["down", "move down", "go down", "scroll down", "navigate down", "down arrow"]
        ),
        TR_VoiceCommandApp(
            name: "Navigate Left",
            phrases: ["left", "move left", "go left", "navigate left", "left arrow"]
        ),
        TR_VoiceCommandApp(
            name: "Navigate Right",
            phrases: ["right", "move right", "go right", "navigate right", "right arrow"]
        ),
        TR_VoiceCommandApp(
            name: "OK / Select",
            phrases: [
                "ok", "select", "confirm", "enter", "choose", "click", "tap",
                "press ok", "go ahead", "pick this", "select it"
            ]
        ),
        TR_VoiceCommandApp(
            name: "Play",
            phrases: [
                "play", "resume", "start playing", "continue playing",
                "unpause", "let it play", "start the video", "play it", "continue"
            ]
        ),
        TR_VoiceCommandApp(
            name: "Pause",
            phrases: [
                "pause", "stop", "hold on", "pause it", "stop it",
                "freeze", "wait", "pause the video", "stop playing"
            ]
        ),
        TR_VoiceCommandApp(
            name: "Settings",
            phrases: [
                "settings", "setting", "open settings", "go to settings",
                "show settings", "menu settings", "tv settings", "options",
                "preferences", "configuration", "setup menu", "open menu settings"
            ]
        ),
        TR_VoiceCommandApp(
            name: "Power",
            phrases: [
                "power", "power off", "power on", "turn off", "turn on",
                "shut down", "switch off", "switch on", "turn off the tv",
                "turn on the tv", "power button", "restart tv", "power the tv",
                "kill the tv", "shut the tv off"
            ]
        ),
        TR_VoiceCommandApp(
            name: "TR_Channel Up",
            phrases: [
                "channel up", "next channel", "channel plus", "go to next channel",
                "increase channel", "channel forward", "flip channel up",
                "change channel up", "up channel", "skip channel"
            ]
        ),
        TR_VoiceCommandApp(
            name: "TR_Channel Down",
            phrases: [
                "channel down", "previous channel", "channel minus", "go to previous channel",
                "decrease channel", "channel backward", "flip channel down",
                "change channel down", "down channel", "back channel"
            ]
        )
    ]
    
    // MARK: - Full sections (for sheet consumption)
    static func allSections(for tvType: TR_TelevisionType?) -> [TR_VoiceCommandSection] {
        [
            TR_VoiceCommandSection(title: "Applications", iconName: "square.grid.2x2.fill", items: applications(for: tvType)),
            TR_VoiceCommandSection(title: "Remote Commands", iconName: "slider.horizontal.3", items: remoteCommands)
        ]
    }
}

// MARK: - Quick Guide View Sheet & Navigation View
struct TR_QuickGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var languageManager = TR_LanguageManager.shared
    let tvType: TR_TelevisionType?
    var onBack: (() -> Void)? = nil
    
    @State private var expandedSectionIDs: Set<String> = []
    @State private var expandedAppIDs: Set<String> = []
    
    private var sections: [TR_VoiceCommandSection] {
        TR_VoiceCommandGuide.allSections(for: tvType)
    }
    
    private var brandGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "8E03A1"), Color(hex: "E25F89")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // TOP HEADER BAR (Centered Title & Subtitle with Left Back Button)
            ZStack {
                HStack {
                    GlassBackButton {
                        if let onBack = onBack {
                            onBack()
                        } else {
                            dismiss()
                        }
                    }
                    Spacer()
                }
                
                VStack(spacing: 2) {
                    Text(languageManager.localized("quick_guide"))
                        .font(.inter(.bold, size: 18))
                        .foregroundColor(TR_Theme.textPrimary)
                        .lineLimit(1)
                    
                    Text(languageManager.localized("quick_guide_subtitle"))
                        .font(.inter(.regular, size: 11.5))
                        .foregroundColor(Color(hex: "6B7280"))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.80)
                }
                .padding(.horizontal, 48)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 16)
            
            // Sections List
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    ForEach(sections) { section in
                        sectionView(section)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, onBack != nil ? 40 : 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            Image("BG")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        )
        .enableNativeSwipeBack()
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .sheetCornerRadius(28)
        .onAppear {
            if let first = sections.first {
                expandedSectionIDs.insert(first.id)
            }
        }
    }
    
    // MARK: - Master Section View (Applications / Remote Commands)
    private func sectionView(_ section: TR_VoiceCommandSection) -> some View {
        let isExpanded = expandedSectionIDs.contains(section.id)
        
        return VStack(spacing: 0) {
            Button(action: {
                triggerHaptic()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    if isExpanded {
                        expandedSectionIDs.remove(section.id)
                    } else {
                        expandedSectionIDs.insert(section.id)
                    }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: section.iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(brandGradient)
                        .frame(width: 24)
                    
                    Text(section.title)
                        .font(.inter(.semiBold, size: 16))
                        .foregroundColor(TR_Theme.textPrimary)
                    
                    Spacer()
                    
                    toggleIcon(isExpanded: isExpanded)
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 10) {
                    ForEach(section.items) { item in
                        appRow(item)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glassCard(cornerRadius: 20, isInteractive: false)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Individual App / TR_Command Row
    @ViewBuilder
    private func appRow(_ app: TR_VoiceCommandApp) -> some View {
        let isExpanded = expandedAppIDs.contains(app.id)
        
        VStack(spacing: 0) {
            Button(action: {
                triggerHaptic()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    if isExpanded {
                        expandedAppIDs.remove(app.id)
                    } else {
                        expandedAppIDs.insert(app.id)
                    }
                }
            }) {
                HStack {
                    Text(app.name)
                        .font(.inter(.medium, size: 15))
                        .foregroundColor(TR_Theme.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "6B7280"))
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(app.phrases, id: \.self) { phrase in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(brandGradient)
                                .frame(width: 5, height: 5)
                            
                            Text("\"\(phrase)\"")
                                .font(.inter(.regular, size: 13))
                                .foregroundColor(Color(hex: "374151"))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.40))
        )
        .glassModifier(cornerRadius: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
    }
    
    // MARK: - Section Plus/Minus Toggle Icon
    @ViewBuilder
    private func toggleIcon(isExpanded: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isExpanded ? AnyShapeStyle(brandGradient) : AnyShapeStyle(Color.white.opacity(0.60)))
                .frame(width: 26, height: 26)
            
            Image(systemName: isExpanded ? "minus" : "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isExpanded ? .white : TR_Theme.textPrimary)
        }
    }
    
    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Xcode Preview
struct QuickGuideView_Previews: PreviewProvider {
    static var previews: some View {
        TR_QuickGuideView(tvType: .SAMSUNG)
    }
}

// MARK: - Sheet Helper Extension
private extension View {
    @ViewBuilder
    func sheetCornerRadius(_ radius: CGFloat) -> some View {
        if #available(iOS 16.4, *) {
            self.presentationCornerRadius(radius)
        } else {
            self
        }
    }
}
