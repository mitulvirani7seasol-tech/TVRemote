
import UIKit
import GoogleMobileAds

class TR_GoogleNativeAdsCustomeView6: UIView {
    
    // OUTLET
    @IBOutlet var adUIView: NativeAdView!
    @IBOutlet weak var nativeAdsWidth: NSLayoutConstraint!
    
    @IBOutlet weak var tagAd: UIView!
    
    @IBOutlet weak var btnopen: UIButton!
    // VARIABLE
    var nativeAd: NativeAd = NativeAd()
    var blackColor:Bool = false
    
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "TR_GoogleNativeAdsCustomeView6", bundle: nil).instantiate(withOwner: nil, options: nil)[0] as! UIView
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // MARK: - Methods
    func setup() {
        tagAd.roundCorners(corners: [.topLeft, .bottomRight], radius: 10)
        let adView = self.adUIView
        adView?.nativeAd = nativeAd
        adView?.mediaView?.mediaContent = nativeAd.mediaContent
        adView?.mediaView?.contentMode = .scaleAspectFill
        (adView?.headlineView as? UILabel)?.text = nativeAd.headline
        (adView?.headlineView as? UILabel)?.textColor = .blue
        (adView?.bodyView as? UILabel)?.text = "\(nativeAd.body ?? "")"
        (adView?.bodyView as? UILabel)?.textColor = hexStringToUIColor(hex: "#BDBDBD")
        (adView?.iconView as? UIImageView)?.clipsToBounds = true
        (adView?.iconView as? UIImageView)?.layer.cornerRadius = 5
        (adView?.iconView as? UIImageView)?.image = nativeAd.icon?.image
        (adView?.callToActionView as? UIButton)?.isUserInteractionEnabled = false
        (adView?.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        (adView?.callToActionView as? UIButton)?.layer.cornerRadius = 4
//        (adView!.callToActionView as? UIButton)?.backgroundColor = Common().hexStringToUIColor(hex: Application.addButtonColor)
        self.btnopen.backgroundColor = hexStringToUIColor(hex: addButtonColor)
//        if blackColor == true {
//            (adView?.headlineView as? UILabel)?.textColor = .black
//            (adView?.bodyView as? UILabel)?.textColor = .darkGray
//        } else {
//            (adView?.headlineView as? UILabel)?.textColor = .white
//            (adView?.bodyView as? UILabel)?.textColor = .systemGray6
//        }
        
        
        
        let data = (adView?.iconView as? UIImageView)?.image?.pngData()
        if data == nil {
            nativeAdsWidth.constant = 0
        }
        
        
    }
}

func hexStringToUIColor(hex:String) -> UIColor {
    var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

    if (cString.hasPrefix("#")) {
        cString.remove(at: cString.startIndex)
    }

    if ((cString.count) != 6) {
        return UIColor.gray
    }

    var rgbValue:UInt64 = 0
    Scanner(string: cString).scanHexInt64(&rgbValue)

    return UIColor(
        red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
        green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
        blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
        alpha: CGFloat(1.0)
    )
}
