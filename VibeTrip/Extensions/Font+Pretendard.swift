//
//  Font+Pretendard.swift
//  VibeTrip
//
//  Created by CHOI on 3/21/26.
//


import SwiftUI

extension Font {
    
    enum FontWeight: String {
        case black = "Pretendard-Black"
        case bold = "Pretendard-Bold"
        case extraBold = "Pretendard-ExtraBold"
        case extraLight = "Pretendard-ExtraLight"
        case light = "Pretendard-Light"
        case medium = "Pretendard-Medium"
        case regular = "Pretendard-Regular"
        case semiBold = "Pretendard-SemiBold"
        case thin = "Pretendard-Thin"
    }

    static func setPretendard(weight: FontWeight, size: CGFloat) -> Font {
        return .custom(weight.rawValue, size: size)
    }
}
