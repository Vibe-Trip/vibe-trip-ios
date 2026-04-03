//
//  UserService.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import Foundation

final class UserService: UserServiceProtocol {

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    func fetchProfile() async throws -> UserProfile {
        let endpoint = APIEndpoint(path: "/api/v1/members/profile", method: .get)
        return try await apiClient.request(endpoint)
    }

    func deleteAccount() async throws {
        // TODO: 계정 DELETE 앤드포인트 변경
        throw URLError(.unsupportedURL)
    }
}
