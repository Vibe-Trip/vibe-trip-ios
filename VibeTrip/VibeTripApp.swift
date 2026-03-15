//
//  VibeTripApp.swift
//  VibeTrip
//
//  Created by CHOI on 2/28/26.
//

import SwiftUI
import KakaoSDKCommon
import KakaoSDKAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        
        // 카카오 SDK 초기화
        if let appKey = Bundle.main.infoDictionary?["KAKAO_APP_KEY"] as? String {
            KakaoSDK.initSDK(appKey: appKey)
        }
        
        return true
    }
    
}

@main
struct VibeTripApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            LoginView()
                .onOpenURL { url in
                    // 카카오톡 앱 로그인 후 돌아오는 URL 처리 (취소 포함)
                    if AuthApi.isKakaoTalkLoginUrl(url) {
                        _ = AuthController.handleOpenUrl(url: url)
                    }
                }
        }
    }
}
