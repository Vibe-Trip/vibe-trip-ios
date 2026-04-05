//
//  VibeTripApp.swift
//  VibeTrip
//
//  Created by CHOI on 2/28/26.
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import KakaoSDKCommon
import KakaoSDKAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    private enum Constants {
        static let notificationKey = "isNotificationEnabled"
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 앨범 커버 이미지 반복 다운로드 방지: 메모리 50MB / 디스크 200MB
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )

        // Firebase 초기화
        FirebaseApp.configure()
        
        // 카카오 SDK 초기화
        if let appKey = Bundle.main.infoDictionary?["KAKAO_APP_KEY"] as? String {
            KakaoSDK.initSDK(appKey: appKey)
        }

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

}

@main
struct VibeTripApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var appState = AppState()

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
                }
            }
            .task {
                // 앱 진입 시 Keychain 토큰 유무로 초기 화면 결정
                appState.isLoggedIn = (try? keychainService.getAccessToken()) != nil
            }
        }
    }
}
