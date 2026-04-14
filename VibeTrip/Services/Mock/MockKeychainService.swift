//
//  MockKeychainService.swift
//  VibeTrip
//
//  Created by CHOI on 3/21/26.
//

// 단위테스트용 keychain 서비스

#if DEBUG
import Foundation

final class MockKeychainService: KeychainServiceProtocol {

    // 에러 시뮬레이션 (단위 테스트용)
    var simulatedSaveError: KeychainError? = nil
    var simulatedGetError: KeychainError? = nil

    private var store: [String: String] = [:]

    func save(accessToken: String, refreshToken: String) throws {
        if let error = simulatedSaveError { throw error }
        store["accessToken"] = accessToken
        store["refreshToken"] = refreshToken
    }

    func getAccessToken() throws -> String {
        if let error = simulatedGetError { throw error }
        guard let token = store["accessToken"] else { throw KeychainError.notFound }
        return token
    }

    func getRefreshToken() throws -> String {
        if let error = simulatedGetError { throw error }
        guard let token = store["refreshToken"] else { throw KeychainError.notFound }
        return token
    }

    func clear() throws {
        store.removeAll()
    }
}
#endif
