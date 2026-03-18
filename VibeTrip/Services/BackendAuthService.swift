//
//  BackendAuthService.swift
//  VibeTrip
//
//  Created by CHOI on 3/15/26.
//

// 백엔드 인증 API 호출 서비스 구현체
// 1. accessToken(카카오) or identityToken(애플), deviceId: 서버로 전송
// 2. 서버가 발급한 JWT 반환
// TODO: 백엔드 서버 연결(baseURL, 엔드포인트)

import Foundation

final class BackendAuthService: BackendAuthServiceProtocol {
    
    // TODO: 백엔드 baseURL 변경
    private let baseURL = "https://api.vibetrip.com"
    private let timeoutInterval: TimeInterval = 15
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        return URLSession(configuration: config)
    }()
    
    func authenticate(token: String, provider: LoginProvider, deviceId: String, fullName: String?) async throws -> AuthToken {
        // TODO: 백엔드 엔드포인트 변경
        let endpoint = "/api/auth/\(provider.rawValue)"
        
        guard let url = URL(string: baseURL + endpoint) else {
            throw LoginError.providerError
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Request Body
        var body: [String: Any] = [
            provider == .apple ? "identityToken" : "accessToken": token,
            "deviceId": deviceId
        ]
        if provider == .apple {
            body["fullName"] = fullName ?? NSNull()
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LoginError.networkError
            }
            
            // HTTP 상태코드별 에러 처리
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 403:
                throw LoginError.accountBlocked
            default:
                throw LoginError.providerError
            }
            
            return try JSONDecoder().decode(AuthToken.self, from: data)
            
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
