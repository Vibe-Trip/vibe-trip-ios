//
//  AlbumDetailViewModelTests.swift
//  VibeTrip
//
//  Created by Codex on 4/2/26.
//

import XCTest
@testable import VibeTrip

// MARK: - StubAlbumDetailService

private final class StubAlbumDetailService: AlbumServiceProtocol {

    var results: [Result<AlbumLogListPayload, Error>]
    var deleteResult: Result<Void, Error> = .success(())
    private(set) var callCount = 0
    private(set) var capturedAlbumIds: [String] = []
    private(set) var capturedCursors: [Int?] = []
    private(set) var capturedLimits: [Int] = []

    init(results: [Result<AlbumLogListPayload, Error>]) {
        self.results = results
    }

    func fetchAlbumLogs(albumId: String, cursor: Int?, limit: Int) async throws -> AlbumLogListPayload {
        callCount += 1
        capturedAlbumIds.append(albumId)
        capturedCursors.append(cursor)
        capturedLimits.append(limit)
        let result = results.count > 1 ? results.removeFirst() : results.first!
        switch result {
        case .success(let payload): return payload
        case .failure(let error): throw error
        }
    }

    func deleteAlbum(albumId: String) async throws {
        switch deleteResult {
        case .success: return
        case .failure(let error): throw error
        }
    }

    func fetchAlbums(cursor: Int?, limit: Int) async throws -> AlbumListPayload { fatalError("미사용") }
    func createAlbum(request: AlbumCreateRequest) async throws -> AlbumCreateResponse { fatalError("미사용") }
    func fetchAlbumLog(albumId: String) async throws -> AlbumLog { fatalError("미사용") }
    func updateAlbum(albumId: String, request: AlbumUpdateRequest) async throws -> AlbumCard { fatalError("미사용") }
    func saveLog(request: AlbumLogRequest) async throws { fatalError("미사용") }
}

// MARK: - AlbumDetailViewModelTests

@MainActor
final class AlbumDetailViewModelTests: XCTestCase {

    private var stub: StubAlbumDetailService!
    private var sut: AlbumDetailViewModel!

    override func tearDown() async throws {
        stub = nil
        sut = nil
        try await super.tearDown()
    }

    private func makeSUT(results: [Result<AlbumLogListPayload, Error>]) {
        stub = StubAlbumDetailService(results: results)
        sut = AlbumDetailViewModel(albumId: "77", service: stub)
    }

    private func makeEntry(id: Int, postedAt: String) -> AlbumLogEntry {
        AlbumLogEntry(
            id: id,
            description: "로그 \(id)",
            postedAt: postedAt,
            images: []
        )
    }

    // MARK: - loadInitialLogs

    // 첫 조회 성공 -> logs 채워짐, albumId/limit 전달
    func test_loadInitialLogs_success_populatesLogs() async {
        let entries = [
            makeEntry(id: 1, postedAt: "2026-01-13T12:00:00Z"),
            makeEntry(id: 2, postedAt: "2026-01-12T12:00:00Z")
        ]
        makeSUT(results: [.success(AlbumLogListPayload(content: entries, hasNext: false))])

        await sut.loadInitialLogs()

        XCTAssertEqual(sut.logs.map(\.id), [1, 2])
        XCTAssertEqual(stub.capturedAlbumIds, ["77"])
        XCTAssertEqual(stub.capturedLimits, [20])
        XCTAssertEqual(stub.capturedCursors.count, 1)
        XCTAssertNil(stub.capturedCursors[0])
    }

    // 재조회 시 기존 logs와 cursor를 리셋하고 첫 페이지부터 다시 요청
    func test_loadInitialLogs_calledTwice_resetsLogsAndCursor() async {
        let firstPage = [
            makeEntry(id: 10, postedAt: "2026-01-13T12:00:00Z"),
            makeEntry(id: 20, postedAt: "2026-01-12T12:00:00Z")
        ]
        let secondPage = [
            makeEntry(id: 30, postedAt: "2026-01-11T12:00:00Z")
        ]
        let reloadPage = [
            makeEntry(id: 40, postedAt: "2026-01-10T12:00:00Z")
        ]
        makeSUT(results: [
            .success(AlbumLogListPayload(content: firstPage, hasNext: true)),
            .success(AlbumLogListPayload(content: secondPage, hasNext: false)),
            .success(AlbumLogListPayload(content: reloadPage, hasNext: false))
        ])

        await sut.loadInitialLogs()
        await sut.loadMoreIfNeeded(lastId: 20)
        await sut.loadInitialLogs()

        XCTAssertEqual(stub.capturedCursors, [nil, 20, nil])
        XCTAssertEqual(sut.logs.map(\.id), [40])
    }

    // MARK: - loadMoreIfNeeded

    // 마지막 아이템 도달 + hasNext true -> 다음 페이지 요청
    func test_loadMoreIfNeeded_whenLastItem_fetchesNextPage() async {
        let firstPage = [
            makeEntry(id: 1, postedAt: "2026-01-13T12:00:00Z"),
            makeEntry(id: 2, postedAt: "2026-01-12T12:00:00Z")
        ]
        let secondPage = [
            makeEntry(id: 3, postedAt: "2026-01-11T12:00:00Z")
        ]
        makeSUT(results: [
            .success(AlbumLogListPayload(content: firstPage, hasNext: true)),
            .success(AlbumLogListPayload(content: secondPage, hasNext: false))
        ])

        await sut.loadInitialLogs()
        await sut.loadMoreIfNeeded(lastId: 2)

        XCTAssertEqual(stub.callCount, 2)
        XCTAssertEqual(stub.capturedCursors, [nil, 2])
        XCTAssertEqual(sut.logs.map(\.id), [1, 2, 3])
    }

    // 마지막 아이템이 아니면 추가 호출 없음
    func test_loadMoreIfNeeded_whenNotLastItem_doesNotFetch() async {
        let entries = [
            makeEntry(id: 1, postedAt: "2026-01-13T12:00:00Z"),
            makeEntry(id: 2, postedAt: "2026-01-12T12:00:00Z")
        ]
        makeSUT(results: [.success(AlbumLogListPayload(content: entries, hasNext: true))])

        await sut.loadInitialLogs()
        await sut.loadMoreIfNeeded(lastId: 1)

        XCTAssertEqual(stub.callCount, 1)
        XCTAssertEqual(sut.logs.map(\.id), [1, 2])
    }

    // hasNext false면 추가 호출 없음
    func test_loadMoreIfNeeded_whenHasNextFalse_doesNotFetch() async {
        let entries = [
            makeEntry(id: 1, postedAt: "2026-01-13T12:00:00Z")
        ]
        makeSUT(results: [.success(AlbumLogListPayload(content: entries, hasNext: false))])

        await sut.loadInitialLogs()
        await sut.loadMoreIfNeeded(lastId: 1)

        XCTAssertEqual(stub.callCount, 1)
    }

    // MARK: - groupedLogs

    // 날짜별로 그룹핑하고 최신 날짜 그룹이 먼저
    func test_groupedLogs_groupsByDateDescending() async {
        let entries = [
            makeEntry(id: 1, postedAt: "2026-01-13T12:00:00Z"),
            makeEntry(id: 2, postedAt: "2026-01-13T09:00:00Z"),
            makeEntry(id: 3, postedAt: "2026-01-12T12:00:00Z")
        ]
        makeSUT(results: [.success(AlbumLogListPayload(content: entries, hasNext: false))])

        await sut.loadInitialLogs()

        XCTAssertEqual(sut.groupedLogs.count, 2)
        XCTAssertEqual(sut.groupedLogs[0].logs.map(\.id), [1, 2])
        XCTAssertEqual(sut.groupedLogs[1].logs.map(\.id), [3])
    }

    // 밀리초 없는 ISO8601도 파싱 가능
    func test_parseISO8601Date_withoutFractionalSeconds_returnsDate() {
        let date = AlbumDetailViewModel.parseISO8601Date("2026-01-13T12:00:00Z")
        XCTAssertNotNil(date)
    }

    // 밀리초 있는 ISO8601도 파싱 가능
    func test_parseISO8601Date_withFractionalSeconds_returnsDate() {
        let date = AlbumDetailViewModel.parseISO8601Date("2026-01-13T12:00:00.123Z")
        XCTAssertNotNil(date)
    }

    // MARK: - requestDeleteAlbum

    // 호출 시 showDeleteConfirm = true -> 확인 다이얼로그 표시 트리거
    func test_requestDeleteAlbum_setsShowDeleteConfirmTrue() {
        makeSUT(results: [.success(AlbumLogListPayload(content: [], hasNext: false))])

        sut.requestDeleteAlbum()

        XCTAssertTrue(sut.showDeleteConfirm)
    }

    // MARK: - dismissDeleteConfirm

    // 호출 시 showDeleteConfirm = false -> 다이얼로그 닫힘 상태로 리셋
    func test_dismissDeleteConfirm_setsShowDeleteConfirmFalse() {
        makeSUT(results: [.success(AlbumLogListPayload(content: [], hasNext: false))])
        sut.requestDeleteAlbum()

        sut.dismissDeleteConfirm()

        XCTAssertFalse(sut.showDeleteConfirm)
    }

    // MARK: - confirmDeleteAlbum: 성공

    // 성공 시 didDeleteAlbum = true -> View가 화면 닫기 트리거
    func test_confirmDeleteAlbum_success_setsDidDeleteAlbumTrue() async {
        makeSUT(results: [.success(AlbumLogListPayload(content: [], hasNext: false))])
        stub.deleteResult = .success(())

        await sut.confirmDeleteAlbum()

        XCTAssertTrue(sut.didDeleteAlbum)
    }

    // 성공 시 deleteError = nil -> 에러 alert 미표시
    func test_confirmDeleteAlbum_success_doesNotSetError() async {
        makeSUT(results: [.success(AlbumLogListPayload(content: [], hasNext: false))])
        stub.deleteResult = .success(())

        await sut.confirmDeleteAlbum()

        XCTAssertNil(sut.deleteError)
    }

    // 성공 후 isDeleting = false -> 로딩 상태 해제
    func test_confirmDeleteAlbum_success_resetsIsDeleting() async {
        makeSUT(results: [.success(AlbumLogListPayload(content: [], hasNext: false))])
        stub.deleteResult = .success(())

        await sut.confirmDeleteAlbum()

        XCTAssertFalse(sut.isDeleting)
    }

    // MARK: - confirmDeleteAlbum: 실패

    // 실패 시 deleteError 설정 -> 에러 alert 표시 트리거
    func test_confirmDeleteAlbum_failure_setsDeleteError() async {
        makeSUT(results: [.success(AlbumLogListPayload(content: [], hasNext: false))])
        stub.deleteResult = .failure(APIClientError.serverError(.e400))

        await sut.confirmDeleteAlbum()

        XCTAssertNotNil(sut.deleteError)
    }

    // 실패 시 didDeleteAlbum = false -> 화면 닫기 미트리거
    func test_confirmDeleteAlbum_failure_doesNotSetDidDeleteAlbum() async {
        makeSUT(results: [.success(AlbumLogListPayload(content: [], hasNext: false))])
        stub.deleteResult = .failure(APIClientError.serverError(.e400))

        await sut.confirmDeleteAlbum()

        XCTAssertFalse(sut.didDeleteAlbum)
    }

    // 실패 후 isDeleting = false -> 로딩 상태 해제
    func test_confirmDeleteAlbum_failure_resetsIsDeleting() async {
        makeSUT(results: [.success(AlbumLogListPayload(content: [], hasNext: false))])
        stub.deleteResult = .failure(APIClientError.networkError(URLError(.notConnectedToInternet)))

        await sut.confirmDeleteAlbum()

        XCTAssertFalse(sut.isDeleting)
    }

    // MARK: - dismissDeleteError

    // 호출 시 deleteError = nil -> 에러 alert 닫힘 상태로 리셋
    func test_dismissDeleteError_clearsDeleteError() async {
        makeSUT(results: [.success(AlbumLogListPayload(content: [], hasNext: false))])
        stub.deleteResult = .failure(APIClientError.serverError(.e400))
        await sut.confirmDeleteAlbum()

        sut.dismissDeleteError()

        XCTAssertNil(sut.deleteError)
    }
}
