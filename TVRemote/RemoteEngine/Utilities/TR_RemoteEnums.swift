//
//  Enums.swift
//  TR_TV Remote
//
//  Created by iOS Developer on 25/08/2025.
//

import Foundation

enum TR_Tab: String, CaseIterable {
    case remote = "Remote"
    case apps = "Apps"
    case settings = "Settings"
}

enum TVRemoteAppRoute: Hashable {
    case splashView
    case FirstOnBoardingView
    case SecondOnBoardingView
    case FirstSubscriptionView
    case SecondSubscriptionView
    case mainTabView
    case searchingDevicesView(viewModel: TR_RemoteViewModel)
    case connectionGuideView
}

//enum TVType {
//    case ANDROID
//    case LG
//    case ROKU
//    case SAMSUNG
//    case FIRE
//}

//MARK: - GENERAL REMOTE KEYS
enum TR_RemoteKey {
    case POWER
    case VOLUMEUP
    case VOLUMEDOWN
    case CHANNELUP
    case CHANNELDOWN
    case HOME
    case BACK
    case OK
    case EXIT
    case MUTE
    case DPAD_UP
    case DPAD_DOWN
    case DPAD_LEFT
    case DPAD_RIGHT
    case PAUSE_PLAY
    
    case MENU
    case SETTINGS
    case STAR
    case RESTART
    case PAUSE
    case PLAY
    case INPUT_SOURCE
    case SEARCH
}


// MARK: - Fire Manager Enums
enum TR_FireTVKeys: String {
    case KEYCODE_DPAD_UP = "dpad_up"
    case KEYCODE_DPAD_DOWN = "dpad_down"
    case KEYCODE_DPAD_LEFT = "dpad_left"
    case KEYCODE_DPAD_RIGHT = "dpad_right"
    case KEYCODE_OK = "select"
    case KEYCODE_BACK = "back"
    case KEYCODE_PLAY = "play"
    case KEYCODE_PAUSE = "pause"
    case KEYCODE_MENU = "menu"
    case KEYCODE_HOME = "home"
    case KEYCODE_EXIT = "exit"
    case KEYCODE_POWER = "sleep"
    case KEYCODE_VOLUME_UP = "volume_up"
    case KEYCODE_VOLUME_DOWN = "volume_down"
    case KEYCODE_MUTE = "mute"
    case KEYCODE_BACKSPACE = "backspace"
}


// MARK: LG Manager Enums
enum TR_LGRemoteKeys {
    case KEYCODE_CHANNEL_UP, KEYCODE_CHANNEL_DOWN
    case KEYCODE_VOLUME_UP, KEYCODE_VOLUME_DOWN, KEYCODE_MUTE
    case KEYCODE_POWER
    case KEYCODE_DPAD_UP, KEYCODE_DPAD_DOWN, KEYCODE_DPAD_LEFT, KEYCODE_DPAD_RIGHT
    case KEYCODE_OK, KEYCODE_HOME, KEYCODE_BACK, KEYCODE_MENU
    case KEYCODE_PLAY, KEYCODE_PAUSE, KEYCODE_FAST_FORWARD, KEYCODE_REWIND, KEYCODE_STOP
    case KEYCODE_BACKSPACE
    case KEYCODE_SEARCH
}


// MARK: Roku Manager Enums
enum TR_RokuRemoteKeys: String {
    case KEYCODE_DPAD_LEFT = "LEFT"
    case KEYCODE_DPAD_RIGHT = "RIGHT"
    case KEYCODE_DPAD_UP = "UP"
    case KEYCODE_DPAD_DOWN = "DOWN"
    case KEYCODE_VOLUME_UP = "VOLUMEUP"
    case KEYCODE_VOLUME_DOWN = "VOLUMEDOWN"
    case KEYCODE_MUTE = "VOLUMEMUTE"
    case KEYCODE_POWER = "POWER"
    case KEYCODE_HOME = "HOME"
    case KEYCODE_BACK = "BACK"
    case KEYCODE_OK = "SELECT"
    case KEYCODE_STAR = "INFO"
    case KEYCODE_REPLAY = "INSTANTREPLAY"
    case KEYCODE_PLAY = "PLAY"
    case KEYCODE_FARWARD = "FWD"
    case KEYCODE_REWIND = "REV"
    case KEYCODE_BACKSPACE = "BACKSPACE"
}

enum TR_HisenseRemoteKeys: String {
    case up = "KEY_UP"
    case down = "KEY_DOWN"
    case left = "KEY_LEFT"
    case right = "KEY_RIGHT"
    case select = "KEY_OK"
    case back = "KEY_RETURNS"
    case play = "KEY_PLAY"
    case pause = "KEY_PAUSE"
    case menu = "KEY_MENU"
    case home = "KEY_HOME"
    case exit = "KEY_EXIT"
    case power = "KEY_POWER"
    case volumeUp = "KEY_VOLUMEUP"
    case volumeDown = "KEY_VOLUMEDOWN"
    case mute = "KEY_MUTE"
    case backspace = "BACKSPACE"
    case next = "KEY_FORWARDS"
    case previous = "KEY_BACK"
    case stop = "KEY_STOP"
    case input = "KEY_INPUT"
    case channelUp = "KEY_CHANNELUP"
    case channelDown = "KEY_CHANNELDOWN"
    
    case KEYCODE_0 = "KEY_0"
    case KEYCODE_1 = "KEY_1"
    case KEYCODE_2 = "KEY_2"
    case KEYCODE_3 = "KEY_3"
    case KEYCODE_4 = "KEY_4"
    case KEYCODE_5 = "KEY_5"
    case KEYCODE_6 = "KEY_6"
    case KEYCODE_7 = "KEY_7"
    case KEYCODE_8 = "KEY_8"
    case KEYCODE_9 = "KEY_9"
    
    case KEYCODE_B = "KEY_BLUE"
    case KEYCODE_C = "KEY_GREEN"
    case KEYCODE_A = "KEY_RED"
    case KEYCODE_D = "KEY_YELLOW"
}

enum TR_TVApps: String, CaseIterable, Identifiable {
    var id: String { self.rawValue }
    
    case youtube = "youtube"
    case netflix = "netflix"
    case prime = "prime"
    case spotify = "spotify"
    case disney = "disney"
    case paramount = "paramount"
    case eSPN = "espn"
    case hulu = "hulu"
    case peacock = "peacock"
    
    var deepLinkURL: String {
        switch self {
        case .youtube: return "https://www.youtube.com/"
        case .netflix: return "https://www.netflix.com/title"
        case .prime: return "https://www.primevideo.com/"
        case .spotify: return "https://open.spotify.com/"
        case .disney: return "https://www.disneyplus.com/"
        case .paramount: return "https://www.paramountplus.com/"
        case .eSPN: return "https://www.espn.com/watch/"
        case .hulu: return "https://play.google.com/store/apps/details?id=com.hulu.livingroomplus"
        case .peacock: return "https://www.peacocktv.com/"
        }
    }
    
    var fireTVAppId: String {
        switch self {
        case .youtube: return "com.amazon.firetv.youtube"
        case .netflix: return "com.netflix.ninja"
        case .prime: return "com.amazon.avod"
        case .spotify: return "com.spotify.tv.android"
        case .disney: return "com.disney.disneyplus"
        case .paramount: return "com.cbs.app"
        case .eSPN: return "com.espn.score_center"
        case .hulu: return "com.hulu.livingroomplus"
        case .peacock: return "com.peacocktv.peacockandroid"
        }
    }
    
    var rokuAppId: String {
        switch self {
        case .youtube: return "837"
        case .netflix: return "12"
        case .prime: return ""
        case .spotify: return "22297"
        case .disney: return "291097"
        case .paramount: return "31440"
        case .eSPN: return "34376"
        case .hulu: return "2285"
        case .peacock: return "593099"
        }
    }
    
    func toSamsungApp() -> TR_TVApp {
        switch self {
        case .youtube: return .youtube()
        case .netflix: return .netflix()
        case .prime: return .primeVideo()
        case .spotify: return .spotify()
        case .disney: return .disnep()
        case .paramount: return .paramountPlus()
        case .eSPN: return .espn()
        case .hulu: return .hulu()
        case .peacock: return .peacock()
        }
    }
    
    var displayName: String {
        switch self {
        case .youtube: return "YouTube"
        case .netflix: return "Netflix"
        case .prime: return "Prime Video"
        case .spotify: return "Spotify"
        case .disney: return "Disney+"
        case .paramount: return "Paramount+"
        case .eSPN: return "ESPN"
        case .hulu: return "Hulu"
        case .peacock: return "Peacock"
        }
    }
    
    var image: String {
        switch self {
        case .youtube: return "Youtube"
        case .netflix: return "Netflix"
        case .prime: return "Prime Video"
        case .spotify: return "Spotify"
        case .disney: return "JioHotstar"
        case .paramount: return "Paramount"
        case .eSPN: return "ESPN"
        case .hulu: return "Hulu"
        case .peacock: return "Peacock"
        }
    }
}

enum TR_LGTVApps {
    case lgChannels
    case netflix
    case prime
    case disney
    case appleTV
    case zeeFive
    case youtube
    case lgGamingPortal
    case apps
    case homeOffice
    case music
    case homeHub
    case learning
    case webBrowser
    case mediaPlayer
    
    var image: String {
        switch self {
        case .lgChannels: return "LG Channels"
        case .netflix: return "Netflix"
        case .prime: return "Prime Video"
        case .disney: return "JioHotstar"
        case .appleTV: return "Apple TR_TV"
        case .zeeFive: return "ZEE5"
        case .youtube: return "Youtube"
        case .lgGamingPortal: return "LG Gaming Portal"
        case .apps: return "Apps"
        case .homeOffice: return "Home Office"
        case .music: return "Music"
        case .homeHub: return "Home Hub"
        case .learning: return "Learning"
        case .webBrowser: return "Web Browser"
        case .mediaPlayer: return "Media Player"
        }
    }
    
    var name: String {
        switch self {
        case .lgChannels: return "LG Channels"
        case .netflix: return "Netflix"
        case .prime: return "Amazon Prime"
        case .disney: return "Jio Hotstar"
        case .appleTV: return "Apple TR_TV"
        case .zeeFive: return "Zee 5"
        case .youtube: return "YouTube"
        case .lgGamingPortal: return "Gaming Portal"
        case .apps: return "Apps"
        case .homeOffice: return "Home Office"
        case .music: return "Music"
        case .homeHub: return "Home Hub"
        case .learning: return "Learning"
        case .webBrowser: return "Browser"
        case .mediaPlayer: return "Media Player"
        }
    }
    
    var launchID: String {
        switch self {
        case .lgChannels: return "com.webos.app.lgchannels"
        case .netflix: return "netflix"
        case .prime: return "amazon"
        case .disney: return "hotstar"
        case .appleTV: return "com.apple.appletv"
        case .zeeFive: return "com.zee5.app"
        case .youtube: return "youtube.leanback.v4"
        case .lgGamingPortal: return "com.twin.app.gamingportal"
        case .apps: return "com.webos.app.discovery"
        case .homeOffice: return "com.webos.app.homeoffice"
        case .music: return "com.webos.app.totalmusic"
        case .homeHub: return "com.webos.app.homeconnect"
        case .learning: return "com.webos.app.learning"
        case .webBrowser: return "com.webos.app.browser"
        case .mediaPlayer: return "com.webos.app.mediadiscovery"
        }
    }
}
