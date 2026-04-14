//
//  EditAlbumViewModelTests.swift
//  VibeTrip
//
//  Created by CHOI on 4/5/26.
//

import XCTest
@testable import VibeTrip

// MARK: - StubAlbumService

private final class StubAlbumService: AlbumServiceProtocol {

    var fetchAlbumResult: Result<AlbumDetail, Error>
    var updateAlbumResult: Result<Void, Error>
    private(set) var updateCallCount = 0

    init(
        fetchResult: Result<AlbumDetail, Error> = .success(StubAlbumService.defaultDetail),
        updateResult: Result<Void, Error> = .success(())
    ) {
        self.fetchAlbumResult = fetchResult
        self.updateAlbumResult = updateResult
    }

    static var defaultDetail: AlbumDetail {
        AlbumDetail(
            title: "테스트 앨범",
            coverImageUrl: nil,
            region: "서울",
            travelStartDate: "2026-01-01",
            travelEndDate: "2026-01-05",
            musicUrl: nil,
            genre: .jazz,
            vocalGender: .female,
            withLyrics: true,
            comment: "테스트 코멘트"
        )
    }

    func fetchAlbum(albumId: Int) async throws -> AlbumDetail {
        switch fetchAlbumResult {
        case .success(let detail): return detail
        case .failure(let error): throw error
        }
    }

    func updateAlbum(albumId: String, request: AlbumUpdateRequest) async throws {
        updateCallCount += 1
        if case .failure(let error) = updateAlbumResult { throw error }
    }

    func createAlbum(request: AlbumCreateRequest) async throws -> AlbumCreateResponse { fatalError("미사용") }
    func fetchAlbums(cursor: Int?, limit: Int) async throws -> AlbumListPayload { fatalError("미사용") }
    func fetchAlbumLog(albumId: String) async throws -> AlbumLog { fatalError("미사용") }
    func fetchAlbumLogs(albumId: String, cursor: Int?, limit: Int) async throws -> AlbumLogListPayload { fatalError("미사용") }
    func deleteAlbum(albumId: String) async throws { fatalError("미사용") }
    func saveLog(request: AlbumLogRequest) async throws { fatalError("미사용") }
    func updateLog(request: AlbumLogUpdateRequest) async throws { fatalError("미사용") }
    func deleteAlbumLog(albumId: String, albumLogId: Int) async throws { fatalError("미사용") }
}

// MARK: - EditAlbumViewModelTests

@MainActor
final class EditAlbumViewModelTests: XCTestCase {

    // MARK: - 헬퍼

    private func makeSUT(stub: StubAlbumService = StubAlbumService(), onSaved: @escaping (EditAlbumSaveOutcome) -> Void = { _ in }) -> EditAlbumViewModel {
        EditAlbumViewModel(albumId: 1, albumService: stub, onSaved: onSaved)
    }

    // 1×1 px 실제 UIImage (jpegData 생성 가능)
    private func makeDummyImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    // 사진·여행지·날짜·가사 등 필수 항목을 모두 채운 유효 상태로 설정
    private func setupValidInput(
        _ sut: EditAlbumViewModel,
        lyricsOption: LyricsOption = .exclude,
        vocalGender: VocalGender? = nil,
        regenerateMusic: Bool = false
    ) {
        sut.selectedImage = makeDummyImage()
        sut.albumTitle = "테스트 앨범"
        sut.destination = "서울"
        sut.hasDateSelected = true
        sut.regenerateMusic = regenerateMusic
        sut.lyricsOption = lyricsOption
        sut.vocalGender = vocalGender
    }

    // MARK: - isValid

    // 모든 필수 항목 입력 (가사 미포함) -> true
    func test_isValid_allFilled_excludeLyrics_returnsTrue() {
        let sut = makeSUT()
        setupValidInput(sut, lyricsOption: .exclude)
        XCTAssertTrue(sut.isValid)
    }

    // 모든 필수 항목 입력 (가사 포함 + vocalGender 있음) -> true
    func test_isValid_allFilled_includeLyricsWithGender_returnsTrue() {
        let sut = makeSUT()
        setupValidInput(sut, lyricsOption: .include, vocalGender: .female)
        XCTAssertTrue(sut.isValid)
    }

    // 사진 미선택 (selectedImage nil, coverImageUrl nil) -> false
    func test_isValid_noPhoto_returnsFalse() {
        let sut = makeSUT()
        sut.destination = "서울"
        sut.hasDateSelected = true
        sut.lyricsOption = .exclude
        // selectedImage = nil (기본값), load 안 했으므로 coverImageUrl = nil
        XCTAssertFalse(sut.isValid)
    }

    // 여행지 미입력 -> false
    func test_isValid_emptyDestination_returnsFalse() {
        let sut = makeSUT()
        setupValidInput(sut)
        sut.destination = ""
        XCTAssertFalse(sut.isValid)
    }

    // 날짜 미선택 -> false
    func test_isValid_dateNotSelected_returnsFalse() {
        let sut = makeSUT()
        setupValidInput(sut)
        sut.hasDateSelected = false
        XCTAssertFalse(sut.isValid)
    }

    // 가사 포함인데 vocalGender 미선택 -> false
    func test_isValid_includeLyricsNoGender_returnsFalse() {
        let sut = makeSUT()
        setupValidInput(sut, lyricsOption: .include, vocalGender: nil, regenerateMusic: true)
        XCTAssertFalse(sut.isValid)
    }

    // MARK: - hasChanges

    // load 후 변경 없음 -> false
    func test_hasChanges_afterLoad_noChange_returnsFalse() async {
        let stub = StubAlbumService()
        let sut = makeSUT(stub: stub)
        await sut.load()
        XCTAssertFalse(sut.hasChanges)
    }

    // load 후 여행지 변경 -> true
    func test_hasChanges_afterLoad_destinationChanged_returnsTrue() async {
        let stub = StubAlbumService()
        let sut = makeSUT(stub: stub)
        await sut.load()
        sut.destination = "부산"
        XCTAssertTrue(sut.hasChanges)
    }

    // selectedImage 설정 -> true (load 전후 무관)
    func test_hasChanges_selectedImageSet_returnsTrue() {
        let sut = makeSUT()
        sut.selectedImage = makeDummyImage()
        XCTAssertTrue(sut.hasChanges)
    }

    // load 후 lyricsOption 변경 -> true
    func test_hasChanges_afterLoad_lyricsOptionChanged_returnsTrue() async {
        // defaultDetail.withLyrics = true → load 후 .include
        let stub = StubAlbumService()
        let sut = makeSUT(stub: stub)
        await sut.load()
        sut.lyricsOption = .exclude  // .include → .exclude 변경
        XCTAssertTrue(sut.hasChanges)
    }

    // MARK: - load (Pre-fill)

    // detail.region -> destination에 반영
    func test_load_setsDestinationFromRegion() async {
        let detail = AlbumDetail(
            title: nil, coverImageUrl: nil,
            region: "제주도",
            travelStartDate: "2026-03-01", travelEndDate: "2026-03-05",
            musicUrl: nil
        )
        let stub = StubAlbumService(fetchResult: .success(detail))
        let sut = makeSUT(stub: stub)
        await sut.load()
        XCTAssertEqual(sut.destination, "제주도")
    }

    // withLyrics: true -> lyricsOption = .include
    func test_load_setsLyricsOptionInclude_whenWithLyricsTrue() async {
        let detail = AlbumDetail(
            title: nil, coverImageUrl: nil,
            region: "서울",
            travelStartDate: "2026-01-01", travelEndDate: "2026-01-05",
            musicUrl: nil, withLyrics: true
        )
        let stub = StubAlbumService(fetchResult: .success(detail))
        let sut = makeSUT(stub: stub)
        await sut.load()
        XCTAssertEqual(sut.lyricsOption, .include)
    }

    // withLyrics: false -> lyricsOption = .exclude
    func test_load_setsLyricsOptionExclude_whenWithLyricsFalse() async {
        let detail = AlbumDetail(
            title: nil, coverImageUrl: nil,
            region: "서울",
            travelStartDate: "2026-01-01", travelEndDate: "2026-01-05",
            musicUrl: nil, withLyrics: false
        )
        let stub = StubAlbumService(fetchResult: .success(detail))
        let sut = makeSUT(stub: stub)
        await sut.load()
        XCTAssertEqual(sut.lyricsOption, .exclude)
    }

    // vocalGender pre-fill
    func test_load_setsVocalGender() async {
        let detail = AlbumDetail(
            title: nil, coverImageUrl: nil,
            region: "서울",
            travelStartDate: "2026-01-01", travelEndDate: "2026-01-05",
            musicUrl: nil, vocalGender: .male, withLyrics: true
        )
        let stub = StubAlbumService(fetchResult: .success(detail))
        let sut = makeSUT(stub: stub)
        await sut.load()
        XCTAssertEqual(sut.vocalGender, .male)
    }

    // 날짜 응답 있으면 hasDateSelected = true
    func test_load_setsHasDateSelectedToTrue() async {
        let stub = StubAlbumService()
        let sut = makeSUT(stub: stub)
        await sut.load()
        XCTAssertTrue(sut.hasDateSelected)
    }

    // MARK: - submitEdit

    // isValid false -> toastMessage 설정, 서비스 미호출
    func test_submitEdit_invalidInput_setsToastMessageWithoutServiceCall() async {
        let stub = StubAlbumService()
        let sut = makeSUT(stub: stub)
        // selectedImage nil, coverImageUrl nil → isValid = false
        await sut.submitEdit()
        XCTAssertNotNil(sut.toastMessage)
        XCTAssertEqual(stub.updateCallCount, 0)
    }

    // 유효한 입력 + 서비스 성공 -> onSaved 콜백 호출
    func test_submitEdit_success_callsOnSaved() async {
        let stub = StubAlbumService(updateResult: .success(()))
        var onSavedCalled = false
        let sut = makeSUT(stub: stub, onSaved: { _ in onSavedCalled = true })
        setupValidInput(sut)
        await sut.submitEdit()
        XCTAssertTrue(onSavedCalled)
        XCTAssertEqual(stub.updateCallCount, 1)
    }

    // 유효한 입력 + 서버 에러 -> toastMessage 설정
    func test_submitEdit_serviceError_setsToastMessage() async {
        let stub = StubAlbumService(updateResult: .failure(APIClientError.serverError(.e400)))
        let sut = makeSUT(stub: stub)
        setupValidInput(sut)
        await sut.submitEdit()
        XCTAssertNotNil(sut.toastMessage)
        XCTAssertEqual(stub.updateCallCount, 1)
    }

    // 유효한 입력 + 네트워크 에러 -> toastMessage 설정
    func test_submitEdit_networkError_setsToastMessage() async {
        let urlError = URLError(.notConnectedToInternet)
        let stub = StubAlbumService(updateResult: .failure(APIClientError.networkError(urlError)))
        let sut = makeSUT(stub: stub)
        setupValidInput(sut)
        await sut.submitEdit()
        XCTAssertNotNil(sut.toastMessage)
        XCTAssertEqual(stub.updateCallCount, 1)
    }
}
