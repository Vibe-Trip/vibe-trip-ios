//
//  AlbumLogViewModelTests.swift
//  VibeTrip
//
//  Created by CHOI on 4/2/26.
//

import XCTest
@testable import VibeTrip

// MARK: - StubAlbumLogService

// 로그 저장 결과만 제어하는 Stub
fileprivate final class StubAlbumLogService: AlbumServiceProtocol {

    var saveResult: Result<Void, Error> = .success(())
    private(set) var saveCallCount = 0

    func saveLog(request: AlbumLogRequest) async throws {
        saveCallCount += 1
        if case .failure(let e) = saveResult { throw e }
    }

    func fetchAlbums(cursor: Int?, limit: Int) async throws -> AlbumListPayload { fatalError("미사용") }
    func createAlbum(request: AlbumCreateRequest) async throws -> AlbumCreateResponse { fatalError("미사용") }
    func fetchAlbumLog(albumId: String) async throws -> AlbumLog { fatalError("미사용") }
    func fetchAlbumLogs(albumId: String, cursor: Int?, limit: Int) async throws -> AlbumLogListPayload { fatalError("미사용") }
    func updateAlbum(albumId: String, request: AlbumUpdateRequest) async throws -> AlbumCard { fatalError("미사용") }
    func deleteAlbum(albumId: String) async throws { fatalError("미사용") }
    func fetchAlbumTitle(albumId: Int) async throws -> String? { fatalError("미사용") }
    func deleteAlbumLog(albumId: String, albumLogId: Int) async throws { fatalError("미사용") }
}

// MARK: - AlbumLogViewModelTests

@MainActor
final class AlbumLogViewModelTests: XCTestCase {

    fileprivate var stub: StubAlbumLogService!
    var sut: AlbumLogViewModel!

    override func setUp() async throws {
        try await super.setUp()
        stub = StubAlbumLogService()
        sut = AlbumLogViewModel(albumId: "1", mode: .create, service: stub)
    }

    override func tearDown() async throws {
        stub = nil
        sut = nil
        try await super.tearDown()
    }

    // MARK: - saveLog: 성공

    // 저장 성공 -> isSaved == true (화면 닫힘 트리거)
    func test_saveLog_success_isSavedBecomesTrue() async {
        stub.saveResult = .success(())
        sut.logText = "여행 기록"

        await sut.saveLog()

        XCTAssertTrue(sut.isSaved)
    }

    // 저장 성공 후 -> isSaving == false (로딩 상태 해제)
    func test_saveLog_success_isSavingReturnsFalse() async {
        stub.saveResult = .success(())
        sut.logText = "여행 기록"

        await sut.saveLog()

        XCTAssertFalse(sut.isSaving)
    }

    // MARK: - saveLog: 실패

    // 저장 실패 -> isSaved == false 유지
    func test_saveLog_failure_isSavedRemainingFalse() async {
        stub.saveResult = .failure(APIClientError.serverError(.e400))
        sut.logText = "여행 기록"

        await sut.saveLog()

        XCTAssertFalse(sut.isSaved)
    }

    // 저장 실패 -> 에러 토스트 메시지 설정
    func test_saveLog_failure_showsToastMessage() async {
        stub.saveResult = .failure(APIClientError.serverError(.e400))
        sut.logText = "여행 기록"

        await sut.saveLog()

        XCTAssertNotNil(sut.toastMessage)
    }

    // MARK: - isSaveEnabled

    // 텍스트 없음 -> 저장 버튼 비활성화
    func test_isSaveEnabled_emptyText_returnsFalse() {
        sut.logText = ""
        XCTAssertFalse(sut.isSaveEnabled)
    }

    // 텍스트 있음 -> 저장 버튼 활성화
    func test_isSaveEnabled_withText_returnsTrue() {
        sut.logText = "도쿄 여행"
        XCTAssertTrue(sut.isSaveEnabled)
    }

    // MARK: - addPhotos

    // 5장 이하 추가 -> selectedPhotos에 정상 반영
    func test_addPhotos_withinLimit_addsPhotos() {
        let images = (0..<3).map { _ in UIImage() }

        sut.addPhotos(images)

        XCTAssertEqual(sut.selectedPhotos.count, 3)
    }

    // 5장 초과 추가 -> 한도 초과 토스트 메시지 설정
    func test_addPhotos_exceedLimit_showsToast() {
        let images = (0..<6).map { _ in UIImage() }

        sut.addPhotos(images)

        XCTAssertNotNil(sut.toastMessage)
    }
}
