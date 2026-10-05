//
//  AnalyticsEvent.swift
//  TV Remote
//
//  Created by iOS Developer on 15/09/2026.
//

import Foundation
import FirebaseCore
import FirebaseAnalytics

enum TR_AnalyticEvent: String {
    case Intro
    case Home
    case Settings
    case Language
    case Privacy
    case AboutUs
    case Terms
    case Eula
    case Premium
    case PhotoListing
    case PhotoCasting
    case videoListing
    case videoCasting
    case MusicListing
    case FavMusicListing
    case MusicCasting
    case FilesListing
    case MixFilesListing
    case FilesPageListing
    case FilesPageCasting
    case Browser
    case BrowserCasting
    case YoutubeCasting
    case Camera
    case Recording
    case RecordingHistory
    case IPTVCatCountryListing
    case IPTVChannelListing
    case IPTVCasting
    case OnlineImageListing
    case OnlineImageCasting
    case StartDrawing
    case Drawing
    case DrawingHistory
    case remoteControl
    case Mirror
}

func logAnalyticView(title: String, Screen: String) {
    Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: title, AnalyticsParameterScreenClass: Screen])
}

func logAnalyticAction(title: String, status: TR_AnalyticEvent) {
    Analytics.logEvent(status.rawValue, parameters: ["name": title, "status": status.rawValue])
}

func logAnalyticActionWithParams(_ name: TR_AnalyticEvent, parameters: [String : Any]?) {
    Analytics.logEvent(name.rawValue, parameters: parameters)
}
