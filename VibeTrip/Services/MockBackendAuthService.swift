//
//  MockBackendAuthService.swift
//  VibeTrip
//
//  Created by CHOI on 3/15/26.
//

// 테스트용(성공 case)

import Foundation

#if DEBUG
final class MockBackendAuthService: BackendAuthServiceProtocol {

    // nil: 성공
    // .networkError: 네트워크 에러 (토스트)
    // .timeout: 타임아웃 에러 (팝업)
    // .accountBlocked: 계정 차단 (팝업)
    
    var simulatedError: LoginError? = nil

    // 네트워크 딜레이 시뮬 (기본 1초)
    var delay: UInt64 = 1_000_000_000

    func authenticate(token: String, provider: LoginProvider, deviceId: String, fcmToken: String, fullName: String?) async throws -> AuthToken {
        // 네트워크 딜레이 시뮬레이션
        try await Task.sleep(nanoseconds: delay)

        // 에러 케이스 시뮬레이션
        if let error = simulatedError {
            throw error
        }

        // 가짜 JWT 반환
        return AuthToken(
            accessToken: "mock.access.token.\(provider.rawValue)",
            refreshToken: "mock.refresh.token.\(provider.rawValue)"
        )
    }
}
#endif
