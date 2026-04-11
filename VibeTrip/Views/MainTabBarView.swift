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

    private enum Constants {
        static let hideLoadingToastBottomPadding: CGFloat = 88
        static let hideLoadingToastAnimationDuration: Double = 3.0
        static let deletedAlbumToastMessage = "이미 삭제된 앨범 입니다"
    }

    // 현재 선택된 탭 (기본값: 홈)
    @State private var selectedTab: AppTab = .home
    @State private var isTabBarHidden = false
    @State private var isPresentingMakeAlbum = false
    @State private var isPresentingLoadingView = false

    // 앨범 생성 로딩 관련 상태
    @State private var isAlbumCreating = false                                                  // 요청 진행 중 여부
    @State private var albumLoadingError: MakeAlbumViewModel.AlbumCreationLoadingError? = nil  // 에러 팝업 종류
    @State private var albumRetryAction: (() -> Void)? = nil                                  // 네트워크 오류 재시도 클로저
    @State private var hiddenLoadingToastMessage: String? = nil
    @State private var hiddenLoadingToastShowsIcon = false
    // 완료 알림 상세 진입 전 데이터 조회 중 화면 전환 가리는 상태
    @State private var isResolvingAlbumDetail = false
    @State private var presentedAlbumDetail: PendingAlbumDetailPresentation? = nil

    @EnvironmentObject private var appState: AppState
    @StateObject private var notificationViewModel = NotificationViewModel()
    @StateObject private var mainPageViewModel = MainPageViewModel()

    private let makeAlbumTransition = AnyTransition.move(edge: .trailing).combined(with: .opacity)
    private let tabBarTransition = AnyTransition.move(edge: .bottom).combined(with: .opacity)
    private let albumService: AlbumServiceProtocol

    init(albumService: AlbumServiceProtocol = AlbumService()) {
        self.albumService = albumService
    }

    var body: some View {
        ZStack {

            // 기본 배경색
            Color(UIColor.systemBackground).ignoresSafeArea()

            Group {
                // 탭 전환
                switch selectedTab {
                case .home:
                    MainPageView(viewModel: mainPageViewModel)
                case .notification:
                    NotificationView(viewModel: notificationViewModel)
                case .myPage:
                    MyPageView()
                case .makeAlbum:
                    Color(UIColor.systemBackground).ignoresSafeArea()
                }
            }

            if isPresentingMakeAlbum {
                MakeAlbumView(
                    onExit: {
                        // 앨범 생성 이탈: MakeAlbumView 닫고 진입 전 탭 복귀
                        withAnimation(.easeInOut(duration: 0.24)) {
                            isPresentingMakeAlbum = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                isTabBarHidden = false
                            }
                        }
                    },
                    onCreationStarted: {
                        // API 호출 시작: LoadingView 노출, MakeAlbumView는 메모리에 유지
                        isAlbumCreating = true
                        withAnimation(.easeInOut(duration: 0.24)) {
                            isPresentingLoadingView = true
                        }
                    },
                    onCreationSuccess: { albumId in
                        // 생성 성공: 화면 숨기기 버튼 활성화
                        isAlbumCreating = false
                        albumLoadingError = nil
                    },
                    onNetworkError: { retryAction in
                        // 네트워크 오류: 재시도 클로저 보관 후 팝업 표시
                        isAlbumCreating = false
                        albumRetryAction = retryAction
                        albumLoadingError = .networkError
                    },
                    onFatalError: {
                        // 재시도 불가 오류: 확인 팝업 표시
                        isAlbumCreating = false
                        albumLoadingError = .fatalError
                    }
                )
                .transition(makeAlbumTransition)
                .zIndex(1)
            }

            if isPresentingLoadingView {
                MakeAlbumLoadingView(
                    onHide: {
                        // 화면 숨기기: 메인 페이지로 복귀 + 앨범 목록 재조회
                        selectedTab = .home
                        // MainPageView가 뷰 계층에 추가된 후 신호를 감지할 수 있도록 다음 런루프로 지연
                        DispatchQueue.main.async { appState.needsAlbumRefresh = true }
                        withAnimation(.easeInOut(duration: 0.24)) {
                            isPresentingLoadingView = false
                            isPresentingMakeAlbum = false
                            hiddenLoadingToastShowsIcon = false
                            hiddenLoadingToastMessage = "음악을 백그라운드에서 만들고 있어요. \n알림 리스트에서 확인해 보세요!"
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                isTabBarHidden = false
                            }
                        }
                    },
                    isCreating: isAlbumCreating,
                    loadingError: albumLoadingError,
                    onRetry: {
                        // 재시도: 로딩 상태 복원 후 저장된 클로저 실행
                        isAlbumCreating = true
                        albumLoadingError = nil
                        albumRetryAction?()
                    },
                    onDismissToMain: {
                        // 팝업 dismiss: 메인 페이지로 이동
                        dismissAlbumCreationToMain()
                    }
                )
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
                        isPresentingMakeAlbum: $isPresentingMakeAlbum,
                        // 탭바 내부에서 직접 진입하지 않고, 상위에서 팝업/진입 가드를 판단
                        onMakeAlbumTap: handleMakeAlbumTabTap
                    )
                    .transition(tabBarTransition)
                }
            }

            if let hiddenLoadingToastMessage {
                VStack {
                    Spacer()
                    AppToastView(message: hiddenLoadingToastMessage,
                                 systemImageName: hiddenLoadingToastShowsIcon ? "exclamationmark.circle" : nil)
                        .padding(.bottom, Constants.hideLoadingToastBottomPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.hideLoadingToastAnimationDuration) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    self.hiddenLoadingToastMessage = nil
                                }
                            }
                        }
                }
                .zIndex(3)
            }

            // 완료 알림에서 상세 진입 준비 중 홈 전환 과정을 마스킹
            if isResolvingAlbumDetail {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .controlSize(.large)
                    }
                    .zIndex(4)
            }

        }
        .animation(.easeInOut(duration: 0.24), value: isPresentingMakeAlbum)
        .animation(.easeInOut(duration: 0.22), value: isTabBarHidden)
        .animation(.easeInOut(duration: 0.2), value: hiddenLoadingToastMessage)
        // 알림 탭 시, 화면 이동
        .onChange(of: appState.pendingNotificationAction) { _, action in
            guard let action else { return }
            switch action {
            case .openMakeAlbum:
                // 생성 실패: MakeAlbumView 진입 전 탭 상태 무관하게 앨범 목록 즉시 갱신
                Task { await mainPageViewModel.refreshAlbumsWithoutClearing() }
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
            case .openAlbumDetail(let albumId):
                // 기존에 열린 상세 커버 여부를 변경 전 시점에 캡처
                let hadOpenDetail = appState.isAlbumDetailPresented

                // MainTabBarView 경유 커버 및 MainPageView 경유 커버 모두 dismiss 처리
                presentedAlbumDetail = nil
                appState.needsDismissAlbumDetail = true

                withAnimation(.easeInOut(duration: 0.24)) {
                    isPresentingLoadingView = false
                    isPresentingMakeAlbum = false
                    isTabBarHidden = true
                }

                if hadOpenDetail {
                    // 기존 커버가 있었으면 dismiss 애니메이션 완료 후 새 상세 진입
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        appState.needsDismissAlbumDetail = false
                        Task { await presentAlbumDetailOverlay(albumId: albumId) }
                    }
                } else {
                    // 열린 커버 없으면 즉시 진입
                    appState.needsDismissAlbumDetail = false
                    Task { await presentAlbumDetailOverlay(albumId: albumId) }
                }
            }
            appState.pendingNotificationAction = nil
        }
        // presentedAlbumDetail 변화 시 AppState 동기화: 딥링크 수신 시 기존 커버 유무 판단에 사용
        .onChange(of: presentedAlbumDetail) { _, detail in
            appState.isAlbumDetailPresented = detail != nil
        }
        // 앨범 삭제 등 특정 탭 이동 요청 처리
        .onChange(of: appState.pendingTabNavigation) { _, tab in
            guard let tab else { return }
            selectedTab = tab
            appState.pendingTabNavigation = nil
        }
        // 포그라운드 FAILED 배너 무시 시: 탭 상태 무관하게 앨범 목록 조용히 갱신
        .onChange(of: appState.needsSilentAlbumRefresh) { _, needsRefresh in
            guard needsRefresh else { return }
            appState.needsSilentAlbumRefresh = false
            Task { await mainPageViewModel.refreshAlbumsWithoutClearing() }
        }
        // 앱 포그라운드 전환 시: 미읽음/FAILED 알림 여부 확인 후 red dot 및 앨범 목록 갱신
        .onChange(of: appState.needsActiveCheck) { _, needsCheck in
            guard needsCheck else { return }
            appState.needsActiveCheck = false
            Task {
                let result = await notificationViewModel.checkUnread()
                if result.hasUnread { appState.hasUnreadNotifications = true }
                if result.hasFailed { await mainPageViewModel.refreshAlbumsWithoutClearing() }
            }
        }
        // 포그라운드 FCM COMPLETED 수신 시: 해당 앨범 폴링 취소 후 1회 조회로 완료 처리
        .onChange(of: appState.fcmCompletedAlbumId) { _, albumId in
            guard let albumId else { return }
            appState.fcmCompletedAlbumId = nil
            Task { await mainPageViewModel.handleAlbumCompleted(albumId: albumId) }
        }
        .fullScreenCover(item: $presentedAlbumDetail) { presentation in
            AlbumDetailView(
                displayModel: presentation.displayModel,
                onBackTap: {
                    presentedAlbumDetail = nil
                    selectedTab = .home
                    isTabBarHidden = false
                },
                onEditSaved: { _ in
                    presentedAlbumDetail = nil
                    selectedTab = .home
                    isTabBarHidden = false
                    appState.needsAlbumRefresh = true
                },
                onDeleteAlbumTap: {
                    presentedAlbumDetail = nil
                    selectedTab = .home
                    isTabBarHidden = false
                    appState.needsAlbumRefresh = true
                }
            )
            .onAppear {
                // 해당 앨범 상세페이지 이동 후 탭 전환
                DispatchQueue.main.async {
                    Task { await mainPageViewModel.refreshAlbumsWithoutClearing() }
                    // 상세 애니메이션 이후에 마스크를 해제 -> 탭 전환 노출 방지
                    isResolvingAlbumDetail = false
                }
            }
        }
    }

    // MARK: - Helpers

    // 앨범 생성 관련 모든 뷰/상태를 초기화하고 홈 탭으로 복귀
    private func dismissAlbumCreationToMain() {
        selectedTab = .home
        isAlbumCreating = false
        albumLoadingError = nil
        albumRetryAction = nil
        withAnimation(.easeInOut(duration: 0.24)) {
            isPresentingLoadingView = false
            isPresentingMakeAlbum = false
            hiddenLoadingToastShowsIcon = true
            hiddenLoadingToastMessage = "앨범 생성이 취소되었습니다."
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeInOut(duration: 0.22)) {
                isTabBarHidden = false
            }
        }
    }

    private func presentMakeAlbumFlow() {
        withAnimation(.easeInOut(duration: 0.18)) {
            isTabBarHidden = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: 0.24)) {
                isPresentingMakeAlbum = true
            }
        }
    }

    private func handleMakeAlbumTabTap() {
        guard !isPresentingMakeAlbum else { return }
        presentMakeAlbumFlow()
    }

    // 완료 알림 albumId로 단일 앨범 조회 후 해당 상세페이지 이동
    private func presentAlbumDetailOverlay(albumId: String) async {
        guard let id = Int(albumId) else { return }
        await MainActor.run { isResolvingAlbumDetail = true }

        guard let detail = try? await albumService.fetchAlbum(albumId: id) else {
            await MainActor.run {
                // 조회 실패 시 홈으로 복귀하고 전환 상태만 정리
                selectedTab = .home
                isTabBarHidden = false
                isResolvingAlbumDetail = false
                hiddenLoadingToastShowsIcon = true
                hiddenLoadingToastMessage = Constants.deletedAlbumToastMessage
            }
            return
        }

        let displayModel = AlbumDetailDisplayModel(
            albumId: id,
            title: detail.title ?? "",
            destination: detail.region,
            dateText: "\(formatDate(detail.travelStartDate)) - \(formatDate(detail.travelEndDate))",
            coverImageUrl: detail.coverImageUrl,
            contentState: .empty,
            musicUrl: detail.musicUrl
        )

        await MainActor.run {
            // 상세페이지 먼저 표시 -> 배경에서 탭 전환이 보이지 않게 처리
            presentedAlbumDetail = PendingAlbumDetailPresentation(displayModel: displayModel)
        }
    }

    private func formatDate(_ raw: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        let output = DateFormatter()
        output.locale = Locale(identifier: "ko_KR")
        output.dateFormat = "yyyy년 M월 d일"
        guard let date = input.date(from: raw) else { return raw }
        return output.string(from: date)
    }
}

private struct PendingAlbumDetailPresentation: Identifiable {
    let displayModel: AlbumDetailDisplayModel
    var id: Int { displayModel.albumId }
}

// MARK: - LiquidGlassTabBar

struct LiquidGlassTabBar: View {

    @Binding var selectedTab: AppTab
    @Binding var isTabBarHidden: Bool
    @Binding var isPresentingMakeAlbum: Bool
    // 앨범 만들기 진입 전 팝업/분기 처리
    let onMakeAlbumTap: () -> Void

    @EnvironmentObject private var appState: AppState

    private enum Layout {
        static let iconSize: CGFloat      = 25   // 탭 아이콘 크기
        static let barHeight: CGFloat     = 60   // 탭바 높이
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
                onMakeAlbumTap()
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
