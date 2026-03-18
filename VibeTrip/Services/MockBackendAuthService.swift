//
//  MockBackendAuthService.swift
//  VibeTrip
//
//  Created by CHOI on 3/15/26.
//

// 테스트용(성공 case)

import Foundation

final class MockBackendAuthService: BackendAuthServiceProtocol {

    // nil: 성공, 값을 지정하면 해당 에러를 throw
    var simulatedError: LoginError? = nil

    // 네트워크 딜레이 시뮬 (기본 1초)
    var delay: UInt64 = 1_000_000_000

    func authenticate(token: String, provider: LoginProvider, deviceId: String, fullName: String?) async throws -> AuthToken {
        // 네트워크 딜레이 시뮬레이션
        try await Task.sleep(nanoseconds: delay)

        // 에러 케이스 시뮬레이션
        if let error = simulatedError {
            throw error
        }

        // 가짜 JWT 반환
        return AuthToken(
            accessToken: "mock.access.token.\(provider.rawValue)",
            refreshToken: "mock.refresh.token.\(provider.rawValue)",
            userId: "mock-user-001"
        )
    }
}
