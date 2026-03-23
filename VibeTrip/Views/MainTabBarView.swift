//
//  MainTabBarView.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI
import UIKit

// MARK: - AppTab
// 탭바 항목 정의 (순서, 아이콘, 레이블)

enum AppTab: Int, CaseIterable {
    case home         = 0
    case makeAlbum    = 1
    case notification = 2
    case myPage       = 3

    // 미선택 상태 아이콘 (outline)
    var icon: String {
        switch self {
        case .home:         return "house"
        case .makeAlbum:    return "rectangle.stack.badge.plus"
        case .notification: return "bell"
        case .myPage:       return "person"
        }
    }

    // 선택 상태 아이콘 (filled)
    var selectedIcon: String {
        switch self {
        case .home:         return "house.fill"
        case .makeAlbum:    return "rectangle.stack.fill.badge.plus"
        case .notification: return "bell.fill"
        case .myPage:       return "person.fill"
        }
    }

    // 탭 레이블 텍스트
    var label: String {
        switch self {
        case .home:         return "홈"
        case .makeAlbum:    return "앨범 만들기"
        case .notification: return "알림"
        case .myPage:       return "마이페이지"
        }
    }
}

// MARK: - MainTabBarView

struct MainTabBarView: View {

    // 현재 선택된 탭 (기본값: 홈)
    @State private var selectedTab: AppTab = .home

    var body: some View {
        ZStack {

            // 기본 배경색
            Color(UIColor.systemBackground).ignoresSafeArea()

            // 탭 전환
            switch selectedTab {
            case .home:         MainPageView()
            case .makeAlbum:    MakeAlbumView()
            case .notification: NotificationView()
            case .myPage:       MyPageView()
            }

            // NavBar + TabBar를 콘텐츠 위에 오버레이
            VStack(spacing: 0) {
                NavBarSpacer()
                Spacer()
                LiquidGlassTabBar(selectedTab: $selectedTab)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - NavBarSpacer
// TODO: 로고 추가

struct NavBarSpacer: View {

    var body: some View {
        Color.clear
            .frame(height: 100)
    }
}

// MARK: - LiquidGlassTabBar

struct LiquidGlassTabBar: View {

    @Binding var selectedTab: AppTab

    private enum Layout {
        static let iconSize: CGFloat      = 25   // 탭 아이콘 크기
        static let barHeight: CGFloat     = 64   // 탭바 높이
        static let bottomPadding: CGFloat = 28   // 홈 인디케이터 여백
        static let sidePadding: CGFloat   = 20   // 탭바 캡슐 좌우 여백
        static let innerPadding: CGFloat  = 20   // 탭바 내부 좌우 여백
    }

    var body: some View {
        GeometryReader { geo in
            // 탭바 전체 너비를 기기 화면에 맞게 자동 계산
            let totalW = geo.size.width
            // 내부 좌우 여백을 제외한 너비를 탭 개수로 균등 분할
            let tabW   = (totalW - Layout.innerPadding * 2) / CGFloat(AppTab.allCases.count)

            ZStack {

                // 블러 배경 캡슐
                // 단색 배경: LiquidGlassBackground() 비활성화 및 아래 주석 해제
                // Color(UIColor.systemBackground).clipShape(Capsule())
                LiquidGlassBackground()
                    .clipShape(Capsule())
                    // 테두리 효과
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.55),
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.08)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    // 탭바 그림자
                    .shadow(color: .black.opacity(0.18), radius: 15, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.08), radius: 6,  x: 0, y: 2)

                // 탭 아이템 목록 (내부 여백 적용 후 균등 분할)
                HStack(spacing: 0) {
                    ForEach(AppTab.allCases, id: \.rawValue) { tab in
                        tabItem(tab: tab, tabW: tabW)
                    }
                }
                .padding(.horizontal, Layout.innerPadding)
            }
            .frame(width: totalW, height: Layout.barHeight)
        }
        .frame(height: Layout.barHeight)
        .padding(.horizontal, Layout.sidePadding)
        .padding(.bottom, Layout.bottomPadding)
    }

    // MARK: - tabItem

    @ViewBuilder
    private func tabItem(tab: AppTab, tabW: CGFloat) -> some View {
        let isSelected = selectedTab == tab

        VStack(spacing: 3) {
            // 선택: filled 아이콘 / 미선택: outline 아이콘
            Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                .resizable()
                .scaledToFit()
                .frame(width: Layout.iconSize, height: Layout.iconSize)

            // 탭 레이블
            Text(tab.label)
                .font(Font.setPretendard(weight: isSelected ? .semiBold : .medium, size: 10))
                .fontWeight(isSelected ? .semibold : .medium)
                .multilineTextAlignment(.center)
        }
        // 선택: appPrimary / 미선택: secondaryLabel
        .foregroundStyle(
            isSelected
                ? AnyShapeStyle(Color.appPrimary)
                : AnyShapeStyle(Color.tabLabelUnselected)
        )
        .frame(width: tabW, height: Layout.barHeight)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
            // 탭 전환 햅틱 피드백
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabBarView()
}
