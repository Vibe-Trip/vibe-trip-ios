//
//  APIClient.swift
//  VibeTrip
//
//  Created by CHOI on 3/30/26.
//

// 인증이 필요한 모든 API 요청 공통 HTTP 클라이언트
// - Authorization 헤더 자동 주입 (Keychain에서 accessToken 불러옴)
// - 401 응답 시: refreshToken으로 자동 갱신 후 재시도
// - refreshToken 만료 시: sessionExpiredPublisher 발행 -> AppState에서 로그아웃 처리

import Foundation
import Combine

// MARK: - HTTPMethod

// HTTP 요청 메서드 타입
enum HTTPMethod: String {
    case get    = "GET"
    case post   = "POST"
    case put    = "PUT"
    case delete = "DELETE"
}

// MARK: - APIClientError

// APIClient에서 발생하는 에러 타입
enum APIClientError: Error {
    case invalidURL                     // URL 생성 실패
    case networkError(URLError)         // 네트워크 연결 실패
    case decodingFailed                 // 응답 JSON 파싱 실패
    case serverError(BackendErrorCode)  // 서버가 resultType == "ERROR"로 응답
    case sessionExpired                 // refreshToken 만료: 로그아웃 트리거
    case unknown                        // 미분류 에러
}

// MARK: - APIEndpoint

// 단일 API 요청을 설명하는 값 타입
struct APIEndpoint {
    let path: String                    // 앤드포인트 경로
    let method: HTTPMethod              // HTTP 메서드
    let body: (any Encodable)?          // JSON 바디 (없으면 nil)
    let requiresAuth: Bool              // false: Authorization 헤더 생략
    let queryItems: [URLQueryItem]?     // GET 쿼리 파라미터

    init(
        path: String,
        method: HTTPMethod,
        body: (any Encodable)? = nil,
        requiresAuth: Bool = true,
        queryItems: [URLQueryItem]? = nil
    ) {
        self.path = path
        self.method = method
        self.body = body
        self.requiresAuth = requiresAuth
        self.queryItems = queryItems
    }
}

// MARK: - MultipartFormData

// multipart/form-data 요청 바디 구성 헬퍼
// 사용: 앨범 생성, 로그 등록 및 수정

struct MultipartFormData {

    // 멀티파트의 각 파트 (이미지 1장, JSON 1개 등)
    struct Part {
        let name: String        // form-data 필드명 (예: "image", "request")
        let data: Data          // 실제 바이트 데이터
        let filename: String?   // 파일명 (이미지: "image.jpg", JSON: nil)
        let mimeType: String?   // Content-Type (이미지: "image/jpeg", JSON: "application/json")
    }

    private(set) var parts: [Part] = []

    // Encodable 객체: JSON으로 직렬화해 파트에 추가
    mutating func append(name: String, encodable: any Encodable) throws {
        let data = try JSONEncoder().encode(encodable)
        parts.append(Part(name: name, data: data, filename: nil, mimeType: "application/json"))
    }

    // 이미지 바이너리 데이터: 파트에 추가
    mutating func append(name: String, imageData: Data, filename: String = "image.jpg") {
        parts.append(Part(name: name, data: imageData, filename: filename, mimeType: "image/jpeg"))
    }

    // boundary를 기준: 전체 바디를 Data로 인코딩
    func encode(boundary: String) -> Data {
        var body = Data()
        let crlf = "\r\n"

        for part in parts {
            body.append("--\(boundary)\(crlf)")

            var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
            if let filename = part.filename {
                disposition += "; filename=\"\(filename)\""
            }
            body.append("\(disposition)\(crlf)")

            if let mimeType = part.mimeType {
                body.append("Content-Type: \(mimeType)\(crlf)")
            }

            body.append(crlf)
            body.append(part.data)
            body.append(crlf)
        }
        body.append("--\(boundary)--\(crlf)")
        return body
    }
}

private extension Data {
    // String -> Data 변환 편의 메서드 (multipart 바디 구성 시 사용)
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) { append(data) }
    }
}

// MARK: - URLSessionProtocol

// URLSession: 프로토콜로 추상화 -> 단위 테스트 시 MockURLSession으로 교체 가능
protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

// MARK: - APIClientProtocol

protocol APIClientProtocol {
    // JSON 응답이 있는 요청 (GET/POST/PUT)
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T

    // multipart/form-data 요청 (이미지 포함 업로드)
    func upload<T: Decodable>(_ endpoint: APIEndpoint, formData: MultipartFormData) async throws -> T

    // 응답 데이터가 없는 요청 (DELETE, ApiResponseUnit 처리)
    func perform(_ endpoint: APIEndpoint) async throws

    // refreshToken 만료 시 발행: AppState -> 로그아웃 처리
    var sessionExpiredPublisher: AnyPublisher<Void, Never> { get }
}

// MARK: - RefreshActor

// Swift actor: 토큰 갱신 중복 요청을 방지
// 여러 401이 발생: refreshToken 갱신은 1회만 수행
// 갱신 진행 중: 나머지 요청은 대기 -> 갱신 완료 후 결과를 일괄 수신
private actor RefreshActor {

    private var isRefreshing = false

    // 갱신 완료를 기다리는 요청 대기열
    private var waiters: [CheckedContinuation<Bool, Never>] = []

    func refreshIfNeeded(using action: () async -> Bool) async -> Bool {
        if isRefreshing {
            // 이미 갱신 진행 중 -> 완료될 때까지 대기 후 같은 결과 수신
            return await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        isRefreshing = true
        let success = await action()

        // 대기 중이던 요청에 갱신 결과 전달
        for waiter in waiters { waiter.resume(returning: success) }
        waiters.removeAll()
        isRefreshing = false
        return success
    }
}

// MARK: - APIClient

final class APIClient: APIClientProtocol {

    // 기본 공유 인스턴스: 별도 DI 없이 서비스에서 직접 참조 가능
    static let shared = APIClient()

    private let baseURL = "https://dev.retrip.shop"
    private let keychain: KeychainServiceProtocol
    private let session: URLSessionProtocol
    private let refreshActor = RefreshActor()

    // 세션 만료 이벤트 스트림: AppState -> isLoggedIn = false 처리
    private let sessionExpiredSubject = PassthroughSubject<Void, Never>()
    var sessionExpiredPublisher: AnyPublisher<Void, Never> {
        sessionExpiredSubject.eraseToAnyPublisher()
    }

    init(
        keychain: KeychainServiceProtocol = KeychainService(),
        session: URLSessionProtocol = URLSession.shared
    ) {
        self.keychain = keychain
        self.session = session
    }

    // MARK: - JSON 요청

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let urlRequest = try buildJSONRequest(endpoint)
        let data = try await executeRaw(urlRequest)
        return try decodeResponse(data)
    }

    // MARK: - multipart 요청

    func upload<T: Decodable>(_ endpoint: APIEndpoint, formData: MultipartFormData) async throws -> T {
        let urlRequest = try buildMultipartRequest(endpoint, formData: formData)
        let data = try await executeRaw(urlRequest)
        return try decodeResponse(data)
    }

    // MARK: - 응답 바디 없는 요청

    func perform(_ endpoint: APIEndpoint) async throws {
        let urlRequest = try buildJSONRequest(endpoint)
        let data = try await executeRaw(urlRequest)
        // data 필드 없이 resultType만 확인 (ApiResponseUnit 처리)
        guard let apiResponse = try? JSONDecoder().decode(ApiResponse<EmptyDecodable>.self, from: data) else {
            throw APIClientError.decodingFailed
        }
        if apiResponse.resultType == "ERROR" {
            let code = apiResponse.error.flatMap { BackendErrorCode(rawValue: $0.errorCode) } ?? .unknown
            throw APIClientError.serverError(code)
        }
    }

    // MARK: - 내부 실행 (401 인터셉터)

    // 실제 네트워크 요청 수행: 401 -> 토큰 갱신 후 재시도 -> Data 반환
    private func executeRaw(_ urlRequest: URLRequest) async throws -> Data {
        let (data, response) = try await performRequest(urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.unknown
        }

        guard httpResponse.statusCode == 401 else {
            return data
        }

        // 401: RefreshActor로 갱신 중복 방지하며 토큰 갱신
        let refreshed = await refreshActor.refreshIfNeeded { [weak self] in
            await self?.refreshToken() ?? false
        }

        guard refreshed else {
            // refreshToken도 만료: 세션 만료 발행 후 에러
            sessionExpiredSubject.send()
            throw APIClientError.sessionExpired
        }

        // 갱신 성공: 새 accessToken으로 헤더만 교체 후 재시도
        var retryRequest = urlRequest
        if let newToken = try? keychain.getAccessToken() {
            retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
        }
        let (retryData, _) = try await performRequest(retryRequest)
        return retryData
    }

    // URLError -> APIClientError 변환: 통일된 에러 타입 유지
    private func performRequest(_ urlRequest: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: urlRequest)
        } catch let urlError as URLError {
            throw APIClientError.networkError(urlError)
        }
    }

    // MARK: - 토큰 갱신

    // POST /api/v1/auth/refresh 호출: 성공 시 새 토큰 Keychain 저장
    private func refreshToken() async -> Bool {
        guard let refreshToken = try? keychain.getRefreshToken() else { return false }

        let endpoint = APIEndpoint(path: "/api/v1/auth/refresh", method: .post, requiresAuth: false)
        guard var request = try? buildJSONRequest(endpoint) else { return false }

        // 갱신 요청: accessToken 대신 refreshToken 사용
        request.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await session.data(for: request),
              let apiResponse = try? JSONDecoder().decode(ApiResponse<AuthToken>.self, from: data),
              apiResponse.resultType == "SUCCESS",
              let newToken = apiResponse.data else { return false }

        try? keychain.save(accessToken: newToken.accessToken, refreshToken: newToken.refreshToken)
        return true
    }

    // MARK: - URLRequest 생성 (JSON)

    private func buildJSONRequest(_ endpoint: APIEndpoint) throws -> URLRequest {
        // URLComponents: 쿼리 파라미터를 URL에 인코딩 및 연결
        var components = URLComponents(string: baseURL + endpoint.path)
        components?.queryItems = endpoint.queryItems
        guard let url = components?.url else {
            throw APIClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // requiresAuth == true: Keychain에서 accessToken 호출 및 자동 주입
        if endpoint.requiresAuth, let token = try? keychain.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = endpoint.body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        return request
    }

    // MARK: - URLRequest 생성 (multipart)

    private func buildMultipartRequest(_ endpoint: APIEndpoint, formData: MultipartFormData) throws -> URLRequest {
        var request = try buildJSONRequest(endpoint)
        let boundary = UUID().uuidString
        // multipart Content-Type에 boundary 포함 (JSON Content-Type 덮어쓰기)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = formData.encode(boundary: boundary)
        return request
    }

    // MARK: - ApiResponse<T> 디코딩

    // resultType == "ERROR": BackendErrorCode 기반 에러 throw
    // data = nil: unknown 에러
    private func decodeResponse<T: Decodable>(_ data: Data) throws -> T {
        guard let apiResponse = try? JSONDecoder().decode(ApiResponse<T>.self, from: data) else {
            throw APIClientError.decodingFailed
        }
        if apiResponse.resultType == "ERROR" {
            let code = apiResponse.error.flatMap { BackendErrorCode(rawValue: $0.errorCode) } ?? .unknown
            throw APIClientError.serverError(code)
        }
        guard let result = apiResponse.data else {
            throw APIClientError.unknown
        }
        return result
    }
}

// MARK: - 내부 타입

// ApiResponseUnit 처리용 빈 Decodable
// perform() 내부에서만 사용
private struct EmptyDecodable: Decodable {}

// MARK: - MockAPIClient (DEBUG 전용)

#if DEBUG
// 단위 테스트 및 SwiftUI Preview 전용 Mock
final class MockAPIClient: APIClientProtocol {

    var stubbedResult: (any Decodable)?  // 성공 시 반환 데이터 (T 타입과 일치해야 함)
    var stubbedError: Error?             // 에러 시나리오 주입 (nil이면 성공)
    var delay: UInt64 = 300_000_000      // 네트워크 지연 시뮬레이션

    private let sessionExpiredSubject = PassthroughSubject<Void, Never>()
    var sessionExpiredPublisher: AnyPublisher<Void, Never> {
        sessionExpiredSubject.eraseToAnyPublisher()
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        try await simulateResponse()
    }

    func upload<T: Decodable>(_ endpoint: APIEndpoint, formData: MultipartFormData) async throws -> T {
        try await simulateResponse()
    }

    func perform(_ endpoint: APIEndpoint) async throws {
        try await Task.sleep(nanoseconds: delay)
        if let error = stubbedError { throw error }
    }

    // 세션 만료 시나리오 수동 트리거
    func triggerSessionExpired() {
        sessionExpiredSubject.send()
    }

    private func simulateResponse<T: Decodable>() async throws -> T {
        try await Task.sleep(nanoseconds: delay)
        if let error = stubbedError { throw error }
        guard let result = stubbedResult as? T else { throw APIClientError.unknown }
        return result
    }
}
#endif
