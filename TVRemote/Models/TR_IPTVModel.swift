//
//  IPTVModel.swift
//  ClarioMirror
//
//  Created by Vivek Rakholiya on 08/05/26.
//

import Foundation

struct TR_IPTVCountryModelElement: Codable, Hashable, Identifiable {
    var id: String { country ?? (countryCodes?.isEmpty == false ? countryCodes! : UUID().uuidString) }
    let countryCodes: String?
    let country: String?
    let flag: String?
    let channels: [TR_Channel]?
    
    var resolvedCountryCode: String {
        if let code = countryCodes?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty {
            return code.lowercased()
        }
        if let name = country?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           let mapped = Self.countryCodeMap[name] {
            return mapped
        }
        return ""
    }
    
    var resolvedFlagURL: URL? {
        if let flag = flag, !flag.isEmpty, !flag.hasSuffix("/.png"), let url = URL(string: flag) {
            return url
        }
        let code = resolvedCountryCode
        if !code.isEmpty {
            return URL(string: "https://flagcdn.com/w320/\(code).png")
        }
        return nil
    }
    
    static let countryCodeMap: [String: String] = [
        "afghanistan": "af", "albania": "al", "algeria": "dz", "andorra": "ad", "angola": "ao",
        "argentina": "ar", "armenia": "am", "aruba": "aw", "australia": "au", "austria": "at",
        "azerbaijan": "az", "bahamas": "bs", "bahrain": "bh", "bangladesh": "bd", "barbados": "bb",
        "belarus": "by", "belgium": "be", "benin": "bj", "bermuda": "bm", "bhutan": "bt",
        "bolivia": "bo", "bonaire": "bq", "bosnia and herzegovina": "ba", "brazil": "br",
        "british virgin islands": "vg", "brunei": "bn", "bulgaria": "bg", "burkina faso": "bf",
        "cambodia": "kh", "cameroon": "cm", "canada": "ca", "cape verde": "cv", "chad": "td",
        "chile": "cl", "china": "cn", "colombia": "co", "costa rica": "cr", "croatia": "hr",
        "cuba": "cu", "curacao": "cw", "cyprus": "cy", "czech republic": "cz",
        "democratic republic of the congo": "cd", "denmark": "dk", "djibouti": "dj",
        "dominican republic": "do", "ecuador": "ec", "egypt": "eg", "el salvador": "sv",
        "equatorial guinea": "gq", "eritrea": "er", "estonia": "ee", "ethiopia": "et",
        "faroe islands": "fo", "finland": "fi", "france": "fr", "french polynesia": "pf",
        "gabon": "ga", "gambia": "gm", "georgia": "ge", "germany": "de", "ghana": "gh",
        "greece": "gr", "guadeloupe": "gp", "guam": "gu", "guatemala": "gt", "guernsey": "gg",
        "guinea": "gn", "guyana": "gy", "haiti": "ht", "honduras": "hn", "hong kong": "hk",
        "hungary": "hu", "iceland": "is", "india": "in", "indonesia": "id", "iran": "ir",
        "iraq": "iq", "ireland": "ie", "israel": "il", "italy": "it", "ivory coast": "ci",
        "jamaica": "jm", "japan": "jp", "jordan": "jo", "kazakhstan": "kz", "kenya": "ke",
        "kosovo": "xk", "kuwait": "kw", "kyrgyzstan": "kg", "laos": "la", "latvia": "lv",
        "lebanon": "lb", "liberia": "lr", "libya": "ly", "liechtenstein": "li", "lithuania": "lt",
        "luxembourg": "lu", "macao": "mo", "malaysia": "my", "maldives": "mv", "mali": "ml",
        "malta": "mt", "martinique": "mq", "mauritania": "mr", "mauritius": "mu", "mexico": "mx",
        "moldova": "md", "monaco": "mc", "mongolia": "mn", "montenegro": "me", "morocco": "ma",
        "mozambique": "mz", "myanmar": "mm", "namibia": "na", "nepal": "np", "netherlands": "nl",
        "new zealand": "nz", "nicaragua": "ni", "niger": "ne", "nigeria": "ng", "north korea": "kp",
        "north macedonia": "mk", "norway": "no", "oman": "om", "pakistan": "pk", "palestine": "ps",
        "panama": "pa", "papua new guinea": "pg", "paraguay": "py", "peru": "pe",
        "philippines": "ph", "poland": "pl", "portugal": "pt", "puerto rico": "pr", "qatar": "qa",
        "republic of the congo": "cg", "reunion": "re", "romania": "ro", "russia": "ru",
        "rwanda": "rw", "saint kitts and nevis": "kn", "saint lucia": "lc", "samoa": "ws",
        "san marino": "sm", "saudi arabia": "sa", "senegal": "sn", "serbia": "rs",
        "singapore": "sg", "sint maarten": "sx", "slovakia": "sk", "slovenia": "si",
        "somalia": "so", "south africa": "za", "south korea": "kr", "spain": "es",
        "sri lanka": "lk", "sudan": "sd", "suriname": "sr", "sweden": "se", "switzerland": "ch",
        "syria": "sy", "taiwan": "tw", "tajikistan": "tj", "tanzania": "tz", "thailand": "th",
        "togo": "tg", "trinidad and tobago": "tt", "tunisia": "tn", "turkiye": "tr",
        "turkmenistan": "tm", "uganda": "ug", "ukraine": "ua", "united arab emirates": "ae",
        "united kingdom": "uk", "united states": "us", "uruguay": "uy", "uzbekistan": "uz",
        "vatican city": "va", "venezuela": "ve", "vietnam": "vn", "western sahara": "eh",
        "yemen": "ye", "zimbabwe": "zw", "international": "un", "undefined": "xx"
    ]
}

typealias TR_IPTVCountryModel = [TR_IPTVCountryModelElement]


struct TR_IPTVCategoryModelElement: Codable, Hashable, Identifiable {
    var id: String { category ?? UUID().uuidString }
    let category: String?
    let channels: [TR_Channel]?
}

// MARK: - TR_Channel
struct TR_Channel: Codable, Hashable, Identifiable {
    var id: String { (url?.isEmpty == false ? url : name) ?? UUID().uuidString }
    let name: String?
    let logo: String?
    let url: String?
}

typealias TR_IPTVCategoryModel = [TR_IPTVCategoryModelElement]
