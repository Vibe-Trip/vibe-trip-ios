//
//  AlbumLogViewModelTests.swift
//  VibeTrip
//
//  Created by CHOI on 4/2/26.
//

import XCTest
import UIKit
@testable import VibeTrip

// MARK: - StubAlbumLogService

// 로그 저장/수정 결과를 제어하는 Stub
fileprivate final class StubAlbumLogService: AlbumServiceProtocol {

    var saveResult: Result<Void, Error> = .success(())
    private(set) var saveCallCount = 0

    var updateResult: Result<Void, Error> = .success(())
    private(set) var updateCallCount = 0
    // 마지막으로 전달된 수정 요청 (removeImageIds 등 검증용)
    private(set) var lastUpdateRequest: AlbumLogUpdateRequest?

    func saveLog(request: AlbumLogRequest) async throws {
        saveCallCount += 1
        if case .failure(let e) = saveResult { throw e }
    }

    func updateLog(request: AlbumLogUpdateRequest) async throws {
        updateCallCount += 1
        lastUpdateRequest = request
        if case .failure(let e) = updateResult { throw e }
    }

    func fetchAlbums(cursor: Int?, limit: Int) async throws -> AlbumListPayload { fatalError("미사용") }
    func createAlbum(request: AlbumCreateRequest) async throws -> AlbumCreateResponse { fatalError("미사용") }
    func fetchAlbumLog(albumId: String) async throws -> AlbumLog { fatalError("미사용") }
    func fetchAlbumLogs(albumId: String, cursor: Int?, limit: Int) async throws -> AlbumLogListPayload { fatalError("미사용") }
    func updateAlbum(albumId: String, request: AlbumUpdateRequest) async throws { fatalError("미사용") }
    func deleteAlbum(albumId: String) async throws { fatalError("미사용") }
    func fetchAlbum(albumId: Int) async throws -> AlbumDetail { fatalError("미사용") }
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
    
    // 텍스트가 비어있으면 저장 요청 없이 검증 토스트 노출
    func test_saveLog_emptyText_showsValidationToastWithoutSaving() async {
        sut.logText = ""
        
        await sut.saveLog()
        
        XCTAssertEqual(stub.saveCallCount, 0)
        XCTAssertEqual(sut.toastMessage, "이야기를 작성해야 저장할 수 있어요.")
        XCTAssertFalse(sut.isSaved)
    }
    
    // 공백만 입력한 경우도 저장 요청 없이 검증 토스트 노출
    func test_saveLog_whitespaceText_showsValidationToastWithoutSaving() async {
        sut.logText = "   \n  "
        
        await sut.saveLog()
        
        XCTAssertEqual(stub.saveCallCount, 0)
        XCTAssertEqual(sut.toastMessage, "이야기를 작성해야 저장할 수 있어요.")
        XCTAssertFalse(sut.isSaved)
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

    private func makeTestImage(size: CGSize = CGSize(width: 10, height: 10)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    // 5장 이하 추가 -> selectedPhotos에 정상 반영
    func test_addPhotos_withinLimit_addsPhotos() {
        let images = (0..<3).map { _ in makeTestImage() }

        sut.addPhotos(images)

        XCTAssertEqual(sut.selectedPhotos.count, 3)
    }

    // 5장 초과 추가 -> 한도 초과 토스트 메시지 설정
    func test_addPhotos_exceedLimit_showsToast() {
        let images = (0..<6).map { _ in makeTestImage() }

        sut.addPhotos(images)

        XCTAssertNotNil(sut.toastMessage)
    }
}

// MARK: - AlbumLogViewModelEditTests

@MainActor
final class AlbumLogViewModelEditTests: XCTestCase {

    private var stub: StubAlbumLogService!
    private var sut: AlbumLogViewModel!

    private let mockEntry = AlbumLogEntry(
        id: 99,
        description: "기존 텍스트",
        postedAt: "2026-01-13T12:00:00Z",
        images: []
    )

    override func setUp() async throws {
        try await super.setUp()
        stub = StubAlbumLogService()
        sut = AlbumLogViewModel(albumId: "1", mode: .edit(mockEntry), service: stub)
    }

    override func tearDown() async throws {
        stub = nil
        sut = nil
        try await super.tearDown()
    }

    // MARK: - saveLog

    // 수정 저장 성공 -> updateLog 1회 호출
    func test_saveLog_editMode_success_callsUpdateLogOnce() async {
        stub.updateResult = .success(())
        sut.logText = "수정된 텍스트"

        await sut.saveLog()

        XCTAssertEqual(stub.updateCallCount, 1)
    }

    // 수정 저장 성공 -> isSaved == true
    func test_saveLog_editMode_success_isSavedBecomesTrue() async {
        stub.updateResult = .success(())
        sut.logText = "수정된 텍스트"

        await sut.saveLog()

        XCTAssertTrue(sut.isSaved)
    }

    // 수정 저장 실패 -> 에러 토스트 메시지 설정
    func test_saveLog_editMode_failure_showsToastMessage() async {
        stub.updateResult = .failure(APIClientError.serverError(.e400))
        sut.logText = "수정된 텍스트"

        await sut.saveLog()

        XCTAssertNotNil(sut.toastMessage)
    }

    // MARK: - hasUnsavedChanges

    // 텍스트 동일 + 새 사진 없음 -> 변경 없음
    func test_hasUnsavedChanges_editMode_noChanges_returnsFalse() {
        // logText는 init 시 entry.description으로 pre-fill됨
        XCTAssertFalse(sut.hasUnsavedChanges)
    }

    // 텍스트 변경 -> 변경 있음
    func test_hasUnsavedChanges_editMode_textChanged_returnsTrue() {
        sut.logText = "변경된 텍스트"

        XCTAssertTrue(sut.hasUnsavedChanges)
    }

    // MARK: - removePhoto

    // 새 사진 추가 후 제거 -> selectedPhotos에서 삭제됨
    func test_removePhoto_editMode_newPhoto_removesPhoto() {
        sut.addPhotos([UIImage()])

        sut.removePhoto(at: 0)

        XCTAssertTrue(sut.selectedPhotos.isEmpty)
    }

    // MARK: - removeImageIds

    // 기존 이미지가 있는 수정 모드에서 기존 사진 삭제 -> 저장 시 removeImageIds에 해당 ID 포함
    func test_removePhoto_existingImage_includesIdInUpdateRequest() async {
        let entryWithImages = AlbumLogEntry(
            id: 99,
            description: "텍스트",
            postedAt: "2026-01-13T12:00:00Z",
            images: [
                AlbumLogImage(id: 10, imageUrl: URL(string: "https://example.com/img1.jpg")!),
                AlbumLogImage(id: 20, imageUrl: URL(string: "https://example.com/img2.jpg")!)
            ]
        )
        stub = StubAlbumLogService()
        sut = AlbumLogViewModel(albumId: "1", mode: .edit(entryWithImages), service: stub)
        sut.logText = "텍스트"

        // 첫 번째 기존 이미지(id: 10) 삭제 (existingPhotosCount 기준 인덱스 0)
        sut.removePhoto(at: 0)
        await sut.saveLog()

        XCTAssertEqual(stub.lastUpdateRequest?.removeImageIds, [Int64(10)])
    }

    // 기존 이미지 삭제 없이 저장 -> removeImageIds 빈 배열 전달
    func test_saveLog_editMode_noRemovedImages_sendsEmptyRemoveIds() async {
        let entryWithImages = AlbumLogEntry(
            id: 99,
            description: "텍스트",
            postedAt: "2026-01-13T12:00:00Z",
            images: [
                AlbumLogImage(id: 10, imageUrl: URL(string: "https://example.com/img1.jpg")!)
            ]
        )
        stub = StubAlbumLogService()
        sut = AlbumLogViewModel(albumId: "1", mode: .edit(entryWithImages), service: stub)
        sut.logText = "텍스트"

        await sut.saveLog()

        XCTAssertEqual(stub.lastUpdateRequest?.removeImageIds, [Int64]())
    }
}
