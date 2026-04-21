//
//  AppShadowModifier.swift
//  VibeTrip
//
//  Created by CHOI on 4/21/26.
//

import SwiftUI

enum AppShadowStyle {
    // shadow 없음
    case none
    // 메인_카드이미지섀도우
    case mainCardImage
    // 메인페이지_카드프레임섀도우
    case mainPageCardFrame
    // 버튼+텍스트필드섀도우
    case buttonTextField
    // 상세페이지_메뉴섀도우
    case detailMenu
    // 페이지컨트롤섀도우
    case pageControl

    fileprivate var x: CGFloat {
        switch self {
        case .none: return 0
        case .mainCardImage: return 0
        case .mainPageCardFrame: return 0
        case .buttonTextField: return 0
        case .detailMenu: return 0
        case .pageControl: return 0
        }
    }

    fileprivate var y: CGFloat {
        switch self {
        case .none: return 0
        case .mainCardImage: return 3
        case .mainPageCardFrame: return 1
        case .buttonTextField: return 1
        case .detailMenu: return 0
        case .pageControl: return 0
        }
    }

    fileprivate var blur: CGFloat {
        switch self {
        case .none: return 0
        case .mainCardImage: return 5
        case .mainPageCardFrame: return 10
        case .buttonTextField: return 3
        case .detailMenu: return 10
        case .pageControl: return 6
        }
    }

    fileprivate var opacity: CGFloat {
        switch self {
        case .none: return 0
        case .mainCardImage: return 0.10
        case .mainPageCardFrame: return 0.06
        case .buttonTextField: return 0.06
        case .detailMenu: return 0.10
        case .pageControl: return 0.50
        }
    }
}

// 공통 shadow 적용 modifier
private struct AppShadowModifier: ViewModifier {
    let style: AppShadowStyle

    func body(content: Content) -> some View {
        content.shadow(
            color: .black.opacity(style.opacity),
            radius: style.blur,
            x: style.x,
            y: style.y
        )
    }
}

extension View {
    // 호출부: .appShadow(.buttonTextField) 형태로 통일
    func appShadow(_ style: AppShadowStyle) -> some View {
        modifier(AppShadowModifier(style: style))
    }
}
