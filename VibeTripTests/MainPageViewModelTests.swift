//
//  MainPageViewModelTests.swift
//  VibeTrip
//
//  Created by CHOI on 4/1/26.
//

import XCTest
@testable import VibeTrip

// MARK: - StubAlbumService

// fetchAlbums 호출: 순서대로 지정한 결과 반환
// results 배열 소진: 마지막 결과를 계속 반환
// capturedCursors: 호출 시 전달된 cursor 값 기록
private final class StubAlbumService: AlbumServiceProtocol {

    var results: [Result<AlbumListPayload, Error>]
    private(set) var callCount = 0
    private(set) var capturedCursors: [Int?] = []

    init(results: [Result<AlbumListPayload, Error>]) {
        self.results = results
    }

    func fetchAlbums(cursor: Int?, limit: Int) async throws -> AlbumListPayload {
        callCount += 1
        capturedCursors.append(cursor)
        let result = results.count > 1 ? results.removeFirst() : results.first!
        switch result {
        case .success(let p): return p
        case .failure(let e): throw e
        }
    }

    func createAlbum(request: AlbumCreateRequest) async throws -> AlbumCreateResponse { fatalError("미사용") }
    func fetchAlbumLog(albumId: String) async throws -> AlbumLog { fatalError("미사용") }
    func updateAlbum(albumId: String, request: AlbumUpdateRequest) async throws -> AlbumCard { fatalError("미사용") }
    func deleteAlbum(albumId: String) async throws { fatalError("미사용") }
    func saveLog(request: AlbumLogRequest) async throws { fatalError("미사용") }
}

// MARK: - MainPageViewModelTests

@MainActor
final class MainPageViewModelTests: XCTestCase {

    var sut: MainPageViewModel!

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - 헬퍼

    private func makeSUT(stub: StubAlbumService) {
        sut = MainPageViewModel(albumService: stub)
    }

    // id 배열로 AlbumCard 목록 생성
    private func makeAlbumCards(ids: [Int]) -> [AlbumCard] {
        ids.map { AlbumCard(id: $0, title: "앨범\($0)", location: "서울", startDate: "2026-01-01", endDate: "2026-01-05", coverImageUrl: nil) }
    }

    // MARK: - loadAlbums

    // 성공 응답 -> albums 채워짐, errorMessage nil
    func test_loadAlbums_success_populatesAlbums() async {
        let cards = makeAlbumCards(ids: [1, 2, 3])
        let stub = StubAlbumService(results: [
            .success(AlbumListPayload(content: cards, totalCount: 3, hasNext: false))
        ])
        makeSUT(stub: stub)

        await sut.loadAlbums()

        XCTAssertEqual(sut.albums.count, 3)
        XCTAssertEqual(sut.albums.map(\.id), [1, 2, 3])
        XCTAssertNil(sut.errorMessage)
    }

    // 에러 응답 -> errorMessage 설정됨, albums 비어있음
    func test_loadAlbums_error_setsErrorMessage() async {
        let stub = StubAlbumService(results: [
            .failure(APIClientError.serverError(.e400))
        ])
        makeSUT(stub: stub)

        await sut.loadAlbums()

        XCTAssertTrue(sut.albums.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
    }

    // 두 번째 loadAlbums() 호출 시 albums 초기화 후 로드
    func test_loadAlbums_calledTwice_resetsAlbums() async {
        let firstCards = makeAlbumCards(ids: [1, 2, 3])
        let secondCards = makeAlbumCards(ids: [4, 5])
        let stub = StubAlbumService(results: [
            .success(AlbumListPayload(content: firstCards, totalCount: 3, hasNext: false)),
            .success(AlbumListPayload(content: secondCards, totalCount: 2, hasNext: false))
        ])
        makeSUT(stub: stub)

        await sut.loadAlbums()
        await sut.loadAlbums()

        XCTAssertEqual(sut.albums.count, 2)
        XCTAssertEqual(sut.albums.map(\.id), [4, 5])
    }

    // MARK: - loadMoreIfNeeded

    // currentIndex >= albums.count - 2 -> fetchNextPage 실행됨
    func test_loadMoreIfNeeded_nearEnd_fetchesNextPage() async {
        let firstCards = makeAlbumCards(ids: [1, 2, 3, 4, 5])
        let secondCards = makeAlbumCards(ids: [6, 7])
        let stub = StubAlbumService(results: [
            .success(AlbumListPayload(content: firstCards, totalCount: 5, hasNext: true)),
            .success(AlbumListPayload(content: secondCards, totalCount: 2, hasNext: false))
        ])
        makeSUT(stub: stub)

        await sut.loadAlbums()                          // 첫 페이지: albums.count = 5
        await sut.loadMoreIfNeeded(currentIndex: 3)     // 5 - 2 = 3 → 3 >= 3 → 트리거

        XCTAssertEqual(stub.callCount, 2)
        XCTAssertEqual(sut.albums.count, 7)
    }

    // currentIndex < albums.count - 2 -> API 추가 호출 없음
    func test_loadMoreIfNeeded_notNearEnd_doesNotFetch() async {
        let cards = makeAlbumCards(ids: [1, 2, 3, 4, 5])
        let stub = StubAlbumService(results: [
            .success(AlbumListPayload(content: cards, totalCount: 5, hasNext: true))
        ])
        makeSUT(stub: stub)

        await sut.loadAlbums()                          // 첫 페이지: albums.count = 5
        await sut.loadMoreIfNeeded(currentIndex: 2)     // 5 - 2 = 3 → 2 < 3 → 미트리거

        XCTAssertEqual(stub.callCount, 1)
    }

    // MARK: - 페이지네이션

    // 1페이지 후 loadMoreIfNeeded -> albums 누적
    func test_pagination_appendsResultsAcrossPages() async {
        let firstCards = makeAlbumCards(ids: [1, 2, 3])
        let secondCards = makeAlbumCards(ids: [4, 5])
        let stub = StubAlbumService(results: [
            .success(AlbumListPayload(content: firstCards, totalCount: 3, hasNext: true)),
            .success(AlbumListPayload(content: secondCards, totalCount: 2, hasNext: false))
        ])
        makeSUT(stub: stub)

        await sut.loadAlbums()
        await sut.loadMoreIfNeeded(currentIndex: 1)     // 3 - 2 = 1 → 1 >= 1 -> 트리거

        XCTAssertEqual(sut.albums.count, 5)
        XCTAssertEqual(sut.albums.map(\.id), [1, 2, 3, 4, 5])
    }

    // hasNext: false 응답 후 loadMoreIfNeeded -> API 추가 호출 없음
    func test_pagination_hasNextFalse_doesNotFetchMore() async {
        let cards = makeAlbumCards(ids: [1, 2, 3])
        let stub = StubAlbumService(results: [
            .success(AlbumListPayload(content: cards, totalCount: 3, hasNext: false))
        ])
        makeSUT(stub: stub)

        await sut.loadAlbums()
        await sut.loadMoreIfNeeded(currentIndex: 1)     // guard hasNext에서 차단

        XCTAssertEqual(stub.callCount, 1)
    }

    // 2페이지 요청: 페이지 마지막 albumId가 cursor로 전달
    func test_pagination_cursorPassedCorrectly() async {
        let firstCards = makeAlbumCards(ids: [10, 20, 30])
        let secondCards = makeAlbumCards(ids: [40, 50])
        let stub = StubAlbumService(results: [
            .success(AlbumListPayload(content: firstCards, totalCount: 3, hasNext: true)),
            .success(AlbumListPayload(content: secondCards, totalCount: 2, hasNext: false))
        ])
        makeSUT(stub: stub)

        await sut.loadAlbums()
        await sut.loadMoreIfNeeded(currentIndex: 1)

        XCTAssertEqual(stub.capturedCursors.count, 2)
        XCTAssertNil(stub.capturedCursors[0])           // 첫 페이지: cursor nil
        XCTAssertEqual(stub.capturedCursors[1], 30)     // 두 번째 페이지: 마지막 id = 30
    }

    // loadAlbums() 재호출 시 cursor nil로 리셋 -> 첫 페이지부터 재요청
    func test_loadAlbums_resetsToFirstPage() async {
        let firstCards = makeAlbumCards(ids: [1, 2, 3])
        let secondCards = makeAlbumCards(ids: [4, 5])
        let stub = StubAlbumService(results: [
            .success(AlbumListPayload(content: firstCards, totalCount: 3, hasNext: true)),
            .success(AlbumListPayload(content: secondCards, totalCount: 2, hasNext: false)),
            .success(AlbumListPayload(content: firstCards, totalCount: 3, hasNext: false))
        ])
        makeSUT(stub: stub)

        await sut.loadAlbums()
        await sut.loadMoreIfNeeded(currentIndex: 1)     // 2페이지 로드 (cursor = 3)
        await sut.loadAlbums()                          // 재로드 -> cursor 리셋

        XCTAssertEqual(stub.capturedCursors.count, 3)
        XCTAssertNil(stub.capturedCursors[2])           // 세 번째 요청: cursor nil (리셋 확인)
        XCTAssertEqual(sut.albums.count, 3)
    }
}
