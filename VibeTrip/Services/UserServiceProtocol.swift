//
//  UserServiceProtocol.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import Foundation

// 사용자 서비스 프로토콜
protocol UserServiceProtocol {
    func fetchProfile() async throws -> UserProfile
    func deleteAccount() async throws
}

#if DEBUG
// Mock 서비스 (Preview / 테스트용)
final class MockUserService: UserServiceProtocol {

    func fetchProfile() async throws -> UserProfile {
        return UserProfile.mock
    }

    func deleteAccount() async throws {
        // No-op
    }
}
#endif
