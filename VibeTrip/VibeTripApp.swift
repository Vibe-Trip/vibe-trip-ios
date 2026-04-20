//
//  VibeTripApp.swift
//  VibeTrip
//
//  Created by CHOI on 2/28/26.
//

import SwiftUI
import AVFoundation
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import KakaoSDKCommon
import KakaoSDKAuth

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private enum Constants {
        static let notificationKey = "isNotificationEnabled"
    }

    // appState 설정 전에 수신된 콜백 신호를 버퍼링하기 위한 프로퍼티
    private struct PendingReceivePayload {
        let navigationAction: NotificationNavigationAction?
    }
    private var pendingNeedsActiveCheck = false
    private var pendingReceivePayload: PendingReceivePayload? = nil

    weak var appState: AppState? {
        didSet {
            guard let appState else { return }
            if pendingNeedsActiveCheck {
                pendingNeedsActiveCheck = false
                Task { @MainActor in appState.needsActiveCheck = true }
            }
            if let pending = pendingReceivePayload {
                pendingReceivePayload = nil
                Task { @MainActor in
                    appState.needsNotificationRefresh = true
                    appState.pendingNotificationAction = pending.navigationAction
                }
            }
        }
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 앨범 커버 이미지 반복 다운로드 방지: 메모리 50MB / 디스크 200MB
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )

        // 오디오 세션 설정: 무음 모드에서도 앱 내 배경음악 재생
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        // Firebase 초기화
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        // TODO: FCM 토큰 만료/회전으로 알림 수신 불가 이슈가 발생 시, MessagingDelegate + didReceiveRegistrationToken 재연동
        
        // 카카오 SDK 초기화
        KakaoSDK.initSDK(appKey: AppConfig.kakaoAppKey)

        let isNotificationEnabled = UserDefaults.standard.object(forKey: Constants.notificationKey) as? Bool ?? true

        // 사용자 설정이 켜져 있을 때만 푸시 권한 요청 및 APNs 등록
        if isNotificationEnabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                guard granted else { return }
                DispatchQueue.main.async {
                    // 알림 토글 on: APNs 원격 알림 등록 요청
                    application.registerForRemoteNotifications()
                }
            }
        } else {
            // 알림 토글 off: 앱 런치 시에도 원격 알림 등록 유지X
            application.unregisterForRemoteNotifications()
        }

        return true
    }

    // APNS 토큰 -> Firebase에 전달
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // 앱 포그라운드 전환 시: 미읽음/FAILED 알림 여부 확인 요청
    func applicationDidBecomeActive(_ application: UIApplication) {
        if let appState {
            Task { @MainActor in appState.needsActiveCheck = true }
        } else {
            pendingNeedsActiveCheck = true
        }
    }

    // 포그라운드 푸시: 인앱 배너 표시 + 알림 목록 갱신 신호
    // FAILED 타입: 앨범 목록 조용히 갱신 신호 추가 전송
    // COMPLETED 타입: FCM 완료 신호 전달 -> MainTabBarView에서 앨범 완료 처리
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        let payload = FCMPayload.decode(from: userInfo)
        Task { @MainActor in
            appState?.needsNotificationRefresh = true
            if payload?.type == "FAILED" {
                appState?.needsSilentAlbumRefresh = true
            }
            if payload?.type == "COMPLETED", let albumId = payload?.data?.albumId {
                appState?.fcmCompletedAlbumId = albumId
            }
        }
        completionHandler([.banner, .list, .sound, .badge])
    }

    // 백그라운드 및 종료 상태 푸시 탭: payload에 맞는 화면 이동 전달
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let navigationAction = FCMPayload.decode(from: userInfo)?.toNavigationAction()
        if let appState {
            Task { @MainActor in
                appState.needsNotificationRefresh = true
                appState.pendingNotificationAction = navigationAction
            }
        } else {
            pendingReceivePayload = PendingReceivePayload(navigationAction: navigationAction)
        }
        completionHandler()
    }
}

@main
struct VibeTripApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var appState = AppState()
    @StateObject private var backgroundMusicService = BackgroundMusicService()

    private let keychainService: KeychainServiceProtocol = KeychainService()

    var body: some Scene {
        WindowGroup {
            Group {
                switch appState.isLoggedIn {
                case .none:
                    // Keychain 확인 전: 빈화면
                    Color(.systemBackground).ignoresSafeArea()
                case .some(false):
                    LoginView()
                        .environmentObject(appState)
                        .onOpenURL { url in
                            // 카카오톡 앱 로그인 후 돌아오는 URL 처리 (취소 포함)
                            if AuthApi.isKakaoTalkLoginUrl(url) {
                                _ = AuthController.handleOpenUrl(url: url)
                            }
                        }
                case .some(true):
                    MainTabBarView()
                        .environmentObject(appState)
                        .environmentObject(backgroundMusicService)
                }
            }
            .task {
                // 앱 진입 시 Keychain 토큰 유무로 초기 화면 결정
                appState.isLoggedIn = (try? keychainService.getAccessToken()) != nil
                delegate.appState = appState
            }
        }
    }
}
