//
//  BackendAuthService.swift
//  VibeTrip
//
//  Created by CHOI on 3/15/26.
//

// 백엔드 인증 API 호출 서비스 구현체
// 1. accessToken(카카오) or identityToken(애플), deviceId, fcmToken: 서버로 전송
// 2. 서버가 발급한 JWT 반환

import Foundation

final class BackendAuthService: BackendAuthServiceProtocol {

    private let baseURL = "https://dev.retrip.shop"
    private let timeoutInterval: TimeInterval = 5

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        return URLSession(configuration: config)
    }()

    func authenticate(token: String, provider: LoginProvider, deviceId: String, fcmToken: String, fullName: String?) async throws -> AuthToken {
        let endpoint = "/api/v1/auth/login/\(provider.rawValue)"

        guard let url = URL(string: baseURL + endpoint) else {
            throw LoginError.providerError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Request Body
        var body: [String: Any] = [
            provider == .apple ? "identityToken" : "accessToken": token,
            "deviceId": deviceId,
            "fcmToken": fcmToken
        ]
        if provider == .apple {
            body["name"] = fullName ?? NSNull()
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)

            guard response is HTTPURLResponse else {
                throw LoginError.networkError
            }

            let apiResponse = try JSONDecoder().decode(ApiResponse<AuthToken>.self, from: data)

            if apiResponse.resultType == "ERROR" {
                let code = apiResponse.error.flatMap { BackendErrorCode(rawValue: $0.errorCode) } ?? .unknown
                throw LoginError.backendError(code)
            }

            guard let authToken = apiResponse.data else {
                throw LoginError.backendError(.unknown)
            }

            return authToken

        } catch let error as LoginError {
            throw error
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw LoginError.timeout
            case .notConnectedToInternet, .networkConnectionLost:
                throw LoginError.networkError
            default:
                throw LoginError.networkError
            }
        } catch {
            throw LoginError.providerError
        }
    }
}
