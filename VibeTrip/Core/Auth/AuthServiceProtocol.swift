//
//  AuthServiceProtocol.swift
//  VibeTrip
//
//  Created by CHOI on 3/15/26.
//


// 소셜 로그인 및 백엔드 인증 기능 인터페이스 정의

import Foundation

// MARK: - 소셜 로그인 프로토콜

// 카카오 로그인 인터페이스
protocol KakaoAuthServiceProtocol {
    /// 카카오 로그인 실행: accessToken 반환
    /// 사용자 취소 시: LoginError.cancelled throw
    func login() async throws -> String
}

// 애플 로그인 인터페이스
protocol AppleAuthServiceProtocol {
    /// 애플 로그인 실행: identityToken + fullName 반환
    /// 사용자 취소 시: LoginError.cancelled throw
    func login() async throws -> (identityToken: String, fullName: String?)
}

// MARK: - 백엔드 인증 프로토콜

// 백엔드 JWT 발급 인터페이스
protocol BackendAuthServiceProtocol {
    /// 소셜 토큰 + deviceId + fcmToken
    /// token: accessToken(카카오) or identityToken(애플)
    /// provider: 로그인 제공자(카카오 or 애플)
    /// deviceId: 기기 고유 식별자
    /// fcmToken: FCM 푸시 토큰
    /// fullName, email: (애플) 최초 로그인 시 값 제공, 그 이후 nil
    func authenticate(token: String, provider: LoginProvider, deviceId: String, fcmToken: String, fullName: String?) async throws -> AuthToken
}

extension BackendAuthServiceProtocol {
    // 카카오 로그인: fullName X
    func authenticate(token: String, provider: LoginProvider, deviceId: String, fcmToken: String) async throws -> AuthToken {
        try await authenticate(token: token, provider: provider, deviceId: deviceId, fcmToken: fcmToken, fullName: nil)
    }
}

// MARK: - 로그인 제공자 타입

enum LoginProvider: String {
    case kakao = "kakao"
    case apple = "apple"
}
