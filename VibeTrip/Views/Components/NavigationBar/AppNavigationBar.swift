//
//  AppNavigationBar.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI

// MARK: - NavBarStyle

// 네비게이션 바 배경 스타일
// transparent: 항상 투명, 블러 없음 (ZStack + ignoresSafeArea 방식)
// solidWhite: 흰 배경 고정, 블러 없음 (safeAreaInset 방식)
// blurOnly: 스크롤 시 블러 배경만 등장 (ZStack + ignoresSafeArea 방식)
// blurTransition: 스크롤 전 타이틀 숨김 -> 스크롤 후 블러 + 타이틀 표시 (ZStack + ignoresSafeArea 방식)

// blurOnly or blurTransition -> 뷰에서 offset 감지 필요:
/// @State private var offset: CGFloat = 0
/// -> ScrollOffsetKey로 감지 후 style에 전달

enum NavBarStyle {
    case transparent
    case solidWhite
    case blurOnly(scrollOffset: CGFloat)
    case blurTransition(scrollOffset: CGFloat)
}

// MARK: - Constants

private enum AppNavigationBarConstants {
    static let touchTargetSize: CGFloat = 44
    static let horizontalPadding: CGFloat = 20
    static let height: CGFloat = 44
    static let backIconSize: CGFloat = 20
    
    // 블러 관련 상수
    
    /// 블러 강도: 0.0(투명) ~ 1.0(블러)
    static let blurIntensity: CGFloat = 0.2
    /// 스크롤 시, 블러 시작 시점
    static let blurTrigger: CGFloat = 0
    /// 스크롤 시, 블러 최대 시점
    static let blurMaxOffset: CGFloat = -60
    /// 타이틀 fade 시작 시점 (blurTransition)
    static let titleFadeStart: CGFloat = -30
    /// 타이틀 fade 완료 시점 (blurTransition)
    static let titleFadeEnd: CGFloat = -60
}

// MARK: - AppNavigationBar

struct AppNavigationBar<Trailing: View>: View {
    
    let title: String
    let style: NavBarStyle
    let onBackTap: () -> Void
    let trailing: Trailing
    
    // MARK: - Init
    
    init(
        title: String,
        style: NavBarStyle = .transparent,
        onBackTap: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.style = style
        self.onBackTap = onBackTap
        self.trailing = trailing()
    }
    
    // MARK: - Body
    
    var body: some View {
        // TODO: 다크모드 대응 시, assets 색상 추가 및 적용
        if case .solidWhite = style {
            // safeAreaInset 방식
            ZStack {
                contentHStack(alignment: .center, bottomPadding: 0)
            }
            .frame(height: AppNavigationBarConstants.height)
            .background { Color.white.ignoresSafeArea(edges: .top) }    /// status bar영역까지 흰 배경
        } else {
            // ZStack overlay 방식
            ZStack {
                blurBackground
                contentHStack(alignment: .bottom, bottomPadding: 12)
            }
            .frame(height: safeTop + AppNavigationBarConstants.height)
            .ignoresSafeArea()
        }
    }
    
    // MARK: - 콘텐츠 HStack
    
    private func contentHStack(alignment: Alignment, bottomPadding: CGFloat) -> some View {
        HStack {
            // 좌측: 뒤로가기
            Button(action: onBackTap) {
                Image(systemName: "chevron.left")
                    .font(.system(
                        size: AppNavigationBarConstants.backIconSize,
                        weight: .medium
                    ))
                    .foregroundStyle(Color.textPrimary)
                    .frame(
                        width: AppNavigationBarConstants.touchTargetSize,
                        height: AppNavigationBarConstants.touchTargetSize
                    )
            }
            
            Spacer()
            
            // 중앙: 타이틀
            Text(title)
                .font(.setPretendard(weight: .medium, size: 16))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .opacity(titleOpacity)
            
            Spacer()
            
            // 우측: trailing
            Color.clear
                .frame(
                    width: AppNavigationBarConstants.touchTargetSize,
                    height: AppNavigationBarConstants.touchTargetSize
                )
                .overlay { trailing }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppNavigationBarConstants.horizontalPadding)
        .frame(maxHeight: .infinity, alignment: alignment)
        .padding(.bottom, bottomPadding)
    }
    
    // MARK: - 블러 배경 (blurOnly / blurTransition)
    
    @ViewBuilder
    private var blurBackground: some View {
        switch style {
        case .transparent, .solidWhite:
            Color.clear
            
        case .blurOnly, .blurTransition:
            // 블러 레이어 + 하단 페이드 마스크
            BlurView(style: .systemUltraThinMaterialDark, intensity: AppNavigationBarConstants.blurIntensity)
                .opacity(blurOpacity)
                .mask(
                    // 0.0~0.82: 균일한 블러
                    // 0.82~1.0: 하단으로 갈수록 서서히 투명
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .black,                    location: 0.0),
                            .init(color: .black,                    location: 0.82),
                            .init(color: Color.black.opacity(0.6),  location: 0.90),
                            .init(color: Color.black.opacity(0.15), location: 0.96),
                            .init(color: .clear,                    location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }
    
    // MARK: - 블러 투명도
    // scrollOffset 0 → -60 구간에서 0 → 1.0 선형 증가
    
    private var blurOpacity: Double {
        let offset = scrollOffset
        let trigger = AppNavigationBarConstants.blurTrigger
        let maxOffset = AppNavigationBarConstants.blurMaxOffset
        
        if offset > trigger { return 0 }
        if offset < maxOffset { return 1.0 }
        return Double((trigger - offset) / (trigger - maxOffset))
    }
    
    // MARK: - 타이틀 투명도
    // transparent / solidWhite / blurOnly: 항상 보임
    // blurTransition: scrollOffset -30 -> -60 구간에서 0 -> 1.0
    
    private var titleOpacity: Double {
        guard case .blurTransition = style else { return 1.0 }
        
        let offset = scrollOffset
        let fadeStart = AppNavigationBarConstants.titleFadeStart
        let fadeEnd = AppNavigationBarConstants.titleFadeEnd
        
        if offset > fadeStart { return 0 }
        if offset < fadeEnd { return 1 }
        return Double((fadeStart - offset) / (fadeStart - fadeEnd))
    }
    
    // MARK: - scrollOffset 추출
    
    private var scrollOffset: CGFloat {
        switch style {
        case .transparent, .solidWhite: return 0
        case .blurOnly(let offset): return offset
        case .blurTransition(let offset): return offset
        }
    }
    
    // MARK: - Safe Area Top
    
    private var safeTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.top ?? 0
    }
}

// MARK: - Convenience init
// trailing X

extension AppNavigationBar where Trailing == EmptyView {
    init(
        title: String,
        style: NavBarStyle = .transparent,
        onBackTap: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.onBackTap = onBackTap
        self.trailing = EmptyView()
    }
}

// MARK: - Preview

#Preview("transparent") {
    AppNavigationBar(title: "앨범 만들기", style: .transparent, onBackTap: {})
}

#Preview("solidWhite") {
    AppNavigationBar(title: "앨범 만들기", style: .solidWhite, onBackTap: {})
}

#Preview("solidWhite + trailing") {
    AppNavigationBar(title: "로그 작성", style: .solidWhite, onBackTap: {}) {
        Button("저장") {}
            .font(.setPretendard(weight: .semiBold, size: 16))
            .foregroundStyle(Color.appPrimary)
    }
}

#Preview("blurTransition") {
    AppNavigationBar(
        title: "에펠탑 느낌나는 야경 도쿄타워",
        style: .blurTransition(scrollOffset: -50),
        onBackTap: {}
    ) {
        Button(action: {}) {
            Image(systemName: "ellipsis")
        }
    }
}
