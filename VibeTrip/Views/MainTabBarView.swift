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
        case .home:         return "house.fill"
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
    @State private var isTabBarHidden = false
    @State private var isPresentingMakeAlbum = false
    @State private var isPresentingLoadingView = false

    @EnvironmentObject private var appState: AppState

    private let makeAlbumTransition = AnyTransition.move(edge: .trailing).combined(with: .opacity)
    private let tabBarTransition = AnyTransition.move(edge: .bottom).combined(with: .opacity)

    var body: some View {
        ZStack {

            // 기본 배경색
            Color(UIColor.systemBackground).ignoresSafeArea()

            Group {
                // 탭 전환
                switch selectedTab {
                case .home:
                    MainPageView()
                case .notification:
                    NotificationView()
                case .myPage:
                    MyPageView()
                case .makeAlbum:
                    Color(UIColor.systemBackground).ignoresSafeArea()
                }
            }

            if isPresentingMakeAlbum {
                MakeAlbumView(
                    onExit: {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            isPresentingMakeAlbum = false
                        }

                        // 진입 전 탭 복귀
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                isTabBarHidden = false
                            }
                        }
                    },
                    onProceedToLoading: {
                        // LoadingView를 표시 후, MakeAlbumView 제거
                        withAnimation(.easeInOut(duration: 0.24)) {
                            isPresentingLoadingView = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                            isPresentingMakeAlbum = false
                        }
                    }
                )
                .transition(makeAlbumTransition)
                .zIndex(1)
            }

            if isPresentingLoadingView {
                MakeAlbumLoadingView(onHide: {

                    // 화면 숨기기: 로딩 뷰 닫기 + 알림 탭으로 복귀
                    selectedTab = .notification
                    withAnimation(.easeInOut(duration: 0.24)) {
                        isPresentingLoadingView = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isTabBarHidden = false
                        }
                    }
                })
                .transition(makeAlbumTransition)
                .zIndex(2)
            }

            // NavBar + TabBar를 콘텐츠 위에 오버레이
            VStack(spacing: 0) {
                Spacer()
                if !isTabBarHidden {
                    LiquidGlassTabBar(
                        selectedTab: $selectedTab,
                        isTabBarHidden: $isTabBarHidden,
                        isPresentingMakeAlbum: $isPresentingMakeAlbum
                    )
                    .transition(tabBarTransition)
                }
            }
        }
        .animation(.easeInOut(duration: 0.24), value: isPresentingMakeAlbum)
        .animation(.easeInOut(duration: 0.22), value: isTabBarHidden)
        // 알림 탭 시, 화면 이동
        .onChange(of: appState.pendingNotificationAction) { _, action in
            guard let action else { return }
            switch action {
            case .openMakeAlbum:
                // 생성 실패: MakeAlbumView
                withAnimation(.easeInOut(duration: 0.18)) {
                    isTabBarHidden = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        isPresentingMakeAlbum = true
                    }
                }

            case .openAlbumCreationLoading:
                // 생성 중: MakeAlbumLoadingView
                // TODO: 서버 연동 시, 기존 생성 중인 ViewModel 상태 복원
                withAnimation(.easeInOut(duration: 0.18)) {
                    isTabBarHidden = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        isPresentingLoadingView = true
                    }
                }
            case .openAlbumDetail:
                // TODO: 서버 albumId 연동 후 AlbumDetailView 라우팅 구현
                break
            }
            appState.pendingNotificationAction = nil
        }
    }
}

// MARK: - LiquidGlassTabBar

struct LiquidGlassTabBar: View {

    @Binding var selectedTab: AppTab
    @Binding var isTabBarHidden: Bool
    @Binding var isPresentingMakeAlbum: Bool

    @EnvironmentObject private var appState: AppState

    private enum Layout {
        static let iconSize: CGFloat      = 25   // 탭 아이콘 크기
        static let barHeight: CGFloat     = 64   // 탭바 높이
//        static let bottomPadding: CGFloat = 28   // 홈 인디케이터 여백
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
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 4)
                    .shadow(color: .black.opacity(0.08), radius: 6,  x: 0, y: 4)

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
//        .padding(.bottom, Layout.bottomPadding)
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
                .overlay(alignment: .topTrailing) {
                    if tab == .notification && appState.hasUnreadNotifications {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 4, y: -4)
                    }
                }

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
            if tab == .makeAlbum {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isTabBarHidden = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        isPresentingMakeAlbum = true
                    }
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTabBarHidden = false
                    isPresentingMakeAlbum = false
                    selectedTab = tab
                }
            }
            // 탭 전환 햅틱 피드백
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabBarView()
        .environmentObject(AppState())
}
