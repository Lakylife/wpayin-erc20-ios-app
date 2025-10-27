//
//  Bundle+Language.swift
//  Wpayin_Wallet
//
//  Created by Claude Code
//

import Foundation
import UIKit

private var bundleKey: UInt8 = 0

class BundleExtension: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    static let once: Void = {
        object_setClass(Bundle.main, BundleExtension.self)
    }()

    static func setLanguage(_ language: String) {
        Bundle.once

        let isLanguageRTL = Locale.characterDirection(forLanguage: language) == .rightToLeft
        if isLanguageRTL {
            UIView.appearance().semanticContentAttribute = .forceRightToLeft
        } else {
            UIView.appearance().semanticContentAttribute = .forceLeftToRight
        }
        UserDefaults.standard.set(isLanguageRTL, forKey: "AppleTextDirection")
        UserDefaults.standard.set(isLanguageRTL, forKey: "NSForceRightToLeftWritingDirection")
        UserDefaults.standard.synchronize()

        let path = Bundle.main.path(forResource: language, ofType: "lproj")
        if let path = path {
            objc_setAssociatedObject(Bundle.main, &bundleKey, Bundle(path: path), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        } else {
            // Fallback to base bundle if language not found
            objc_setAssociatedObject(Bundle.main, &bundleKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    static var currentLanguage: String {
        if let currentLanguage = objc_getAssociatedObject(Bundle.main, &bundleKey) as? Bundle {
            return currentLanguage.bundlePath.components(separatedBy: "/").last?.replacingOccurrences(of: ".lproj", with: "") ?? "en"
        }
        return UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "en"
    }
}
