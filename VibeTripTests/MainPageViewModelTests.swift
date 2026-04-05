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
    func fetchAlbumLogs(albumId: String, cursor: Int?, limit: Int) async throws -> AlbumLogListPayload { fatalError("미사용") }
    func updateAlbum(albumId: String, request: AlbumUpdateRequest) async throws -> AlbumCard { fatalError("미사용") }
    func deleteAlbum(albumId: String) async throws { fatalError("미사용") }
    func deleteAlbumLog(albumId: String, albumLogId: Int) async throws { fatalError("미사용") }
    func saveLog(request: AlbumLogRequest) async throws { fatalError("미사용") }
    func fetchAlbum(albumId: Int) async throws -> AlbumDetail {
        AlbumDetail(title: nil, coverImageUrl: nil, region: "", travelStartDate: "", travelEndDate: "", musicUrl: nil)
    }
}

// MARK: - PollingStubAlbumService

// fetchAlbums + fetchAlbumTitle 동시 제어가 필요한 폴링 테스트 전용 Stub
private final class PollingStubAlbumService: AlbumServiceProtocol {

    // fetchAlbums 반환 앨범 목록
    var albums: [AlbumCard]
    // N번째 fetchAlbumTitle 호출부터 타이틀 반환 (기본: 첫 번째 호출에서 반환)
    var titleReadyAfterAttempts: Int = 1
    private(set) var titleFetchCounts: [Int: Int] = [:]

    init(albums: [AlbumCard]) {
        self.albums = albums
    }

    func fetchAlbums(cursor: Int?, limit: Int) async throws -> AlbumListPayload {
        AlbumListPayload(content: albums, totalCount: albums.count, hasNext: false)
    }

    func fetchAlbum(albumId: Int) async throws -> AlbumDetail {
        titleFetchCounts[albumId, default: 0] += 1
        let count = titleFetchCounts[albumId]!
        let title: String? = count >= titleReadyAfterAttempts ? "폴링 타이틀" : nil
        return AlbumDetail(title: title, coverImageUrl: nil, region: "", travelStartDate: "", travelEndDate: "", musicUrl: nil)
    }

    func createAlbum(request: AlbumCreateRequest) async throws -> AlbumCreateResponse { fatalError("미사용") }
    func fetchAlbumLog(albumId: String) async throws -> AlbumLog { fatalError("미사용") }
    func fetchAlbumLogs(albumId: String, cursor: Int?, limit: Int) async throws -> AlbumLogListPayload { fatalError("미사용") }
    func updateAlbum(albumId: String, request: AlbumUpdateRequest) async throws -> AlbumCard { fatalError("미사용") }
    func deleteAlbum(albumId: String) async throws { fatalError("미사용") }
    func deleteAlbumLog(albumId: String, albumLogId: Int) async throws { fatalError("미사용") }
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

    // reloadAlbums() 호출 시 albums 초기화 후 재로드
    func test_reloadAlbums_resetsAndLoadsNewData() async {
        let firstCards = makeAlbumCards(ids: [1, 2, 3])
        let secondCards = makeAlbumCards(ids: [4, 5])
        let stub = StubAlbumService(results: [
            .success(AlbumListPayload(content: firstCards, totalCount: 3, hasNext: false)),
            .success(AlbumListPayload(content: secondCards, totalCount: 2, hasNext: false))
        ])
        makeSUT(stub: stub)

        await sut.loadAlbums()
        await sut.reloadAlbums()   // 명시적 새로고침: hasLoaded 리셋 후 재로드

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
        await sut.reloadAlbums()                        // 명시적 새로고침 -> cursor 리셋

        XCTAssertEqual(stub.capturedCursors.count, 3)
        XCTAssertNil(stub.capturedCursors[2])           // 세 번째 요청: cursor nil (리셋 확인)
        XCTAssertEqual(sut.albums.count, 3)
    }

    // MARK: - 폴링

    // nil-title 앨범 로드 후 폴링 완료 시 해당 앨범의 title이 업데이트됨
    func test_polling_nilTitleAlbum_titleApplied() async {
        let nilAlbum = AlbumCard(id: 10, title: nil, location: "제주", startDate: "2026-01-01", endDate: "2026-01-03", coverImageUrl: nil)
        let stub = PollingStubAlbumService(albums: [nilAlbum])
        stub.titleReadyAfterAttempts = 1
        sut = MainPageViewModel(albumService: stub, pollingInterval: 0)

        await sut.loadAlbums()
        // pollingInterval: 0이어도 Task.sleep + fetchAlbumTitle 호출 등 여러 비동기 단계가 있어
        // yield 2회로는 부족 → 10ms sleep으로 모든 단계 완료 보장
        try? await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(sut.albums.first?.title, "폴링 타이틀")
    }

    // nil-title 앨범만 업데이트되고 title이 있는 앨범은 변경 없음
    func test_polling_onlyTargetAlbumUpdated() async {
        let normalAlbum = AlbumCard(id: 1, title: "기존 타이틀", location: "서울", startDate: "2026-01-01", endDate: "2026-01-02", coverImageUrl: nil)
        let nilAlbum    = AlbumCard(id: 2, title: nil,        location: "제주", startDate: "2026-01-01", endDate: "2026-01-03", coverImageUrl: nil)
        let stub = PollingStubAlbumService(albums: [normalAlbum, nilAlbum])
        stub.titleReadyAfterAttempts = 1
        sut = MainPageViewModel(albumService: stub, pollingInterval: 0)

        await sut.loadAlbums()
        try? await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(sut.albums[0].title, "기존 타이틀")  // 변경 없음
        XCTAssertEqual(sut.albums[1].title, "폴링 타이틀")  // 폴링으로 업데이트
    }

    // cancelAllPolling 호출 후 title nil 상태 유지 (폴링 Task 취소됨)
    func test_cancelAllPolling_preventsUpdate() async {
        let nilAlbum = AlbumCard(id: 10, title: nil, location: "제주", startDate: "2026-01-01", endDate: "2026-01-03", coverImageUrl: nil)
        let stub = PollingStubAlbumService(albums: [nilAlbum])
        stub.titleReadyAfterAttempts = 1
        sut = MainPageViewModel(albumService: stub, pollingInterval: 0)

        await sut.loadAlbums()
        sut.cancelAllPolling()       // 폴링 시작 직후 취소
        try? await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertNil(sut.albums.first?.title)   // 취소됐으므로 여전히 nil
    }

    // reloadAlbums 호출 시 기존 폴링이 취소되고 새 폴링이 시작됨
    func test_reloadAlbums_cancelsAndRestarts() async {
        let nilAlbum = AlbumCard(id: 10, title: nil, location: "제주", startDate: "2026-01-01", endDate: "2026-01-03", coverImageUrl: nil)
        let stub = PollingStubAlbumService(albums: [nilAlbum])
        // 2번째 호출부터 타이틀 반환 → reloadAlbums 후 새 폴링에서 반환됨
        stub.titleReadyAfterAttempts = 2
        sut = MainPageViewModel(albumService: stub, pollingInterval: 0)

        await sut.loadAlbums()      // 첫 번째 폴링 시작 (1번째 호출: nil 반환)
        await sut.reloadAlbums()    // 기존 폴링 취소 + 재로드 + 새 폴링 시작 (2번째 호출: 타이틀 반환)
        try? await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(sut.albums.first?.title, "폴링 타이틀")
    }

    // MARK: - hasLoaded

    // loadAlbums() 두 번 호출 -> 두 번째는 API 호출 없이 스킵
    func test_loadAlbums_calledTwice_skipsSecondCall() async {
        let cards = makeAlbumCards(ids: [1, 2, 3])
        let stub = StubAlbumService(results: [
            .success(AlbumListPayload(content: cards, totalCount: 3, hasNext: false))
        ])
        makeSUT(stub: stub)

        await sut.loadAlbums()
        await sut.loadAlbums()   // hasLoaded guard: 스킵

        XCTAssertEqual(stub.callCount, 1)       // API 1회만 호출
        XCTAssertEqual(sut.albums.count, 3)     // 첫 결과 유지
    }

    // reloadAlbums() -> hasLoaded 리셋 후 API 재호출
    func test_reloadAlbums_afterLoad_callsAPIAgain() async {
        let cards = makeAlbumCards(ids: [1, 2, 3])
        let stub = StubAlbumService(results: [
            .success(AlbumListPayload(content: cards, totalCount: 3, hasNext: false)),
            .success(AlbumListPayload(content: cards, totalCount: 3, hasNext: false))
        ])
        makeSUT(stub: stub)

        await sut.loadAlbums()
        await sut.reloadAlbums()

        XCTAssertEqual(stub.callCount, 2)       // 재로드로 API 2회 호출
    }
}
