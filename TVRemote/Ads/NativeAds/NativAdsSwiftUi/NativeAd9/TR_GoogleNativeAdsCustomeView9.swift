//
//  TR_GoogleNativeAdsCustomeView9.swift
//  TV Remote Casting
//
//  Created by Parthiv Akbari on 17/10/25.
//

import UIKit
import GoogleMobileAds

class TR_GoogleNativeAdsCustomeView9: UIView {
    
    @IBOutlet weak var adUIView: NativeAdView!
    @IBOutlet weak var nativeAdsWidth: NSLayoutConstraint!
    @IBOutlet weak var bgTagView: UIView!
    @IBOutlet weak var star1: UIImageView!
    @IBOutlet weak var star2: UIImageView!
    @IBOutlet weak var star3: UIImageView!
    @IBOutlet weak var star4: UIImageView!
    @IBOutlet weak var star5: UIImageView!
    
    var nativeAd: NativeAd = NativeAd()
    let filledStar = UIImage(systemName: "star.fill")
    let emptyStar = UIImage(systemName: "star")
    
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "TR_GoogleNativeAdsCustomeView9", bundle: nil)
            .instantiate(withOwner: nil, options: nil)[0] as! UIView
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setup() {
        bgTagView.roundCorners(corners: UIRectCorner.allCorners, radius: 2)
        let adView: NativeAdView = adUIView
        adView.nativeAd = nativeAd
        setStarRating(nativeAd.starRating)
        
        (adView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        (adView.headlineView as? UILabel)?.textColor = .black
        adView.mediaView?.mediaContent = nativeAd.mediaContent
        (adView.bodyView as? UILabel)?.text = nativeAd.body ?? ""
        (adView.bodyView as? UILabel)?.textColor = hexStringToUIColor(hex: "#BDBDBD")
        (adView.callToActionView as? UIButton)?.backgroundColor = hexStringToUIColor(hex: addButtonColor)
        
        if let ctaButton = adView.callToActionView as? UIButton {
            ctaButton.isUserInteractionEnabled = false
            ctaButton.setTitle(nativeAd.callToAction, for: .normal)
            ctaButton.layer.cornerRadius = 20
        }
        
        (adView.iconView as? UIImageView)?.layer.cornerRadius = 5
        adView.backgroundColor = .clear
        
        let data = (adView.iconView as? UIImageView)?.image?.pngData()
        nativeAdsWidth.constant = (data == nil) ? 0 : nativeAdsWidth.constant
    }
    
    func setStarRating(_ rating: NSDecimalNumber?) {
        let stars = [star1, star2, star3, star4, star5]
        guard let ratingValue = rating?.doubleValue else {
            stars.forEach { $0?.isHidden = true }
            return
        }
        
        for (index, star) in stars.enumerated() {
            star?.isHidden = false
            star?.image = Double(index) < ratingValue ? filledStar : emptyStar
        }
    }
}
