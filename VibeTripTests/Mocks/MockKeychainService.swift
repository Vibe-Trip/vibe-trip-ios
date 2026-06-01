//
//  MockKeychainService.swift
//  VibeTripTests
//
//  Created by CHOI on 3/21/26.
//

import Foundation
@testable import VibeTrip

// 메모리 기반 Keychain Mock — 실제 Keychain 접근 없이 토큰 저장/조회
final class MockKeychainService: KeychainServiceProtocol {

    var accessToken: String? = "mock-access-token"
    var refreshToken: String? = "mock-refresh-token"
    var shouldThrow = false

    func save(accessToken: String, refreshToken: String) throws {
        if shouldThrow { throw KeychainError.saveFailed(-1) }
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    func getAccessToken() throws -> String {
        guard let token = accessToken else { throw KeychainError.notFound }
        return token
    }

    func getRefreshToken() throws -> String {
        guard let token = refreshToken else { throw KeychainError.notFound }
        return token
    }

    func clear() throws {
        accessToken = nil
        refreshToken = nil
    }
}
