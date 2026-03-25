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
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Firebase 초기화
        FirebaseApp.configure()
        
        // 카카오 SDK 초기화
        if let appKey = Bundle.main.infoDictionary?["KAKAO_APP_KEY"] as? String {
            KakaoSDK.initSDK(appKey: appKey)
        }

        // 푸시 알림 권한 요청 + APNS 등록 (FCM 토큰 발급 전제조건)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        application.registerForRemoteNotifications()

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
