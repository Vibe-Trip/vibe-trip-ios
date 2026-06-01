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
        let endpoint = APIEndpoint(path: "/api/v1/members/me/withdraw", method: .delete)
        try await apiClient.perform(endpoint)
    }
}
