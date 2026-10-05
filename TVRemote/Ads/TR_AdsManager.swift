//
//  TR_AdsManager.swift
//  CineBuzz
//
//  Created by Parthiv Akbari on 23/07/25.
//

import Foundation
import UIKit
import GoogleMobileAds
import AppTrackingTransparency
import AdSupport
import SystemConfiguration
import UserMessagingPlatform

protocol TR_AdsManagerDelegate {
    func NativeAdLoad()
    func DidDismissFullScreenContent()
    func NativeAdsDidFailedToLoad()
}

var interstitialAd: InterstitialAd?
var interstitialAd2: InterstitialAd?
var isNativeLoad : Bool = false

var NATIVE_ADS:NativeAd?
var isAdsLoadFailed = Bool()


class TR_AdsManager: NSObject {
    
    
    
    class func isConnectedToNetwork() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        var flags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
            return false
        }
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        return (isReachable && !needsConnection)
    }
    
    static let shared = TR_AdsManager()
    var delegate: TR_AdsManagerDelegate?

    var adLoader: AdLoader!
    var arrNativeAds = [NativeAd]()

    var appOpenAd :AppOpenAd?
    var loadTime = Date()

    var isMobileAdsStartCalled = Bool()
    var interAdVisible = false
    
    //MARK:- TOP VIEW CONTROLLER

    var topMostViewController: UIViewController? {
        var currentVc = UIApplication.shared.keyWindow?.rootViewController
        while let presentedVc = currentVc?.presentedViewController {
            if let navVc = (presentedVc as? UINavigationController)?.viewControllers.last {
                currentVc = navVc
            } else if let tabVc = (presentedVc as? UITabBarController)?.selectedViewController {
                currentVc = tabVc
            } else {
                currentVc = presentedVc
            }
        }
        return currentVc
    }

    //MARK: - App Tracking

//    func requestIDFA() {
//      if #available(iOS 14, *) {
//        ATTrackingManager.requestTrackingAuthorization(completionHandler: { status in
//
//        })
//      } else {
//      }
//    }

    //MARK: - Request For Content Form
    
    func requestForConsentForms(){
        // Create a UMPRequestParameters object.
        let parameters = RequestParameters()
        // Set tag for under age of consent. false means users are not under age
        // of consent.
//        parameters.tagForUnderAgeOfConsent = false
        let debugSettings = DebugSettings()
        debugSettings.geography = DebugGeography.EEA
        parameters.debugSettings = debugSettings
        // Request an update for the consent information.
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) {
            [weak self] requestConsentError in
            guard let self else { return }
            
            if let consentError = requestConsentError {
                // Consent gathering failed.
                return print("Error: \(consentError.localizedDescription)")
            }
            let rootController = UIApplication.shared.keyWindow?.rootViewController //appDelegate.window?.rootViewController

            ConsentForm.loadAndPresentIfRequired(from: rootController ?? UIViewController()) {
                [weak self] loadAndPresentError in
                guard let self else { return }
                
                if let consentError = loadAndPresentError {
                    // Consent gathering failed.
                    return print("Error: \(consentError.localizedDescription)")
                }
                
                // Consent has been gathered.
                if ConsentInformation.shared.canRequestAds {
                    self.startGoogleMobileAdsSDK()
                }
            }
        }
        
        // Check if you can initialize the Google Mobile Ads SDK in parallel
        // while checking for new consent information. Consent obtained in
        // the previous session can be used to request ads.
        if ConsentInformation.shared.canRequestAds {
            startGoogleMobileAdsSDK()
        }
    }
    
//    private func startGoogleMobileAdsSDK() {
//        DispatchQueue.main.async {
//            guard !self.isMobileAdsStartCalled else { return }
//            
//            self.isMobileAdsStartCalled = true
//            
//            // Initialize the Google Mobile Ads SDK.
//            GADMobileAds.sharedInstance().start()
//            
//            if Subscribe.get() == false {
//                showInterAdClick()
//                TR_AdsManager.shared.requestAppOpenAd()
//                TR_AppOpenAdManager.shared.loadAd()
//             }
//        }
//    }
    
    func requestForConsentForm(completion: @escaping (Bool) -> Void) {
           // Create a UMPRequestParameters object.
        let parameters = RequestParameters()
           // Set tag for under age of consent. false means users are not under age
           // of consent.
           // parameters.tagForUnderAgeOfConsent = false
        let debugSettings = DebugSettings()
        debugSettings.geography = DebugGeography.EEA
           parameters.debugSettings = debugSettings
           // Request an update for the consent information.
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] requestConsentError in
               guard let self = self else { return }

               if let consentError = requestConsentError {
                   // Consent gathering failed.
                   print("Error: \(consentError.localizedDescription)")
                   completion(false) // Consent not granted due to error
                   return
               }
               
//               if let sceneDelegate = UIApplication.shared.delegate as? AppDelegate,
//                   let rootController = sceneDelegate.window?.rootViewController {
                   // Use rootController here
                   let rootController = UIApplication.shared.keyWindow?.rootViewController
                   ConsentForm.loadAndPresentIfRequired(from: rootController) { [weak self] loadAndPresentError in
                       guard let self = self else { return }

                       if let consentError = loadAndPresentError {
                           // Consent gathering failed.
                           print("Error: \(consentError.localizedDescription)")
                           completion(false) // Consent not granted
                           return
                       }

                       // Consent has been gathered.
                       if ConsentInformation.shared.consentStatus == ConsentStatus.obtained {
                           completion(true) // Consent granted
                       } else {
                           completion(false) // Consent not granted
                       }
                   }
//               }

           //    let rootController = UIApplication.shared.keyWindow?.rootViewController
              

           }

           // the previous session can be used to request ads.
        if ConsentInformation.shared.canRequestAds {
               startGoogleMobileAdsSDK()
           }
       }
    
    private func startGoogleMobileAdsSDK() {
        DispatchQueue.main.async {
            guard !self.isMobileAdsStartCalled else { return }
            
            self.isMobileAdsStartCalled = true
            
            // Initialize the Google Mobile Ads SDK.
            MobileAds.shared.start()
            
//            if Subscribe.get() == false {
//                showInterAdClick()
//                Task {
//                    await TR_AppOpenAdManager.shared.loadAd()
//                }
//            }
        }
    }

    //MARK: - LOAD INTERSTITIAL ADS
//    func loadInterstitialAd(){
//
//        if !TR_AdsManager.isConnectedToNetwork() && Subscribe.get() {
//            return
//        }
//        if interstitialAd == nil {
//            let request = Request()
//            InterstitialAd.load(with: interstialId, request: request) { [self] (ad, error) in
//                if let error = error {
//                    isAdsLoadFailed = true
////                    interFaild = true
////                    loadInterstitialAd()
//                    if closeInter == true {
//                        closeInter = false
////                        NotificationCenter.default.post(name: .closeInter, object: nil)
//                    }
//                    print("Interstitial load error \(error.localizedDescription ?? "")")
//                } else {
//                    print("Interstitial load")
//                    interstitialAd = ad
//                    interstitialAd?.fullScreenContentDelegate = self
//                    isAdsLoadFailed = false
//                }
//            }
//        }
//
//    }
    
//    func loadInterstitialAd() {
//
//        if interstitialAd == nil {
//
//          //  print("inter load nill")
//        let request = GADRequest()
//        GADInterstitialAd.load(
//            withAdUnitID: interstialId, request: request
//        ) { (ad, error) in
//            if let error = error {
//                interstitialAd = nil
//                //print("Failed to load interstitial ad with error: \(error.localizedDescription)")
//
//                return
//            }
//            interstitialAd = ad
//            interstitialAd?.fullScreenContentDelegate = self
//
//          }
//        } else {
//           // print("inter load not nill")
//        }
//
//    }
   

    //MARK: - LOAD NATIVE ADS

//    func createAndLoadNativeAds(numberOfAds: Int) {
//
//        if !TR_AdsManager.isConnectedToNetwork() && Subscribe.get(){
//            return
//        }
//        arrNativeAds.removeAll()
//        let multipleAdsOptions = MultipleAdsAdLoaderOptions()
//        multipleAdsOptions.numberOfAds = numberOfAds
//
//        adLoader = AdLoader(adUnitID: nativeId, rootViewController: topMostViewController,
//                            adTypes: [AdLoaderAdType.native],
//                               options: [multipleAdsOptions])
//        adLoader.delegate = self
//        adLoader.load(Request())
//    }
    
    

    //MARK: - LOAD APP OPEN ADS

//    func tryToPresentAppOpenAd() {
//        if Subscribe.get(){
//            return
//        }
//        let ad = appOpenAd
////        appOpenAd = nil
//
//        if let ad = ad {
//            if let rootController = getTopViewController(){
//                ad.present(from: rootController)
//            }
//            
//            requestAppOpenAd()
//        } else {
//             requestAppOpenAd()
//        }
//    }

//    func requestAppOpenAd() {
//        if Subscribe.get(){
//            return
//        }
////        appOpenAd = nil
//        AppOpenAd.load(
//            with:  appopenId,
//            request: Request(),
//            completionHandler: { [self] appOpenAd, error in
//                if let error = error {
//                    isAdsLoadFailed = true
//                    requestAppOpenAd()
//                  //  print("Failed to load app open ad: \(error)")
//                    return
//                }
//                isAdsLoadFailed = false
//                self.appOpenAd = appOpenAd
//                self.appOpenAd?.fullScreenContentDelegate = self
//                self.loadTime = Date()
//            })
//    }

    //MARK: - PRESENT (INTERSITITAL, NATIVE) ADS
    func showInterstitialAd (_ isLoader:Bool = false, isRandom:Bool = false, ratio:Int = 3,shouldMatchRandom : Int = 2){


        if interstitialAd != nil {
//            if isLoader {
//                SVProgressHUD.show(withStatus: "Loading Ads...")
//
//                SVProgressHUD.dismiss(withDelay: 0.5) {
//                    self.checkRandomAndPresentInterstitial(isRandom: isRandom, ratio: ratio, shouldMatchRandom: shouldMatchRandom)
//                }
//            }
//            else{
//                self.checkRandomAndPresentInterstitial(isRandom: isRandom, ratio: ratio, shouldMatchRandom: shouldMatchRandom)
//            }
            
            self.checkRandomAndPresentInterstitial(isRandom: isRandom, ratio: ratio, shouldMatchRandom: shouldMatchRandom)

        } else {
            //print("intersisital Ad wasn't ready")
        }


    }

    func checkRandomAndPresentInterstitial( isRandom:Bool, ratio:Int,shouldMatchRandom :Int){
        if isRandom{
            let isRandomMatch = Int.random(in: 1 ... ratio) == shouldMatchRandom
            if isRandomMatch {
                self.presentInterstitialAd()
            }
        }
        else {
            self.presentInterstitialAd()
        }
    }

    func presentInterstitialAd() {
//        if Subscribe.get(){
//            return
//        }
        DispatchQueue.main.async {
            if let rootController = getTopViewController(){
                interstitialAd?.present(from: rootController)
            }
        }
    }
    var adCompletionHandler: (() -> Void)?
    
//    func presentInterstitialAd2(vc: UIViewController, completion: (() -> Void)? = nil) {
//        if let ad = interstitialAd {
//            ad.fullScreenContentDelegate = self
//            adCompletionHandler = completion
//            isInterShow = true
//            ad.present(from: vc)
//            interAdVisible = true
//        }
//    }
//    
//    func presentInterstitialAd1(vc:UIViewController) {
//        if Subscribe.get() {
//            return
//        }
//        DispatchQueue.main.async {
//            if interstitialAd != nil {
//                isInterShow = true
//                interstitialAd!.present(from: vc)
//            } else {
//               // print("intersitial not load")
//            }
//        }
//    }
}


// MARK: - Interstitial Delegate
extension TR_AdsManager: FullScreenContentDelegate {

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
      //  print("Ad did fail to present full screen content.", error.localizedDescription)
//        interAdVisible = false
//        adsPlus = 0
//        isInterShow = false
//        isAdsLoadFailed = true
//        loadInterstitialAd()
    }

    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        self.delegate?.DidDismissFullScreenContent()
    }


//    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
//      //  print("Ad did dismiss full screen content.")
//        
//        interAdVisible = false
//        isInterShow = false
//        interstitialAd = nil
//        loadInterstitialAd()
//        if closeInter == true {
//            closeInter = false
////            NotificationCenter.default.post(name: .closeInter, object: nil)
//        }
//       
//    }
    
//    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
//        interAdVisible = false
//        isInterShow = false
//        interstitialAd = nil
//        loadInterstitialAd()
//        
//        if closeInter { closeInter = false }
//        // ✅ Call the stored completion if it exists
//            adCompletionHandler?()
//            adCompletionHandler = nil
////        if let topVC = getTopViewController() as? ContentDetailsVC {
////            print("🔄 Ad dismissed. Should play trailer: \(topVC.shouldPlayTrailerAfterAd)")
////            if topVC.shouldPlayTrailerAfterAd {
////                topVC.shouldPlayTrailerAfterAd = false
////                topVC.openYouTubeTrailer()
////            }
////        } else {
////            print("⚠️ Top VC is not ContentDetailsVC")
////        }
//    }

}

// MARK: - NativeAd Loader Delegate
extension TR_AdsManager: NativeAdLoaderDelegate {

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        //        print("did Receive Native Ad \(nativeAd)")
        isNativeLoad = true
        arrNativeAds.append(nativeAd)
        self.delegate?.NativeAdLoad()
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
      //  print("\(adLoader) failed with error: \(error.localizedDescription)")
        isNativeLoad = false
    }

    func adLoaderDidFinishLoading(_ adLoader: AdLoader) {

    }

}



// MARK: - Google Banner Ads -

//class GoogleBannerAds: NSObject, BannerViewDelegate {
//
//    var view: BannerView!
//
//    func loadAds(vc: UIViewController, view : BannerView) {
//        if Subscribe.get() {
//            return
//        }
//        view.isHidden = true
//        let viewWidth = view.frame.size.width
//
//        self.view = view
//        self.view.adSize = currentOrientationAnchoredAdaptiveBanner(width: viewWidth)
//        self.view.adUnitID = bannerId
//        self.view.rootViewController = vc
//        self.view.delegate = self
//        self.view.load(Request())
//    }
//
//    // MARK: GADBannerViewDelegate Methods
//    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
//        view.isHidden = false
//    }
//
//    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
//        view.isHidden = true
//    }
//
//}


// MARK: - Google Native Ads -
//class GoogleNativeAds: NSObject, NativeAdLoaderDelegate {
//
//    var completion: ((NativeAd) -> Void)?
//    var fail: ((Error) -> Void)?
//    var adLoader: AdLoader!
//
//    func loadAds(_ vc: UIViewController, _ completion: @escaping (NativeAd) -> Void) {
//        if Subscribe.get(){
//            return
//        }
//        print("Native Comple..")
//        self.completion = completion
//
//        let multipleAdsOptions = MultipleAdsAdLoaderOptions()
//        multipleAdsOptions.numberOfAds = 1
//        self.adLoader = AdLoader(adUnitID: nativeId, rootViewController: vc, adTypes: [AdLoaderAdType.native], options: [multipleAdsOptions])
//        self.adLoader.delegate = self
//        self.adLoader.load(Request())
//    }
//    
//    func failAds(_ vc: UIViewController, _ fail: @escaping (Error) -> Void ) {
//        if Subscribe.get(){
//            return
//        }
//        print("Native Fail..")
//        self.fail = fail
//    }
//    
//    //load Small_native
//    func loadAds_Small_native(_ vc: UIViewController, _ completion: @escaping (NativeAd) -> Void) {
//        if Subscribe.get(){
//            return
//        }
//        print("Native Comple..")
//        self.completion = completion
//
//        let multipleAdsOptions = MultipleAdsAdLoaderOptions()
//        multipleAdsOptions.numberOfAds = 1
//        self.adLoader = AdLoader(adUnitID: smallNativeBannerId, rootViewController: vc, adTypes: [AdLoaderAdType.native], options: [multipleAdsOptions])
//        self.adLoader.delegate = self
//        self.adLoader.load(Request())
//    }
//    
//    func failAds_Small_native(_ vc: UIViewController, _ fail: @escaping (Error) -> Void ) {
//        if Subscribe.get(){
//            return
//        }
//        print("Native Fail..")
//        self.fail = fail
//    }
//
//    // MARK: - GADNativeAdLoaderDelegate Methods
//    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
//      //  print("Native completion..")
//        completion!(nativeAd)
//        print("Native completion..")
//    }
//
//    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
//       
//        fail?(error)
//        print("Native error")
//        debugPrint("Error: \(error.localizedDescription)")
//    }
//
//     //MARK: - Load View Methods
//
//    let googleNativeAdsCustomeView1: GoogleNativeAdsCustomeView1 = GoogleNativeAdsCustomeView1.instanceFromNib() as! GoogleNativeAdsCustomeView1
//    /// Load big native ads
//    func showAdsView1(nativeAd: NativeAd, view: UIView) {
//        view.isHidden = false
//        displaySubViewtoParentView(view, subview: googleNativeAdsCustomeView1)
//        googleNativeAdsCustomeView1.nativeAd = nativeAd
//        googleNativeAdsCustomeView1.setup()
//    }
//
//    let googleNativeAdsCustomeView2: GoogleNativeAdsCustomeView2 = GoogleNativeAdsCustomeView2.instanceFromNib() as! GoogleNativeAdsCustomeView2
//    /// Load Ads like table view cell (Like Banner Ads)
//    func showAdsView2(nativeAd: NativeAd, view: UIView) {
//        view.isHidden = false
//        displaySubViewtoParentView(view, subview: googleNativeAdsCustomeView2)
//        googleNativeAdsCustomeView2.nativeAd = nativeAd
//        googleNativeAdsCustomeView2.setup()
//    }
//
//    let googleNativeAdsCustomeView4: GoogleNativeAdsCustomeView4 = GoogleNativeAdsCustomeView4.instanceFromNib() as! GoogleNativeAdsCustomeView4
//    /// Load Ads like table view cell (Like Banner Ads)
//    func showAdsView4(nativeAd: NativeAd, view: UIView) {
//        view.isHidden = false
//        displaySubViewtoParentView(view, subview: googleNativeAdsCustomeView4)
//        googleNativeAdsCustomeView4.nativeAd = nativeAd
//        googleNativeAdsCustomeView4.setup()
//    }
//
//    let googleNativeAdsCustomeView3: GoogleNativeAdsCustomeView3 = GoogleNativeAdsCustomeView3.instanceFromNib() as! GoogleNativeAdsCustomeView3
//    /// Load Ads like table view cell (Like Banner Ads)
//    func showAdsView3(nativeAd: NativeAd, view: UIView) {
//        view.isHidden = false
//        displaySubViewtoParentView(view, subview: googleNativeAdsCustomeView3)
//        googleNativeAdsCustomeView3.nativeAd = nativeAd
//        googleNativeAdsCustomeView3.setup()
//    }
//
//    let googleNativeAdsCustomeView5: TR_GoogleNativeAdsCustomeView5 = TR_GoogleNativeAdsCustomeView5.instanceFromNib() as! TR_GoogleNativeAdsCustomeView5
//    /// Load big native ads
//    func showAdsView5(nativeAd: NativeAd, view: UIView) {
//        view.isHidden = false
//        displaySubViewtoParentView(view, subview: googleNativeAdsCustomeView5)
//        googleNativeAdsCustomeView5.nativeAd = nativeAd
//        googleNativeAdsCustomeView5.setup()
//    }
//    
//    let googleNativeAdsCustomeView6: TR_GoogleNativeAdsCustomeView6 = TR_GoogleNativeAdsCustomeView6.instanceFromNib() as! TR_GoogleNativeAdsCustomeView6
//    /// Load big native ads
//    func showAdsView6(nativeAd: NativeAd, view: UIView) {
//        view.isHidden = false
//        displaySubViewtoParentView(view, subview: googleNativeAdsCustomeView6)
//        googleNativeAdsCustomeView6.nativeAd = nativeAd
//        googleNativeAdsCustomeView6.setup()
//    }
//    
//    
//    let googleNativeAdsCustomeView7: TR_GoogleNativeAdsCustomeView7 = TR_GoogleNativeAdsCustomeView7.instanceFromNib() as! TR_GoogleNativeAdsCustomeView7
////    Full Screen Native
//    func showAdsView7(nativeAd: NativeAd, view: UIView) {
//        view.isHidden = false
//        displaySubViewtoParentView(view, subview: googleNativeAdsCustomeView7)
//        googleNativeAdsCustomeView7.nativeAd = nativeAd
//        googleNativeAdsCustomeView7.setup()
//    }
//    
//    let googleNativeAdsCustomeView8: GoogleNativeAdsCustomeView8 = GoogleNativeAdsCustomeView8.instanceFromNib() as! GoogleNativeAdsCustomeView8
//        /// Load Media native ads
//    func showAdsView8(nativeAd: NativeAd, view: UIView) {
//            view.isHidden = false
//            displaySubViewtoParentView(view, subview: googleNativeAdsCustomeView8)
//            googleNativeAdsCustomeView8.nativeAd = nativeAd
//            googleNativeAdsCustomeView8.setup()
//        }
//    
//    let googleNativeAdsCustomeView9: TR_GoogleNativeAdsCustomeView9 = TR_GoogleNativeAdsCustomeView9.instanceFromNib() as! TR_GoogleNativeAdsCustomeView9
//        /// Load Media native ads
//    func showAdsView9(nativeAd: NativeAd, view: UIView) {
//            view.isHidden = false
//            displaySubViewtoParentView(view, subview: googleNativeAdsCustomeView9)
//            googleNativeAdsCustomeView9.nativeAd = nativeAd
//            googleNativeAdsCustomeView9.setup()
//        }
//    
//}

// MARK: - Display view into subview
func displaySubViewtoParentView(_ parentview: UIView! , subview: UIView!) {
    subview.translatesAutoresizingMaskIntoConstraints = false
    parentview.addSubview(subview);
    parentview.addConstraint(NSLayoutConstraint(item: subview!, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: parentview, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1.0, constant: 0.0))
    parentview.addConstraint(NSLayoutConstraint(item: subview!, attribute: NSLayoutConstraint.Attribute.leading, relatedBy: NSLayoutConstraint.Relation.equal, toItem: parentview, attribute: NSLayoutConstraint.Attribute.leading, multiplier: 1.0, constant: 0.0))
    parentview.addConstraint(NSLayoutConstraint(item: subview!, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy: NSLayoutConstraint.Relation.equal, toItem: parentview, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1.0, constant: 0.0))
    parentview.addConstraint(NSLayoutConstraint(item: subview!, attribute: NSLayoutConstraint.Attribute.trailing, relatedBy: NSLayoutConstraint.Relation.equal, toItem: parentview, attribute: NSLayoutConstraint.Attribute.trailing, multiplier: 1.0, constant: 0.0))
    parentview.layoutIfNeeded()
}

func getTopViewController() -> UIViewController? {
    return UIApplication.topViewController
}
