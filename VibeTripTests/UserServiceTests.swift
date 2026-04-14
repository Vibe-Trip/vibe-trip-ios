//
//  UserServiceTests.swift
//  VibeTrip
//
//  Created by CHOI on 4/3/26.
//

import XCTest
@testable import VibeTrip

final class UserServiceTests: XCTestCase {

    private var mockAPIClient: MockAPIClient!
    private var sut: UserService!

    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        sut = UserService(apiClient: mockAPIClient)
    }

    override func tearDown() {
        mockAPIClient = nil
        sut = nil
        super.tearDown()
    }

    // 정상 응답 시 UserProfile 반환
    func test_fetchProfile_success() async throws {
        mockAPIClient.requestResult = .success(UserProfile.mock)

        let result = try await sut.fetchProfile()

        XCTAssertEqual(result.nickname, UserProfile.mock.nickname)
        XCTAssertEqual(result.email, UserProfile.mock.email)
        XCTAssertEqual(result.albumCount, UserProfile.mock.albumCount)
        XCTAssertEqual(result.albumLogCount, UserProfile.mock.albumLogCount)
    }

    // 네트워크 에러 시 throw 확인
    func test_fetchProfile_networkError() async {
        mockAPIClient.requestResult = .failure(APIClientError.networkError(URLError(.notConnectedToInternet)))

        do {
            _ = try await sut.fetchProfile()
            XCTFail("에러가 발생해야 합니다")
        } catch let error as APIClientError {
            guard case .networkError = error else {
                XCTFail("networkError여야 합니다")
                return
            }
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // 올바른 엔드포인트(path, method) 호출 확인
    func test_fetchProfile_callsCorrectEndpoint() async throws {
        mockAPIClient.requestResult = .success(UserProfile.mock)

        _ = try await sut.fetchProfile()

        XCTAssertEqual(mockAPIClient.capturedEndpoints.count, 1)
        XCTAssertEqual(mockAPIClient.capturedEndpoints.first?.path, "/api/v1/members/profile")
        XCTAssertEqual(mockAPIClient.capturedEndpoints.first?.method, .get)
    }

    // MARK: - deleteAccount

    // 정상 응답 시 에러 없이 완료
    func test_deleteAccount_success() async {
        do {
            try await sut.deleteAccount()
        } catch {
            XCTFail("에러가 발생하면 안 됩니다: \(error)")
        }
    }

    // 네트워크 에러 시 throw 확인
    func test_deleteAccount_networkError() async {
        mockAPIClient.performResult = .failure(APIClientError.networkError(URLError(.notConnectedToInternet)))

        do {
            try await sut.deleteAccount()
            XCTFail("에러가 발생해야 합니다")
        } catch let error as APIClientError {
            guard case .networkError = error else {
                XCTFail("networkError여야 합니다")
                return
            }
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // 올바른 엔드포인트(path, method) 호출 확인
    func test_deleteAccount_callsCorrectEndpoint() async throws {
        try await sut.deleteAccount()

        XCTAssertEqual(mockAPIClient.capturedEndpoints.last?.path, "/api/v1/members/me/withdraw")
        XCTAssertEqual(mockAPIClient.capturedEndpoints.last?.method, .delete)
    }
}
