//
//  Constant.swift
//  TV Remote
//

import Foundation
import UIKit
import SwiftUI

#if DEBUG
let AppId = 6756773198
#else
let AppId = 6781641021
#endif

let REVIEW_LINK = "https://apps.apple.com/app/id\(AppId)?action=write-review"
let APPURL = "https://apps.apple.com/app/id\(AppId)"
let PRIVACYPOLICY = "https://jenniferpinto58.blogspot.com/2026/07/privacy-policy.html"
let TEARMS = "https://jenniferpinto58.blogspot.com/2026/07/terms-conditions.html"
let EULA = "https://jenniferpinto58.blogspot.com/2026/07/eula.html"

// In-App Purchase identifiers
var iapLifetime = ""
var iapYearlyPlan = ""
var iapMonthlyPlan = ""
var iapWeeklyPlan = ""

var isShowPremium = ""
var second_native = ""
var second_appopen = ""
var small_native = ""
var second_small_native = ""
var pro_close_inter = ""
var smallNativeAd = ""

var weatherAPIKey = ""
var isYoutubeEnabled = ""
var isIPTVEnabled = ""
var freeLimitCount = ""
var cat_api = ""
var cat_Identifier = ""
var androidBannerUrl = "https://7seasol-application.s3.ap-south-1.amazonaws.com/Smart+View/TV+Banner+Natasha.png"

var bannerId = "ca-app-pub-3940256099942544/2934735716"
var nativeId = "ca-app-pub-3940256099942544/3986624511"
var interstialId = "ca-app-pub-3940256099942544/4411468910"
var rewardId = ""
var appopenId = "ca-app-pub-3940256099942544/5575463023"
var addButtonColor = "#007AFF"
var adsCount = 4
var adsPlus = 1
var smallNativeBannerId = ""

#if DEBUG
// Test URL
let getJSON : String = "https://7seasol-application.s3.amazonaws.com/admin_prod/pbz-grfgvat-arj.json"
#else
// Live URL
let getJSON : String = "https://7seasol-application.s3.amazonaws.com/admin_prod/pbz-pber-gbby.json"
#endif

public let ACCESS = "AKIA2FCATE7MLGSZBHML"
public let SECRET = "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"

func isIpad() -> Bool {
    UIDevice.current.userInterfaceIdiom == .pad
}
