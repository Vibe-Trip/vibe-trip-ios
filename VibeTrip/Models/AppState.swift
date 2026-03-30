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
    // TODO: 서버 연동 시, albumId 기반 AlbumDetailView 라우팅 구현
    case openAlbumDetail(albumId: String)
}

// MARK: - AppState

// 앱 전역 상태 — EnvironmentObject로 모든 뷰에서 접근 가능
@MainActor final class AppState: ObservableObject {

    // nil: 확인 중, true: 로그인, false: 로그아웃
    @Published var isLoggedIn: Bool? = nil

    // 탭바 레드 닷 표시 여부
    // true: 새 알림 존재, false: 존재X or 탭 진입 후
    // TODO: 서버 연동 시, FCM 푸시 수신 시 AppDelegate에서 true
    @Published var hasUnreadNotifications: Bool = false

    // 알림 탭 시 이동할 화면
    // NotificationView(세팅) -> MainTabBarView: onChange에서 화면 전환 처리 및 nil 초기화
    @Published var pendingNotificationAction: NotificationNavigationAction? = nil
}
