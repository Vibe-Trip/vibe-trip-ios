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
// blurAlways: 스크롤 여부와 무관하게 항상 블러 표시 (ZStack + ignoresSafeArea 방식)

// blurOnly or blurTransition -> 뷰에서 offset 감지 필요:
/// @State private var offset: CGFloat = 0
/// -> ScrollOffsetKey로 감지 후 style에 전달

enum NavBarStyle {
    case transparent
    case solidWhite
    case blurOnly(scrollOffset: CGFloat)
    case blurTransition(scrollOffset: CGFloat)
    case blurAlways
}

// MARK: - Constants

private enum AppNavigationBarConstants {
    static let touchTargetSize: CGFloat = 44
    static let horizontalPadding: CGFloat = 20
    static let height: CGFloat = 44
    static let backIconSize: CGFloat = 20

    // 블러 관련 상수

    /// 블러 강도: 0.0(투명) ~ 1.0(블러)
    static let blurIntensity: CGFloat = 0.1
    /// 스크롤 시, 블러 시작 시점
    static let blurTrigger: CGFloat = 0
    /// 스크롤 시, 블러 최대 시점
    static let blurMaxOffset: CGFloat = -60
    /// 타이틀 fade 시작 시점 (blurTransition)
    static let titleFadeStart: CGFloat = -35
    /// 타이틀 fade 완료 시점 (blurTransition)
    static let titleFadeEnd: CGFloat = -60
}

// MARK: - AppNavBackButton

// 뒤로가기 버튼
struct AppNavBackButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
    }
}

// MARK: - AppNavigationBar

struct AppNavigationBar<Leading: View, Trailing: View>: View {

    let title: String?
    let style: NavBarStyle
    let leading: Leading
    let trailing: Trailing
    private let isLargeTitle: Bool  // true: 24pt 좌측 정렬 (탭 루트 페이지 전용), false: 16pt 센터 정렬 (표준 네비게이션)

    // MARK: - Init

    init(
        title: String? = nil,
        style: NavBarStyle = .transparent,
        isLargeTitle: Bool = false,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.style = style
        self.isLargeTitle = isLargeTitle
        self.leading = leading()
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
                contentHStack(alignment: .top, topPadding: safeTop + 12)
            }
            .frame(height: safeTop + AppNavigationBarConstants.height)
            .ignoresSafeArea()
        }
    }

    // MARK: - 콘텐츠 HStack

    private func contentHStack(alignment: Alignment, topPadding: CGFloat = 0, bottomPadding: CGFloat = 0) -> some View {
        Group {
            if isLargeTitle {
                // 탭 루트 페이지: 24pt 좌측 정렬, leading 슬롯 없음
                HStack {
                    if let title {
                        Text(title)
                            .font(.setPretendard(weight: .semiBold, size: 24))
                            .foregroundStyle(Color.textPrimary)
                    }
                    Spacer()
                    Color.clear
                        .frame(
                            width: AppNavigationBarConstants.touchTargetSize,
                            height: AppNavigationBarConstants.touchTargetSize
                        )
                        .overlay { trailing }
                }
            } else {
                // 표준 네비게이션: 16pt 센터 정렬, leading/trailing 슬롯 44pt 고정
                HStack {
                    // 좌측: leading 슬롯 (고정 44pt로 타이틀 중앙 정렬 유지)
                    Color.clear
                        .frame(
                            width: AppNavigationBarConstants.touchTargetSize,
                            height: AppNavigationBarConstants.touchTargetSize
                        )
                        .overlay { leading }

                    Spacer()

                    // 중앙: 타이틀 (옵셔널)
                    if let title {
                        Text(title)
                            .font(.setPretendard(weight: .medium, size: 16))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                            .opacity(titleOpacity)
                    }

                    Spacer()

                    // 우측: trailing 슬롯
                    Color.clear
                        .frame(
                            width: AppNavigationBarConstants.touchTargetSize,
                            height: AppNavigationBarConstants.touchTargetSize
                        )
                        .overlay { trailing }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppNavigationBarConstants.horizontalPadding)
        .frame(maxHeight: .infinity, alignment: alignment)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
    }

    // MARK: - 블러 배경 (blurOnly / blurTransition / blurAlways)

    @ViewBuilder
    private var blurBackground: some View {
        switch style {
        case .transparent, .solidWhite:
            Color.clear

        case .blurOnly, .blurTransition, .blurAlways:
            // 블러 레이어 + 하단 페이드 마스크
            BlurView(style: .systemUltraThinMaterialDark, intensity: AppNavigationBarConstants.blurIntensity)
                .opacity(blurOpacity)
                .mask(
                    // 0.0~0.82: 균일한 블러
                    // 0.82~1.0: 하단으로 갈수록 서서히 투명
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .black,                     location: 0.0),
                            .init(color: .black,                     location: 0.70),
                            .init(color: Color.black.opacity(0.6),   location: 0.82),
                            .init(color: Color.black.opacity(0.15),  location: 0.92),
                            .init(color: .clear,                     location: 1.0)
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
        switch style {
        case .blurAlways:
            return 1.0
        default:
            let offset = scrollOffset
            let trigger = AppNavigationBarConstants.blurTrigger
            let maxOffset = AppNavigationBarConstants.blurMaxOffset

            if offset > trigger { return 0 }
            if offset < maxOffset { return 1.0 }
            return Double((trigger - offset) / (trigger - maxOffset))
        }
    }

    // MARK: - 타이틀 투명도
    // transparent / solidWhite / blurOnly / blurAlways: 항상 보임
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
        case .transparent, .solidWhite, .blurAlways: return 0
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

// 뒤로가기 버튼 + trailing
extension AppNavigationBar where Leading == AppNavBackButton {
    init(
        title: String? = nil,
        style: NavBarStyle = .transparent,
        onBackTap: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.style = style
        self.isLargeTitle = false
        self.leading = AppNavBackButton(action: onBackTap)
        self.trailing = trailing()
    }
}

// 뒤로가기 버튼만 (trailing 없음)
extension AppNavigationBar where Leading == AppNavBackButton, Trailing == EmptyView {
    init(
        title: String? = nil,
        style: NavBarStyle = .transparent,
        onBackTap: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isLargeTitle = false
        self.leading = AppNavBackButton(action: onBackTap)
        self.trailing = EmptyView()
    }
}

// leading/trailing X
extension AppNavigationBar where Leading == EmptyView, Trailing == EmptyView {
    init(
        title: String? = nil,
        style: NavBarStyle = .transparent
    ) {
        self.title = title
        self.style = style
        self.isLargeTitle = false
        self.leading = EmptyView()
        self.trailing = EmptyView()
    }

    // 탭 루트 페이지 전용: 24pt 좌측 정렬 타이틀
    init(
        largeTitle: String,
        style: NavBarStyle = .transparent
    ) {
        self.title = largeTitle
        self.style = style
        self.isLargeTitle = true
        self.leading = EmptyView()
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

#Preview("blurAlways - 알림 탭") {
    AppNavigationBar(largeTitle: "알림", style: .blurAlways)
}
