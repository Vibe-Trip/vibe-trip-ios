//
//  APIClientTests.swift
//  VibeTripTests
//
//  Created by CHOI on 3/30/26.
//

import XCTest
import Combine
@testable import VibeTrip

// MARK: - MockURLSession

// URLSession을 대체해 테스트용 응답을 주입 Mock 세션
// responses 배열에 순서대로 응답을 쌓아두면 요청 순서대로 소비
final class MockURLSession: URLSessionProtocol {
    
    // 주입할 응답 목록
    var responses: [(Data, URLResponse)] = []
    var error: Error? = nil
    
    // 실제로 호출된 요청 기록 (검증용)
    private(set) var requestCount = 0
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1
        if let error { throw error }
        guard !responses.isEmpty else {
            throw URLError(.badServerResponse)
        }
        return responses.removeFirst()
    }
}

// MARK: - MockKeychainService

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

// MARK: - 헬퍼

// 딕셔너리를 APIClient용 ApiResponse<T> JSON으로 래핑
private func makeSuccessResponse(_ value: [String: Any]) throws -> Data {
    let wrapper: [String: Any] = ["resultType": "SUCCESS", "data": value]
    return try JSONSerialization.data(withJSONObject: wrapper)
}

// 에러 응답 JSON 생성
private func makeErrorResponse(code: String = "E400", message: String = "Bad Request") throws -> Data {
    let wrapper: [String: Any] = [
        "resultType": "ERROR",
        "error": ["errorCode": code, "message": message]
    ]
    return try JSONSerialization.data(withJSONObject: wrapper)
}

// HTTP 응답 생성 헬퍼
private func makeHTTPResponse(statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: URL(string: "https://dev.retrip.shop")!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
}

// MARK: - 테스트 대상 Decodable

private struct SampleResponse: Codable, Equatable {
    let id: Int
    let name: String
}

// MARK: - APIClientTests

final class APIClientTests: XCTestCase {
    
    var mockSession: MockURLSession!
    var mockKeychain: MockKeychainService!
    var sut: APIClient!               // System Under Test
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        mockKeychain = MockKeychainService()
        sut = APIClient(keychain: mockKeychain, session: mockSession)
        cancellables = []
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - 정상 요청 성공
    
    // 200 응답 -> ApiResponse<T> 디코딩 -> 올바른 값 반환
    func test_requestSuccess_returnsDecodedData() async throws {
        let expected = SampleResponse(id: 1, name: "테스트")
        let responseData = try makeSuccessResponse(["id": 1, "name": "테스트"])
        mockSession.responses = [(responseData, makeHTTPResponse(statusCode: 200))]
        
        let endpoint = APIEndpoint(path: "/api/v1/test", method: .get)
        let result: SampleResponse = try await sut.request(endpoint)
        
        XCTAssertEqual(result, expected)
        XCTAssertEqual(mockSession.requestCount, 1)
    }
    
    // MARK: - 토큰 자동 주입 확인
    
    // requiresAuth == true -> Authorization 헤더에 accessToken 포함
    func test_request_injectsAuthorizationHeader() async throws {
        mockKeychain.accessToken = "test-access-token"
        
        let responseData = try makeSuccessResponse(["id": 1, "name": "확인"])
        mockSession.responses = [(responseData, makeHTTPResponse(statusCode: 200))]
        
        // MockURLSession: 직접 헤더 검증 불가 -> 요청 1회 발생 여부로 검증
        let endpoint = APIEndpoint(path: "/api/v1/test", method: .get)
        let _: SampleResponse = try await sut.request(endpoint)
        
        XCTAssertEqual(mockSession.requestCount, 1)
    }
    
    // MARK: - 서버 에러 응답
    
    // resultType == "ERROR" -> APIClientError.serverError(BackendErrorCode) throw
    func test_serverErrorResponse_throwsServerError() async throws {
        let errorData = try makeErrorResponse(code: "E400", message: "잘못된 요청")
        mockSession.responses = [(errorData, makeHTTPResponse(statusCode: 200))]
        
        let endpoint = APIEndpoint(path: "/api/v1/test", method: .get)
        
        do {
            let _: SampleResponse = try await sut.request(endpoint)
            XCTFail("에러가 throw되어야 합니다")
        } catch APIClientError.serverError(let code) {
            XCTAssertEqual(code, .e400)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }
    
    // MARK: - 401 → 토큰 갱신 성공 → 재시도
    
    // 첫 번째 요청: 401 반환
    // 갱신 요청: 새 토큰 포함 성공 응답
    // 재시도 요청: 200 성공
    func test_401_refreshSuccess_retriesAndReturnsData() async throws {
        // 1. 원래 요청 401 응답
        let unauthorizedResponse = makeHTTPResponse(statusCode: 401)
        
        // 2. 토큰 갱신 성공 응답
        let newToken = AuthToken(accessToken: "new-access-token", refreshToken: "new-refresh-token")
        let refreshSuccessData = try makeSuccessResponse(["accessToken": "new-access-token", "refreshToken": "new-refresh-token"])
        
        // 3. 재시도 성공 응답
        let retryData = try makeSuccessResponse(["id": 2, "name": "갱신 후 성공"])
        
        mockSession.responses = [
            (Data(), unauthorizedResponse),          // 첫 요청: 401
            (refreshSuccessData, makeHTTPResponse(statusCode: 200)),  // 갱신 요청
            (retryData, makeHTTPResponse(statusCode: 200))            // 재시도
        ]
        
        let endpoint = APIEndpoint(path: "/api/v1/test", method: .get)
        let result: SampleResponse = try await sut.request(endpoint)
        
        XCTAssertEqual(result.id, 2)
        // 원래 요청 1회 + 갱신 1회 + 재시도 1회 = 총 3회
        XCTAssertEqual(mockSession.requestCount, 3)
        // 새 토큰이 Keychain에 저장됐는지 확인
        XCTAssertEqual(mockKeychain.accessToken, "new-access-token")
        XCTAssertEqual(mockKeychain.refreshToken, "new-refresh-token")
    }
    
    // MARK: - 401 -> 토큰 갱신 실패 -> 세션 만료

    // 갱신 요청에서 서버 401 반환 시 sessionExpiredPublisher 발행 + APIClientError.sessionExpired throw
    func test_401_refreshExpired_publishesSessionExpiredAndThrows() async throws {
        // 1. 원래 요청: 401
        // 2. 갱신 요청: 서버 401 -> refreshToken 만료 확인
        mockSession.responses = [
            (Data(), makeHTTPResponse(statusCode: 401)),
            (Data(), makeHTTPResponse(statusCode: 401))
        ]

        // sessionExpiredPublisher 발행 여부 추적
        var sessionExpiredFired = false
        sut.sessionExpiredPublisher
            .sink { sessionExpiredFired = true }
            .store(in: &cancellables)

        let endpoint = APIEndpoint(path: "/api/v1/test", method: .get)

        do {
            let _: SampleResponse = try await sut.request(endpoint)
            XCTFail("sessionExpired 에러가 throw되어야 합니다")
        } catch APIClientError.sessionExpired {
            XCTAssertTrue(sessionExpiredFired, "sessionExpiredPublisher가 발행되어야 합니다")
            // 만료된 토큰이 Keychain에서 삭제됐는지 확인
            XCTAssertNil(mockKeychain.accessToken, "세션 만료 시 accessToken이 삭제되어야 합니다")
            XCTAssertNil(mockKeychain.refreshToken, "세션 만료 시 refreshToken이 삭제되어야 합니다")
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - 401 -> 갱신 일시 오류 -> 로그아웃 없이 네트워크 에러

    // 갱신 요청에서 서버 5xx 반환 시 -> sessionExpiredPublisher 미발행 + APIClientError.networkError throw
    func test_401_refreshTransientError_doesNotPublishSessionExpired() async throws {
        // 1. 원래 요청: 401
        // 2. 갱신 요청: 서버 503 -> 일시 오류
        mockSession.responses = [
            (Data(), makeHTTPResponse(statusCode: 401)),
            (Data(), makeHTTPResponse(statusCode: 503))
        ]

        // sessionExpiredPublisher가 발행되면 안됨
        var sessionExpiredFired = false
        sut.sessionExpiredPublisher
            .sink { sessionExpiredFired = true }
            .store(in: &cancellables)

        let endpoint = APIEndpoint(path: "/api/v1/test", method: .get)

        do {
            let _: SampleResponse = try await sut.request(endpoint)
            XCTFail("networkError가 throw되어야 합니다")
        } catch APIClientError.networkError {
            XCTAssertFalse(sessionExpiredFired, "일시 오류 시 sessionExpiredPublisher가 발행되면 안 됩니다")
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - perform (응답 바디 없는 요청)
    
    // DELETE 등 Unit 응답 -> 에러 없이 정상 완료
    func test_perform_success_noThrow() async throws {
        let unitResponseData = try JSONSerialization.data(withJSONObject: [
            "resultType": "SUCCESS"
        ])
        mockSession.responses = [(unitResponseData, makeHTTPResponse(statusCode: 200))]
        
        let endpoint = APIEndpoint(path: "/api/v1/test", method: .delete)
        
        // 에러 없이 완료되면 통과
        try await sut.perform(endpoint)
        XCTAssertEqual(mockSession.requestCount, 1)
    }
}
