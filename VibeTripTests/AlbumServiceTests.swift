//
//  AlbumServiceTests.swift
//  VibeTrip
//
//  Created by CHOI on 3/31/26.
//

import XCTest
import Combine
@testable import VibeTrip

// MARK: - MockAPIClient

// 테스트용 Mock -> APIClientProtocol 대체
// requestResult: request() 호출 시 반환할 성공 or 실패 결과 주입
// uploadResult:  upload()  호출 시 반환할 성공 or 실패 결과 주입
final class MockAPIClient: APIClientProtocol {

    // request 호출 시 반환할 결과 -> Any로 보관 후 T로 캐스팅
    var requestResult: Result<Any, Error> = .failure(APIClientError.decodingFailed)

    // upload 호출 시 반환할 결과
    var uploadResult: Result<AlbumCreateResponse, Error> = .success(AlbumCreateResponse(albumId: 0))

    // 호출 횟수 및 마지막으로 전달된 endpoint 기록
    private(set) var requestCallCount = 0
    private(set) var uploadCallCount = 0
    private(set) var capturedEndpoints: [APIEndpoint] = []

    var sessionExpiredPublisher: AnyPublisher<Void, Never> {
        PassthroughSubject<Void, Never>().eraseToAnyPublisher()
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        requestCallCount += 1
        capturedEndpoints.append(endpoint)
        switch requestResult {
        case .success(let value):
            guard let typed = value as? T else {
                throw APIClientError.decodingFailed
            }
            return typed
        case .failure(let error):
            throw error
        }
    }

    func upload<T: Decodable>(_ endpoint: APIEndpoint, formData: MultipartFormData) async throws -> T {
        uploadCallCount += 1
        switch uploadResult {
        case .success(let response):
            guard let typed = response as? T else {
                throw APIClientError.decodingFailed
            }
            return typed
        case .failure(let error):
            throw error
        }
    }

    // perform 호출 시 반환할 결과
    var performResult: Result<Void, Error> = .success(())
    private(set) var performCallCount = 0

    func perform(_ endpoint: APIEndpoint) async throws {
        performCallCount += 1
        capturedEndpoints.append(endpoint)
        if case .failure(let error) = performResult { throw error }
    }

    // performUpload 호출 시 반환할 결과
    var performUploadResult: Result<Void, Error> = .success(())
    private(set) var performUploadCallCount = 0
    private(set) var capturedFormData: MultipartFormData?

    func performUpload(_ endpoint: APIEndpoint, formData: MultipartFormData) async throws {
        performUploadCallCount += 1
        capturedEndpoints.append(endpoint)
        capturedFormData = formData
        if case .failure(let error) = performUploadResult { throw error }
    }
}

// MARK: - AlbumServiceTests

final class AlbumServiceTests: XCTestCase {

    var mockAPIClient: MockAPIClient!
    var sut: AlbumService!

    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        sut = AlbumService(apiClient: mockAPIClient)
    }

    override func tearDown() {
        mockAPIClient = nil
        sut = nil
        super.tearDown()
    }

    // 테스트용 AlbumCreateRequest 기본값
    private func makeRequest() -> AlbumCreateRequest {
        AlbumCreateRequest(
            photoData: Data([0x00, 0x01]),
            location: "서울",
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 86400),
            lyricsOption: .include,
            vocalGender: .female,
            genre: .kPop,
            comment: "테스트 코멘트"
        )
    }

    // MARK: - 성공

    // 정상 응답 -> albumId를 포함한 AlbumCreateResponse 반환
    func test_createAlbum_success_returnsAlbumId() async throws {
        mockAPIClient.uploadResult = .success(AlbumCreateResponse(albumId: 42))

        let response = try await sut.createAlbum(request: makeRequest())

        XCTAssertEqual(response.albumId, 42)
        XCTAssertEqual(mockAPIClient.uploadCallCount, 1)
    }

    // MARK: - 서버 에러

    // 서버가 에러 응답 반환 -> APIClientError.serverError throw
    func test_createAlbum_serverError_throwsServerError() async throws {
        mockAPIClient.uploadResult = .failure(APIClientError.serverError(.e400))

        do {
            _ = try await sut.createAlbum(request: makeRequest())
            XCTFail("서버 에러가 throw되어야 합니다")
        } catch APIClientError.serverError(let code) {
            XCTAssertEqual(code, .e400)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - 네트워크 에러

    // 네트워크 연결 불가 -> APIClientError.networkError throw
    func test_createAlbum_networkError_throwsNetworkError() async throws {
        let urlError = URLError(.notConnectedToInternet)
        mockAPIClient.uploadResult = .failure(APIClientError.networkError(urlError))

        do {
            _ = try await sut.createAlbum(request: makeRequest())
            XCTFail("네트워크 에러가 throw되어야 합니다")
        } catch APIClientError.networkError(let error) {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - 날짜 포맷

    // "yyyy-MM-dd" 형식으로 서버에 전달되는지 검증
    func test_createAlbum_dateFormatting_doesNotThrow() async throws {
        mockAPIClient.uploadResult = .success(AlbumCreateResponse(albumId: 1))

        // 특정 날짜로 요청 생성 (날짜 포맷 오류 시 throw)
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2025; components.month = 12; components.day = 31
        let date = calendar.date(from: components)!

        let request = AlbumCreateRequest(
            photoData: Data([0x00]),
            location: "제주",
            startDate: date,
            endDate: date,
            lyricsOption: .exclude,
            vocalGender: nil,
            genre: .jazz,
            comment: ""
        )

        let response = try await sut.createAlbum(request: request)
        XCTAssertEqual(response.albumId, 1)
    }

    // MARK: - fetchAlbums 성공

    // 정상 응답 -> AlbumListPayload 반환
    func test_fetchAlbums_success_returnsPayload() async throws {
        let expected = AlbumListPayload(
            content: [
                AlbumCard(id: 1, title: "도쿄", location: "일본", startDate: "2026-01-01", endDate: "2026-01-05", coverImageUrl: nil)
            ],
            totalCount: 1,
            hasNext: false
        )
        mockAPIClient.requestResult = .success(expected)

        let result = try await sut.fetchAlbums(cursor: nil, limit: 10)

        XCTAssertEqual(result.content.count, 1)
        XCTAssertEqual(result.content.first?.id, 1)
        XCTAssertEqual(result.hasNext, false)
        XCTAssertEqual(mockAPIClient.requestCallCount, 1)
    }

    // MARK: - fetchAlbums cursor 전달

    // cursor 값이 쿼리 파라미터로 올바르게 전달되는지 검증
    func test_fetchAlbums_cursor_isPassedAsQueryItem() async throws {
        mockAPIClient.requestResult = .success(
            AlbumListPayload(content: [], totalCount: 0, hasNext: false)
        )

        _ = try await sut.fetchAlbums(cursor: 5, limit: 10)

        let items = mockAPIClient.capturedEndpoints.first?.queryItems ?? []
        let cursorItem = items.first { $0.name == "cursor" }
        XCTAssertEqual(cursorItem?.value, "5")
    }

    // MARK: - fetchAlbums 서버 에러

    // 서버 에러 응답 -> APIClientError.serverError throw
    func test_fetchAlbums_serverError_throwsServerError() async throws {
        mockAPIClient.requestResult = .failure(APIClientError.serverError(.e400))

        do {
            _ = try await sut.fetchAlbums(cursor: nil, limit: 10)
            XCTFail("서버 에러가 throw되어야 합니다")
        } catch APIClientError.serverError(let code) {
            XCTAssertEqual(code, .e400)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - fetchAlbums 빈 목록

    // 빈 content 응답 -> content 빈 배열, hasNext false 반환
    func test_fetchAlbums_emptyList_returnsEmptyContent() async throws {
        mockAPIClient.requestResult = .success(
            AlbumListPayload(content: [], totalCount: 0, hasNext: false)
        )

        let result = try await sut.fetchAlbums(cursor: nil, limit: 10)

        XCTAssertTrue(result.content.isEmpty)
        XCTAssertEqual(result.totalCount, 0)
        XCTAssertFalse(result.hasNext)
    }

    // MARK: - fetchAlbumLogs 성공

    // 정상 응답 -> AlbumLogListPayload 반환
    func test_fetchAlbumLogs_success_returnsPayload() async throws {
        let expected = AlbumLogListPayload(
            content: [
                AlbumLogEntry(
                    id: 101,
                    description: "로그",
                    postedAt: "2026-01-13T12:00:00Z",
                    images: []
                )
            ],
            hasNext: true
        )
        mockAPIClient.requestResult = .success(expected)

        let result = try await sut.fetchAlbumLogs(albumId: "42", cursor: nil, limit: 20)

        XCTAssertEqual(result.content.count, 1)
        XCTAssertEqual(result.content.first?.id, 101)
        XCTAssertTrue(result.hasNext)
        XCTAssertEqual(mockAPIClient.requestCallCount, 1)
    }

    // albumId가 path에 올바르게 포함되는지 검증
    func test_fetchAlbumLogs_path_containsAlbumId() async throws {
        mockAPIClient.requestResult = .success(
            AlbumLogListPayload(content: [], hasNext: false)
        )

        _ = try await sut.fetchAlbumLogs(albumId: "99", cursor: nil, limit: 20)

        XCTAssertEqual(
            mockAPIClient.capturedEndpoints.first?.path,
            "/api/v1/albums/99/album-logs"
        )
    }

    // limit 값이 쿼리 파라미터로 전달되는지 검증
    func test_fetchAlbumLogs_limit_isPassedAsQueryItem() async throws {
        mockAPIClient.requestResult = .success(
            AlbumLogListPayload(content: [], hasNext: false)
        )

        _ = try await sut.fetchAlbumLogs(albumId: "1", cursor: nil, limit: 20)

        let items = mockAPIClient.capturedEndpoints.first?.queryItems ?? []
        let limitItem = items.first { $0.name == "limit" }
        XCTAssertEqual(limitItem?.value, "20")
    }

    // cursor 값이 있을 때만 쿼리 파라미터로 전달되는지 검증
    func test_fetchAlbumLogs_cursor_isPassedOnlyWhenProvided() async throws {
        mockAPIClient.requestResult = .success(
            AlbumLogListPayload(content: [], hasNext: false)
        )

        _ = try await sut.fetchAlbumLogs(albumId: "1", cursor: nil, limit: 20)
        _ = try await sut.fetchAlbumLogs(albumId: "1", cursor: 555, limit: 20)

        let firstItems = mockAPIClient.capturedEndpoints[0].queryItems ?? []
        let secondItems = mockAPIClient.capturedEndpoints[1].queryItems ?? []
        XCTAssertNil(firstItems.first { $0.name == "cursor" })
        XCTAssertEqual(secondItems.first { $0.name == "cursor" }?.value, "555")
    }

    // 서버 에러 응답 -> APIClientError.serverError throw
    func test_fetchAlbumLogs_serverError_throwsServerError() async throws {
        mockAPIClient.requestResult = .failure(APIClientError.serverError(.e400))

        do {
            _ = try await sut.fetchAlbumLogs(albumId: "1", cursor: nil, limit: 20)
            XCTFail("서버 에러가 throw되어야 합니다")
        } catch APIClientError.serverError(let code) {
            XCTAssertEqual(code, .e400)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - vocalGender 없음

    // vocalGender nil -> 서버에 "N"으로 전달
    func test_createAlbum_nilVocalGender_doesNotThrow() async throws {
        mockAPIClient.uploadResult = .success(AlbumCreateResponse(albumId: 7))

        let request = AlbumCreateRequest(
            photoData: Data([0x00]),
            location: "부산",
            startDate: Date(),
            endDate: Date(),
            lyricsOption: .exclude,
            vocalGender: nil,   // 정상: "N"으로 변환
            genre: .pop,
            comment: ""
        )

        let response = try await sut.createAlbum(request: request)
        XCTAssertEqual(response.albumId, 7)
        XCTAssertEqual(mockAPIClient.uploadCallCount, 1)
    }

    // MARK: - saveLog: 성공

    // 성공 시 performUpload 1회 호출
    func test_saveLog_success_callsPerformUploadOnce() async throws {
        mockAPIClient.performUploadResult = .success(())
        let request = AlbumLogRequest(albumId: "42", logText: "여행 기록", photoDataList: [])

        try await sut.saveLog(request: request)

        XCTAssertEqual(mockAPIClient.performUploadCallCount, 1)
    }

    // 올바른 엔드포인트 경로로 요청되는지 검증
    func test_saveLog_success_usesCorrectEndpointPath() async throws {
        mockAPIClient.performUploadResult = .success(())
        let request = AlbumLogRequest(albumId: "42", logText: "여행 기록", photoDataList: [])

        try await sut.saveLog(request: request)

        XCTAssertEqual(mockAPIClient.capturedEndpoints.last?.path, "/api/v1/albums/42/album-logs")
    }

    // 이미지 포함 시 formData에 images 파트가 이미지 수만큼 추가되는지 검증
    func test_saveLog_withPhotos_appendsImageParts() async throws {
        mockAPIClient.performUploadResult = .success(())
        let request = AlbumLogRequest(
            albumId: "1",
            logText: "사진 있는 로그",
            photoDataList: [Data([0x01, 0x02]), Data([0x03, 0x04])]
        )

        try await sut.saveLog(request: request)

        let imageParts = mockAPIClient.capturedFormData?.parts.filter { $0.name == "images" } ?? []
        XCTAssertEqual(imageParts.count, 2)
    }

    // MARK: - saveLog: 서버 에러

    // 서버 에러 응답 -> APIClientError.serverError throw
    func test_saveLog_serverError_throwsServerError() async throws {
        mockAPIClient.performUploadResult = .failure(APIClientError.serverError(.e400))
        let request = AlbumLogRequest(albumId: "1", logText: "테스트", photoDataList: [])

        do {
            try await sut.saveLog(request: request)
            XCTFail("서버 에러가 throw되어야 합니다")
        } catch APIClientError.serverError(let code) {
            XCTAssertEqual(code, .e400)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - deleteAlbum: 성공

    // 성공 시 perform 1회 호출
    func test_deleteAlbum_success_callsPerformOnce() async throws {
        mockAPIClient.performResult = .success(())

        try await sut.deleteAlbum(albumId: "42")

        XCTAssertEqual(mockAPIClient.performCallCount, 1)
    }

    // 올바른 엔드포인트 경로로 요청되는지 검증
    func test_deleteAlbum_success_usesCorrectPath() async throws {
        mockAPIClient.performResult = .success(())

        try await sut.deleteAlbum(albumId: "42")

        XCTAssertEqual(mockAPIClient.capturedEndpoints.first?.path, "/api/v1/albums/42")
    }

    // MARK: - deleteAlbum: 서버 에러

    // 서버 에러 응답 -> APIClientError.serverError throw
    func test_deleteAlbum_serverError_throwsServerError() async throws {
        mockAPIClient.performResult = .failure(APIClientError.serverError(.e400))

        do {
            try await sut.deleteAlbum(albumId: "1")
            XCTFail("서버 에러가 throw되어야 합니다")
        } catch APIClientError.serverError(let code) {
            XCTAssertEqual(code, .e400)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - deleteAlbum: 네트워크 에러

    // 네트워크 연결 불가 -> APIClientError.networkError throw
    func test_deleteAlbum_networkError_throwsNetworkError() async throws {
        let urlError = URLError(.notConnectedToInternet)
        mockAPIClient.performResult = .failure(APIClientError.networkError(urlError))

        do {
            try await sut.deleteAlbum(albumId: "1")
            XCTFail("네트워크 에러가 throw되어야 합니다")
        } catch APIClientError.networkError(let error) {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - saveLog: 네트워크 에러

    // 네트워크 연결 불가 -> APIClientError.networkError throw
    func test_saveLog_networkError_throwsNetworkError() async throws {
        let urlError = URLError(.notConnectedToInternet)
        mockAPIClient.performUploadResult = .failure(APIClientError.networkError(urlError))
        let request = AlbumLogRequest(albumId: "1", logText: "테스트", photoDataList: [])

        do {
            try await sut.saveLog(request: request)
            XCTFail("네트워크 에러가 throw되어야 합니다")
        } catch APIClientError.networkError(let error) {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - deleteAlbumLog: 성공

    // 성공 시 perform 1회 호출
    func test_deleteAlbumLog_success_callsPerformOnce() async throws {
        mockAPIClient.performResult = .success(())

        try await sut.deleteAlbumLog(albumId: "42", albumLogId: 7)

        XCTAssertEqual(mockAPIClient.performCallCount, 1)
    }

    // albumId, albumLogId가 path에 올바르게 포함되는지 검증
    func test_deleteAlbumLog_success_usesCorrectPath() async throws {
        mockAPIClient.performResult = .success(())

        try await sut.deleteAlbumLog(albumId: "42", albumLogId: 7)

        XCTAssertEqual(
            mockAPIClient.capturedEndpoints.first?.path,
            "/api/v1/albums/42/album-logs/7"
        )
    }

    // MARK: - deleteAlbumLog: 서버 에러

    // 서버 에러 응답 -> APIClientError.serverError throw
    func test_deleteAlbumLog_serverError_throwsServerError() async throws {
        mockAPIClient.performResult = .failure(APIClientError.serverError(.e400))

        do {
            try await sut.deleteAlbumLog(albumId: "1", albumLogId: 1)
            XCTFail("서버 에러가 throw되어야 합니다")
        } catch APIClientError.serverError(let code) {
            XCTAssertEqual(code, .e400)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - updateLog: 헬퍼

    private func makeUpdateRequest(newPhotoDataList: [Data] = []) -> AlbumLogUpdateRequest {
        AlbumLogUpdateRequest(
            albumId: "42",
            albumLogId: 101,
            logText: "수정된 기록",
            newPhotoDataList: newPhotoDataList
        )
    }

    // MARK: - updateLog: 성공

    // 성공 시 performUpload 1회 호출
    func test_updateLog_success_callsPerformUploadOnce() async throws {
        mockAPIClient.performUploadResult = .success(())

        try await sut.updateLog(request: makeUpdateRequest())

        XCTAssertEqual(mockAPIClient.performUploadCallCount, 1)
    }

    // albumId, albumLogId가 path에 올바르게 포함되는지 검증
    func test_updateLog_success_usesCorrectEndpointPath() async throws {
        mockAPIClient.performUploadResult = .success(())

        try await sut.updateLog(request: makeUpdateRequest())

        XCTAssertEqual(
            mockAPIClient.capturedEndpoints.last?.path,
            "/api/v1/albums/42/album-logs/101"
        )
    }

    // 새 이미지 포함 시 formData에 newImages 파트가 이미지 수만큼 추가되는지 검증
    func test_updateLog_withNewPhotos_appendsNewImageParts() async throws {
        mockAPIClient.performUploadResult = .success(())
        let request = makeUpdateRequest(newPhotoDataList: [Data([0x01]), Data([0x02])])

        try await sut.updateLog(request: request)

        let imageParts = mockAPIClient.capturedFormData?.parts.filter { $0.name == "newImages" } ?? []
        XCTAssertEqual(imageParts.count, 2)
    }

    // MARK: - updateLog: 서버 에러

    // 서버 에러 응답 -> APIClientError.serverError throw
    func test_updateLog_serverError_throwsServerError() async throws {
        mockAPIClient.performUploadResult = .failure(APIClientError.serverError(.e400))

        do {
            try await sut.updateLog(request: makeUpdateRequest())
            XCTFail("서버 에러가 throw되어야 합니다")
        } catch APIClientError.serverError(let code) {
            XCTAssertEqual(code, .e400)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - updateLog: 네트워크 에러

    // 네트워크 연결 불가 -> APIClientError.networkError throw
    func test_updateLog_networkError_throwsNetworkError() async throws {
        let urlError = URLError(.notConnectedToInternet)
        mockAPIClient.performUploadResult = .failure(APIClientError.networkError(urlError))

        do {
            try await sut.updateLog(request: makeUpdateRequest())
            XCTFail("네트워크 에러가 throw되어야 합니다")
        } catch APIClientError.networkError(let error) {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }
}
