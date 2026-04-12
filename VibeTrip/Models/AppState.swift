//
//  AppState.swift
//  VibeTrip
//
//  Created by CHOI on 3/25/26.
//

import SwiftUI
import Combine

// MARK: - NotificationNavigationAction

// 알림 탭 시 이동할 화면
// NotificationView: 세팅, MainTabBarView: 처리
enum NotificationNavigationAction: Equatable {

    // 앨범 생성 실패: MakeAlbumView
    case openMakeAlbum

    // 앨범 생성 중: MakeAlbumLoadingView
    // TODO: 서버 연동 시, MakeAlbumViewModel 상태 보존 후 기존 로딩 화면 복귀 구현 
    case openAlbumCreationLoading

    // 앨범 생성 완료: AlbumDetailView
    case openAlbumDetail(albumId: String)

    // 홈 탭으로 이동: albumId 누락 등 상세 진입 불가 시 fallback
    case openHome
}

struct AppToastPayload: Equatable {
    let message: String
    let systemImageName: String?
}

// MARK: - AppState

// 앱 전역 상태 — EnvironmentObject로 모든 뷰에서 접근 가능
@MainActor final class AppState: ObservableObject {

    // nil: 확인 중, true: 로그인, false: 로그아웃
    @Published var isLoggedIn: Bool? = nil

    // 탭바 레드 닷 표시 여부
    // true: 새 알림 존재, false: 존재X or 탭 진입 후
    @Published var hasUnreadNotifications: Bool = false

    // 알림 탭 시 이동할 화면
    // NotificationView(세팅) -> MainTabBarView: onChange에서 화면 전환 처리 및 nil 초기화
    @Published var pendingNotificationAction: NotificationNavigationAction? = nil
    @Published var toastPayload: AppToastPayload? = nil

    // 특정 탭으로 강제 이동 요청 -> 앨범 삭제 후 홈 탭 복귀
    // nil 초기화: MainTabBarView -> onChange에서 처리
    @Published var pendingTabNavigation: AppTab? = nil

    // 생성 대기 화면: 화면 숨기기 시 MainPageView에 목록 새로고침을 요청하는 신호
    // MainTabBarView(송신) -> MainPageView(수신), 수신 즉시 false로 초기화
    @Published var needsAlbumRefresh: Bool = false

    // 푸시 수신 시 알림 목록 재조회 요청 신호
    @Published var needsNotificationRefresh: Bool = false

    // 포그라운드 FAILED 배너 수신 시 앨범 목록 조용히 갱신 요청 신호
    // AppDelegate(송신) -> MainTabBarView(수신), 수신 즉시 false로 초기화
    @Published var needsSilentAlbumRefresh: Bool = false

    // 앱 포그라운드 진입 시 미읽음/FAILED 알림 여부 확인 요청 신호
    // AppDelegate(송신) -> MainTabBarView(수신), 수신 즉시 false로 초기화
    @Published var needsActiveCheck: Bool = false

    // FCM COMPLETED 수신 시 설정 -> MainTabBarView에서 소비 후 nil 초기화
    @Published var fcmCompletedAlbumId: Int? = nil

    // 딥링크 수신 시 열린 AlbumDetailView 커버 dismiss 요청 신호
    // MainTabBarView(송신) -> MainPageView/MainTabBarView(수신), 처리 후 false로 초기화
    @Published var needsDismissAlbumDetail: Bool = false

    // MainPageView or MainTabBarView 경로로 AlbumDetailView 커버가 열려 있는지 여부
    // 딥링크 수신 시 기존 커버 유무 판단에 사용
    @Published var isAlbumDetailPresented: Bool = false

    // MainPageView 커버 dismiss 후 이동할 앨범 ID (nil: 대기 없음)
    // MainTabBarView(송신) -> MainPageView onDismiss에서 소비 후 nil 초기화
    @Published var pendingDeeplinkAlbumId: String? = nil

    // MainPageView 커버 dismiss 완료 시 MainTabBarView로 전달하는 앨범 ID 시그널
    // MainPageView onDismiss(송신) -> MainTabBarView onChange(수신) 후 nil 초기화
    @Published var deeplinkAlbumReadyToPresent: String? = nil

    // 딥링크 상세 뒤로가기 후 캐러셀을 해당 앨범 카드 위치로 이동
    // MainTabBarView onBackTap(송신) -> MainPageView onChange(수신) 후 nil 초기화
    @Published var pendingCarouselAlbumId: Int? = nil


    // APIClient.sessionExpiredPublisher 구독 유지용
    private var cancellables = Set<AnyCancellable>()

    init(apiClient: APIClientProtocol = APIClient.shared) {
        // refreshToken 만료 시 APIClient가 발행 -> 자동 로그아웃
        apiClient.sessionExpiredPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isLoggedIn = false }
            .store(in: &cancellables)
    }

    func showToast(message: String, systemImageName: String? = "exclamationmark.circle") {
        toastPayload = AppToastPayload(message: message, systemImageName: systemImageName)
    }

    func consumeToast() {
        toastPayload = nil
    }
}
