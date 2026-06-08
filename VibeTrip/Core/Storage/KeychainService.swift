//
//  KeychainService.swift
//  VibeTrip
//
//  Created by CHOI on 3/21/26.
//

// Keychain 저장/조회/삭제 구현체

import Foundation

// MARK: - Keychain 에러

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case notFound
    case unexpectedData
    case deleteFailed(OSStatus)
}

// MARK: - Keychain 서비스

protocol KeychainServiceProtocol {
    // accessToken, refreshToken을 Keychain에 저장
    func save(accessToken: String, refreshToken: String) throws
    
    // 저장된 accessToken 조회
    func getAccessToken() throws -> String
    
    // 저장된 refreshToken 조회
    func getRefreshToken() throws -> String
    
    // 저장된 모든 토큰 삭제 (로그아웃)
    func clear() throws
}

// MARK: - Keychain Key

private enum KeychainKey {
    static let service      = "com.vibetrip.auth"
    static let accessToken  = "accessToken"
    static let refreshToken = "refreshToken"
}

// MARK: - 구현체

final class KeychainService: KeychainServiceProtocol {
    
    func save(accessToken: String, refreshToken: String) throws {
        try save(value: accessToken, forKey: KeychainKey.accessToken)
        try save(value: refreshToken, forKey: KeychainKey.refreshToken)
    }
    
    func getAccessToken() throws -> String {
        try getValue(forKey: KeychainKey.accessToken)
    }
    
    func getRefreshToken() throws -> String {
        try getValue(forKey: KeychainKey.refreshToken)
    }
    
    func clear() throws {
        try delete(forKey: KeychainKey.accessToken)
        try delete(forKey: KeychainKey.refreshToken)
    }
    
    // MARK: - 헬퍼
    
    private func save(value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    KeychainKey.service,
            kSecAttrAccount:    key,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            // 이미 존재 -> 업데이트
            let attributes: [CFString: Any] = [kSecValueData: data]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.saveFailed(updateStatus)
            }
        } else {
            // 신규 추가
            var addQuery = query
            addQuery[kSecValueData] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.saveFailed(addStatus)
            }
        }
    }
    
    private func getValue(forKey key: String) throws -> String {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: KeychainKey.service,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { throw KeychainError.notFound }
        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { throw KeychainError.unexpectedData }
        
        return string
    }
    
    private func delete(forKey key: String) throws {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: KeychainKey.service,
            kSecAttrAccount: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        // errSecItemNotFound: 이미 없는 상태 -> 성공으로 간주
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
