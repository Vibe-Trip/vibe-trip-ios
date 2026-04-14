//
//  AlarmServiceTests.swift
//  VibeTrip
//
//  Created by CHOI on 4/7/26.
//

import XCTest
@testable import VibeTrip

// MARK: - AlarmServiceTests

final class AlarmServiceTests: XCTestCase {
    
    var mockAPIClient: MockAPIClient!
    var sut: AlarmService!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        sut = AlarmService(apiClient: mockAPIClient)
    }
    
    override func tearDown() {
        mockAPIClient = nil
        sut = nil
        super.tearDown()
    }
    
    // MARK: - fetchAlarms: 성공
    
    // 정상 응답 -> [AlarmResponse] 반환, request 1회 호출
    func test_fetchAlarms_success_returnsAlarmList() async throws {
        let expected = AlarmResponse.mockItems
        mockAPIClient.requestResult = .success(expected)
        
        let result = try await sut.fetchAlarms()
        
        XCTAssertEqual(result.count, expected.count)
        XCTAssertEqual(result.first?.alarmId, expected.first?.alarmId)
        XCTAssertEqual(mockAPIClient.requestCallCount, 1)
    }
    
    // 올바른 엔드포인트 경로로 요청되는지 검증
    func test_fetchAlarms_success_usesCorrectPath() async throws {
        mockAPIClient.requestResult = .success([AlarmResponse]())
        
        _ = try await sut.fetchAlarms()
        
        XCTAssertEqual(mockAPIClient.capturedEndpoints.first?.path, "/api/v1/alarms")
    }
    
    // GET 메서드로 요청되는지 검증
    func test_fetchAlarms_success_usesGetMethod() async throws {
        mockAPIClient.requestResult = .success([AlarmResponse]())
        
        _ = try await sut.fetchAlarms()
        
        XCTAssertEqual(mockAPIClient.capturedEndpoints.first?.method, .get)
    }
    
    // MARK: - fetchAlarms: 서버 에러
    
    // 서버 에러 응답 -> APIClientError.serverError throw
    func test_fetchAlarms_serverError_throwsServerError() async throws {
        mockAPIClient.requestResult = .failure(APIClientError.serverError(.e400))
        
        do {
            _ = try await sut.fetchAlarms()
            XCTFail("서버 에러가 throw되어야 합니다")
        } catch APIClientError.serverError(let code) {
            XCTAssertEqual(code, .e400)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }
    
    // MARK: - fetchAlarms: 네트워크 에러
    
    // 네트워크 연결 불가 -> APIClientError.networkError throw
    func test_fetchAlarms_networkError_throwsNetworkError() async throws {
        let urlError = URLError(.notConnectedToInternet)
        mockAPIClient.requestResult = .failure(APIClientError.networkError(urlError))
        
        do {
            _ = try await sut.fetchAlarms()
            XCTFail("네트워크 에러가 throw되어야 합니다")
        } catch APIClientError.networkError(let error) {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }
    
    // MARK: - deleteAlarm: 성공
    
    // 성공 시 perform 1회 호출
    func test_deleteAlarm_success_callsPerformOnce() async throws {
        mockAPIClient.performResult = .success(())
        
        try await sut.deleteAlarm(alarmId: 42)
        
        XCTAssertEqual(mockAPIClient.performCallCount, 1)
    }
    
    // alarmId가 path에 올바르게 포함되는지 검증
    func test_deleteAlarm_success_usesCorrectPath() async throws {
        mockAPIClient.performResult = .success(())
        
        try await sut.deleteAlarm(alarmId: 42)
        
        XCTAssertEqual(mockAPIClient.capturedEndpoints.first?.path, "/api/v1/alarms/42")
    }
    
    // DELETE 메서드로 요청되는지 검증
    func test_deleteAlarm_success_usesDeleteMethod() async throws {
        mockAPIClient.performResult = .success(())
        
        try await sut.deleteAlarm(alarmId: 42)
        
        XCTAssertEqual(mockAPIClient.capturedEndpoints.first?.method, .delete)
    }
    
    // MARK: - deleteAlarm: 서버 에러
    
    // 서버 에러 응답 -> APIClientError.serverError throw
    func test_deleteAlarm_serverError_throwsServerError() async throws {
        mockAPIClient.performResult = .failure(APIClientError.serverError(.e400))
        
        do {
            try await sut.deleteAlarm(alarmId: 1)
            XCTFail("서버 에러가 throw되어야 합니다")
        } catch APIClientError.serverError(let code) {
            XCTAssertEqual(code, .e400)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }
    
    // MARK: - deleteAlarm: 네트워크 에러
    
    // 네트워크 연결 불가 -> APIClientError.networkError throw
    func test_deleteAlarm_networkError_throwsNetworkError() async throws {
        let urlError = URLError(.notConnectedToInternet)
        mockAPIClient.performResult = .failure(APIClientError.networkError(urlError))
        
        do {
            try await sut.deleteAlarm(alarmId: 1)
            XCTFail("네트워크 에러가 throw되어야 합니다")
        } catch APIClientError.networkError(let error) {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }
}
