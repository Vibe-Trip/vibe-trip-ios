//
//  MainTabBarView.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI
import UIKit
import UserNotifications

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
        case .makeAlbum:    return "rectangle.stack.fill.badge.plus.fill"
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
    @State private var creatingAlbumId: Int? = nil                                             // 생성 요청한 앨범 ID (완료 감지용)
    @State private var albumLoadingError: MakeAlbumViewModel.AlbumCreationLoadingError? = nil  // 에러 팝업 종류
    @State private var albumRetryAction: (() -> Void)? = nil                                  // 네트워크 오류 재시도 클로저
    @State private var hiddenLoadingToastMessage: String? = nil
    @State private var hiddenLoadingToastIconName: String? = nil
    // 완료 알림 상세 진입 전 데이터 조회 중 화면 전환 가리는 상태
    @State private var isResolvingAlbumDetail = false
    @State private var presentedAlbumDetail: PendingAlbumDetailPresentation? = nil

    // MainTabBarView 자체 커버(presentedAlbumDetail) dismiss 완료 후 진입할  albumId
    // fullScreenCover onDismiss에서 소비
    @State private var ownCoverPendingAlbumId: String? = nil

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
        mainStackWithHandlers
        .onAppear {
            if appState.needsNotificationRefresh {
                appState.needsNotificationRefresh = false
                Task { await processNotificationRefresh() }
            }
            if let action = appState.pendingNotificationAction {
                appState.pendingNotificationAction = nil
                handlePendingNotificationAction(action)
            }
            guard appState.needsActiveCheck else { return }
            appState.needsActiveCheck = false
            Task { await processActiveCheck() }
        }
        // 앱 포그라운드 전환 시: 미읽음/FAILED 알림 여부 확인 후 red dot 및 앨범 목록 갱신
        .onChange(of: appState.needsActiveCheck) { _, needsCheck in
            guard needsCheck else { return }
            appState.needsActiveCheck = false
            Task { await processActiveCheck() }
        }
        // 포그라운드 FCM COMPLETED 수신 시: 해당 앨범 폴링 취소 후 1회 조회로 완료 처리
        .onChange(of: appState.fcmCompletedAlbumId) { _, albumId in
            guard let albumId else { return }
            appState.fcmCompletedAlbumId = nil
            Task { await mainPageViewModel.handleAlbumCompleted(albumId: albumId) }
        }
        .fullScreenCover(item: $presentedAlbumDetail, onDismiss: {
            // 딥링크로 인한 dismiss인 경우: dismiss 완료 직후 새 앨범 상세로 진입
            guard let albumId = ownCoverPendingAlbumId else { return }
            ownCoverPendingAlbumId = nil
            Task { await presentAlbumDetailOverlay(albumId: albumId) }
        }) { presentation in
            AlbumDetailView(
                displayModel: presentation.displayModel,
                onBackTap: {
                    appState.pendingCarouselAlbumId = presentation.displayModel.albumId
                    presentedAlbumDetail = nil
                    isTabBarHidden = false
                },
                onEditSaved: { outcome in
                    let albumId = presentation.displayModel.albumId
                    presentedAlbumDetail = nil
                    selectedTab = .home
                    isTabBarHidden = false
                    // 재생성 저장: 해당 앨범 스켈레톤 전환 + 폴링 재시작 대기
                    if case .regenerated = outcome {
                        mainPageViewModel.markAlbumNotReady(albumId: albumId)
                    }
                    // 위치 리셋 없이 조용한 갱신 + 해당 앨범 카드로 이동
                    appState.needsSilentAlbumRefresh = true
                    appState.pendingCarouselAlbumId = albumId
                },
                onDeleteAlbumTap: {
                    presentedAlbumDetail = nil
                    selectedTab = .home
                    isTabBarHidden = false
                    appState.needsAlbumRefresh = true
                }
            )
            // albumId 기준으로 view 재생성 강제 -> @State/@StateObject 확실히 초기화
            .id(presentation.displayModel.albumId)
            .onAppear {
                // 마스크 뒤에서 홈 탭 전환 + 해당 앨범 캐러셀 위치 세팅
                // -> 뒤로가기 시 알림 탭 노출 없이 홈의 해당 앨범으로 복귀 보장
                DispatchQueue.main.async {
                    Task { await mainPageViewModel.refreshAlbumsWithoutClearing() }
                    appState.pendingCarouselAlbumId = presentation.displayModel.albumId
                    selectedTab = .home
                    isResolvingAlbumDetail = false
                }
            }
        }
    }

    // MARK: - Main Stack

    // 타입 체커 부하 분산을 위해 modifier 체인을 두 단계로 분리
    private var mainStackWithHandlers: some View {
        mainStack
        .animation(.easeInOut(duration: 0.24), value: isPresentingMakeAlbum)
        .animation(.easeInOut(duration: 0.22), value: isTabBarHidden)
        .animation(.easeInOut(duration: 0.2), value: hiddenLoadingToastMessage)
        .onChange(of: selectedTab) { oldTab, newTab in
            if newTab == .notification {
                notificationViewModel.clearUnreadBadge()
            }
            guard oldTab == .notification, newTab != .notification else { return }
            notificationViewModel.markAllAsRead()
        }
        .onChange(of: isPresentingMakeAlbum) { _, isPresenting in
            guard isPresenting, selectedTab == .notification else { return }
            notificationViewModel.markAllAsRead()
        }
        .onChange(of: isPresentingLoadingView) { _, isPresenting in
            guard isPresenting, selectedTab == .notification else { return }
            notificationViewModel.clearUnreadBadge()
        }
        .onChange(of: appState.needsNotificationRefresh) { _, needsRefresh in
            guard needsRefresh else { return }
            appState.needsNotificationRefresh = false
            Task { await processNotificationRefresh() }
        }
        .onChange(of: appState.pendingNotificationAction) { _, action in
            guard let action else { return }
            appState.pendingNotificationAction = nil
            handlePendingNotificationAction(action)
        }
        // presentedAlbumDetail 변화 시 AppState 동기화: 딥링크 수신 시 기존 커버 유무 판단에 사용
        .onChange(of: presentedAlbumDetail?.id) { _, detailId in
            appState.isAlbumDetailPresented = detailId != nil
        }
        // MainPageView 커버 dismiss 완료 시그널 수신: 새 앨범 상세로 진입
        .onChange(of: appState.deeplinkAlbumReadyToPresent) { _, albumId in
            guard let albumId else { return }
            appState.deeplinkAlbumReadyToPresent = nil
            Task { await presentAlbumDetailOverlay(albumId: albumId) }
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
        // 앨범 생성 완료 감지 (FCM·폴링 공통): 같은 albumId 재완료도 이벤트로 처리
        .onReceive(mainPageViewModel.$lastCompletedAlbumId) { completedId in
            guard let completedId,
                  let creatingId = creatingAlbumId,
                  completedId == creatingId,
                  isPresentingLoadingView else { return }
            autoHideLoadingViewOnCompletion()
        }
    }

    // ZStack 콘텐츠를 body에서 분리
    private var mainStack: some View {
        ZStack {

            // 기본 배경색
            Color(UIColor.systemBackground).ignoresSafeArea()

            ZStack {
                // 홈: 항상 마운트 유지 -> @State currentIndex 등 탭 전환에도 보존
                MainPageView(viewModel: mainPageViewModel)
                    .opacity(selectedTab == .home ? 1 : 0)
                    .allowsHitTesting(selectedTab == .home)

                // 나머지 탭: 기존 조건부 렌더링 유지 -> 불필요한 선제 네트워크 호출 방지
                if selectedTab == .notification {
                    NotificationView(viewModel: notificationViewModel)
                } else if selectedTab == .myPage {
                    MyPageView()
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
                        // 생성 성공: 화면 숨기기 버튼 활성화 + 완료 감지용 albumId 저장
                        isAlbumCreating = false
                        albumLoadingError = nil
                        creatingAlbumId = albumId
                        // 푸시 미수신/지연 대비: 생성 요청한 앨범 완료 감시 바로 시작
                        Task { await mainPageViewModel.handleAlbumCompleted(albumId: albumId) }
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
                            hiddenLoadingToastIconName = "exclamationmark.circle"
                            hiddenLoadingToastMessage = "앨범을 제작하고 있어요. 잠시만 기다려 주세요!"
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
                        showsNotificationBadge: notificationViewModel.showsUnreadBadge,
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
                                 systemImageName: hiddenLoadingToastIconName)
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
            hiddenLoadingToastIconName = "exclamationmark.circle"
            hiddenLoadingToastMessage = "앨범 만들기를 취소했어요."
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeInOut(duration: 0.22)) {
                isTabBarHidden = false
            }
        }
    }

    // 생성 완료 감지 시 자동으로 로딩 화면 숨기기
    private func autoHideLoadingViewOnCompletion() {
        let completedAlbumId = creatingAlbumId
        creatingAlbumId = nil
        selectedTab = .home
        withAnimation(.easeInOut(duration: 0.24)) {
            isPresentingLoadingView = false
            isPresentingMakeAlbum = false
            isTabBarHidden = true
        }

        // 상세 진입 전 목록 동기화로 카드/캐러셀 상태를 맞추고, 뒤로가기 시 해당 앨범 위치를 복원
        guard let albumId = completedAlbumId else { return }
        Task {
            await mainPageViewModel.refreshAlbumsWithoutClearing()
            appState.pendingCarouselAlbumId = albumId
            await presentAlbumDetailOverlay(albumId: String(albumId))
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

    private func processNotificationRefresh() async {
        await notificationViewModel.handleIncomingNotification(
            isViewingNotificationTab: selectedTab == .notification
        )
    }

    // 앱 포그라운드 복귀 시 알림 동기화 처리
    private func processActiveCheck() async {
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        await notificationViewModel.handleAppBecameActive(
            isViewingNotificationTab: selectedTab == .notification,
            hasDeliveredNotifications: !delivered.isEmpty
        )

        // 백그라운드에서 수신해둔 미처리 COMPLETED 알림 소비 (알림 탭 없이 직접 진입한 경우)
        await consumeDeliveredCompletedNotifications()
        // 앱 직접 복귀 경로: COMPLETED 감지를 위해 1회 동기화
        // pendingNotificationAction이 설정된 경우 딥링크 경로에서 이미 갱신 처리 -> 중복 스킵
        if appState.pendingNotificationAction == nil {
            await mainPageViewModel.refreshAlbumsWithoutClearing()
        }
    }

    private func handlePendingNotificationAction(_ action: NotificationNavigationAction) {
        switch action {
        case .openMakeAlbum:
            Task { await mainPageViewModel.refreshAlbumsWithoutClearing() }
            withAnimation(.easeInOut(duration: 0.18)) {
                isTabBarHidden = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeInOut(duration: 0.24)) {
                    isPresentingMakeAlbum = true
                }
            }
        case .openAlbumCreationLoading(let albumId):
            if let albumId, let id = Int(albumId) {
                creatingAlbumId = id
            }
            // isPresentingLoadingView: Task 시작 전에 동기로 확정 -> 레이스 방지
            withAnimation(.easeInOut(duration: 0.18)) {
                isTabBarHidden = true
            }
            withAnimation(.easeInOut(duration: 0.24)) {
                isPresentingLoadingView = true
            }
            // 상태 확정 후 완료 감시 시작
            if let albumId, let id = Int(albumId) {
                Task { await mainPageViewModel.handleAlbumCompleted(albumId: id) }
            }
        case .openAlbumDetail(let albumId):
            // 로딩뷰 체류 중 완료 알림 탭 시 onChange 리스너 가드를 선제 차단
            creatingAlbumId = nil
            if let numericAlbumId = Int(albumId) {
                Task { await mainPageViewModel.handleAlbumCompleted(albumId: numericAlbumId) }
            }

            let hadPresentedDetail = presentedAlbumDetail != nil
            let hadSelectedAlbum = !hadPresentedDetail && appState.isAlbumDetailPresented

            withAnimation(.easeInOut(duration: 0.24)) {
                isPresentingLoadingView = false
                isPresentingMakeAlbum = false
                isTabBarHidden = true
            }

            if hadPresentedDetail {
                ownCoverPendingAlbumId = albumId
                presentedAlbumDetail = nil
            } else if hadSelectedAlbum {
                appState.pendingDeeplinkAlbumId = albumId
                appState.needsDismissAlbumDetail = true
            } else {
                Task { await presentAlbumDetailOverlay(albumId: albumId) }
            }
        case .openHome:
            selectedTab = .home
        }
    }

    // 백그라운드에서 수신했으나 탭되지 않은 COMPLETED 알림을 찾아 handleAlbumCompleted로 소비
    // 처리된 알림은 알림 센터에서 제거하여 중복 처리 방지
    private func consumeDeliveredCompletedNotifications() async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()
        var processedIdentifiers: [String] = []
        for notification in delivered {
            let userInfo = notification.request.content.userInfo
            guard let payload = FCMPayload.decode(from: userInfo),
                  payload.type == "COMPLETED",
                  let albumId = payload.data?.albumId else { continue }
            await mainPageViewModel.handleAlbumCompleted(albumId: albumId)
            processedIdentifiers.append(notification.request.identifier)
        }
        if !processedIdentifiers.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: processedIdentifiers)
        }
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
                hiddenLoadingToastIconName = "exclamationmark.circle"
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
    let showsNotificationBadge: Bool
    // 앨범 만들기 진입 전 팝업/분기 처리
    let onMakeAlbumTap: () -> Void

    private enum Layout {
        static let iconSize: CGFloat      = 26   // 탭 아이콘 크기
        static let makeAlbumIconSize: CGFloat = 30 // 앨범 만들기 탭 아이콘 크기
        static let iconSlotSize: CGFloat = 30 // 탭별 아이콘 영역 높이 고정(레이블 정렬)
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
        let iconSize = tab == .makeAlbum ? Layout.makeAlbumIconSize : Layout.iconSize

        VStack(spacing: 3) {
            // 선택: filled 아이콘 / 미선택: outline 아이콘
            Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .frame(width: Layout.iconSlotSize, height: Layout.iconSlotSize)
                .overlay(alignment: .topTrailing) {
                    if tab == .notification && showsNotificationBadge {
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
