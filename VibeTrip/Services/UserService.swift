//
//  UserService.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import Foundation

// TODO: 백엔드 API 연동 시 실제 구현 필요
final class UserService: UserServiceProtocol {

    func fetchProfile() async throws -> UserProfile {
        // TODO: 프로필 GET 앤드포인트 변경
        throw URLError(.unsupportedURL)
    }

    func deleteAccount() async throws {
        // TODO: 계정 DELETE 앤드포인트 변경
        throw URLError(.unsupportedURL)
    }
}
