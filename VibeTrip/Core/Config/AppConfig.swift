//
//  AppConfig.swift
//  VibeTrip
//
//  Created by CHOI on 4/20/26.
//

import Foundation

// 빌드 구성(Debug/Release)별로 xcconfig에서 주입된 환경 값을 Info.plist를 통해 읽어오는 진입점
// - 값이 누락될 경우: 빌드 설정 문제이므로 'fatalError'로 즉시 중단하여 조기 감지
enum AppConfig {

    // MARK: - Public
    // debug: 개발용 | release: 배포용

    // 백엔드 서버 base URL
    static var serverURL: String {
        value(for: Key.serverURL)
    }

    // 카카오 네이티브 앱 키
    static var kakaoAppKey: String {
        value(for: Key.kakaoAppKey)
    }

    // MARK: - Private

    private enum Key {
        static let serverURL = "SERVER_URL"
        static let kakaoAppKey = "KAKAO_APP_KEY"
    }

    private static func value(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else {
            fatalError("AppConfig: Info.plist에 '\(key)' 값이 없습니다. xcconfig 설정을 확인하세요.")
        }
        return value
    }
}
