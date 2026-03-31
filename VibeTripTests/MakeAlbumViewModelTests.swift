//
//  MakeAlbumViewModelTests.swift
//  VibeTrip
//
//  Created by CHOI on 3/31/26.
//

import XCTest
@testable import VibeTrip

// MARK: - StubAlbumService

// 순서대로 지정한 결과 반환
// results 배열 소진: 마지막 결과를 계속 반환
private final class StubAlbumService: AlbumServiceProtocol {

    var results: [Result<AlbumCreateResponse, Error>]
    private(set) var callCount = 0

    init(results: [Result<AlbumCreateResponse, Error>]) {
        self.results = results
    }

    func createAlbum(request: AlbumCreateRequest) async throws -> AlbumCreateResponse {
        callCount += 1
        // results: 1개 남으면 소비하지 않고 유지 (이후 호출에도 동일 결과 반환)
        let result = results.count > 1 ? results.removeFirst() : results.first!
        switch result {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }

    func fetchAlbums(cursor: String?, limit: Int) async throws -> AlbumListPayload { fatalError("미사용") }
    func fetchAlbumLog(albumId: String) async throws -> AlbumLog { fatalError("미사용") }
    func updateAlbum(albumId: String, request: AlbumUpdateRequest) async throws -> AlbumCard { fatalError("미사용") }
    func deleteAlbum(albumId: String) async throws { fatalError("미사용") }
    func saveLog(request: AlbumLogRequest) async throws -> AlbumLog { fatalError("미사용") }
}

// MARK: - MakeAlbumViewModelTests

@MainActor
final class MakeAlbumViewModelTests: XCTestCase {

    var sut: MakeAlbumViewModel!

    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - 헬퍼

    // 지정한 서비스 스텁으로 ViewModel 초기화
    private func makeSUT(stub: StubAlbumService) {
        sut = MakeAlbumViewModel(albumService: stub)
    }

    // 필수 입력 항목을 모두 채운 유효 상태로 설정
    private func setupValidInput(lyricsOption: LyricsOption = .exclude, vocalGender: VocalGender? = nil) {
        sut.selectedPhotoData = Data([0x00])
        sut.selectedPhotoImage = nil
        sut.album.travelDestination = "서울"
        sut.album.startDate = Date()
        sut.album.endDate = Date()
        sut.album.lyricsOption = lyricsOption
        sut.album.vocalGender = vocalGender
    }

    // MARK: - isRequiredInputValid

    // 모든 필수 항목 입력 (가사 미포함) -> true
    func test_isRequiredInputValid_whenAllFieldsFilled_exclude_returnsTrue() {
        makeSUT(stub: StubAlbumService(results: [.success(AlbumCreateResponse(albumId: 1))]))
        setupValidInput(lyricsOption: .exclude)
        XCTAssertTrue(sut.isRequiredInputValid)
    }

    // 모든 필수 항목 입력 (가사 포함 + vocalGender 있음) -> true
    func test_isRequiredInputValid_whenAllFieldsFilled_includeWithGender_returnsTrue() {
        makeSUT(stub: StubAlbumService(results: [.success(AlbumCreateResponse(albumId: 1))]))
        setupValidInput(lyricsOption: .include, vocalGender: .female)
        XCTAssertTrue(sut.isRequiredInputValid)
    }

    // 사진 미선택 -> false
    func test_isRequiredInputValid_whenNoPhoto_returnsFalse() {
        makeSUT(stub: StubAlbumService(results: [.success(AlbumCreateResponse(albumId: 1))]))
        setupValidInput()
        sut.selectedPhotoData = nil
        XCTAssertFalse(sut.isRequiredInputValid)
    }

    // 날짜 미선택 -> false
    func test_isRequiredInputValid_whenNoDates_returnsFalse() {
        makeSUT(stub: StubAlbumService(results: [.success(AlbumCreateResponse(albumId: 1))]))
        setupValidInput()
        sut.album.startDate = nil
        sut.album.endDate = nil
        XCTAssertFalse(sut.isRequiredInputValid)
    }

    // 가사 포함인데 vocalGender 미선택 -> false
    func test_isRequiredInputValid_whenLyricsIncludeButNoVocalGender_returnsFalse() {
        makeSUT(stub: StubAlbumService(results: [.success(AlbumCreateResponse(albumId: 1))]))
        setupValidInput(lyricsOption: .include, vocalGender: nil)
        XCTAssertFalse(sut.isRequiredInputValid)
    }

    // MARK: - submitAlbum: 성공

    // API 성공 -> onSuccess 콜백에 albumId 전달
    func test_submitAlbum_success_callsOnSuccess() async {
        let stub = StubAlbumService(results: [.success(AlbumCreateResponse(albumId: 99))])
        makeSUT(stub: stub)
        setupValidInput()

        let expectation = expectation(description: "onSuccess 호출")
        var receivedAlbumId: Int?

        sut.submitAlbum(
            onStarted: {},
            onSuccess: { albumId in
                receivedAlbumId = albumId
                expectation.fulfill()
            },
            onNetworkError: { _ in XCTFail("onNetworkError가 호출되면 안 됩니다") },
            onFatalError: { XCTFail("onFatalError가 호출되면 안 됩니다") }
        )

        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(receivedAlbumId, 99)
        XCTAssertEqual(stub.callCount, 1)
    }

    // MARK: - submitAlbum: 네트워크 오류 (첫 시도)

    // 첫 시도 네트워크 오류 -> onNetworkError 콜백 호출 (재시도 클로저 포함)
    func test_submitAlbum_networkError_firstAttempt_callsOnNetworkError() async {
        let urlError = URLError(.notConnectedToInternet)
        let stub = StubAlbumService(results: [.failure(APIClientError.networkError(urlError))])
        makeSUT(stub: stub)
        setupValidInput()

        let expectation = expectation(description: "onNetworkError 호출")

        sut.submitAlbum(
            onStarted: {},
            onSuccess: { _ in XCTFail("onSuccess가 호출되면 안 됩니다") },
            onNetworkError: { _ in expectation.fulfill() },
            onFatalError: { XCTFail("onFatalError가 호출되면 안 됩니다") }
        )

        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(stub.callCount, 1)
    }

    // MARK: - submitAlbum: 네트워크 오류 후 재시도 성공

    // 첫 시도 네트워크 오류 -> 재시도 성공 -> onSuccess 콜백 호출
    func test_submitAlbum_networkError_retrySuccess_callsOnSuccess() async {
        let urlError = URLError(.notConnectedToInternet)
        let stub = StubAlbumService(results: [
            .failure(APIClientError.networkError(urlError)),    // 첫 시도: 실패
            .success(AlbumCreateResponse(albumId: 55))          // 재시도: 성공
        ])
        makeSUT(stub: stub)
        setupValidInput()

        let networkErrorExpectation = expectation(description: "onNetworkError 호출")
        let successExpectation = expectation(description: "onSuccess 호출")
        var receivedAlbumId: Int?

        sut.submitAlbum(
            onStarted: {},
            onSuccess: { albumId in
                receivedAlbumId = albumId
                successExpectation.fulfill()
            },
            onNetworkError: { retryAction in
                networkErrorExpectation.fulfill()
                retryAction()  // 바로 재시도 실행
            },
            onFatalError: { XCTFail("onFatalError가 호출되면 안 됩니다") }
        )

        await fulfillment(of: [networkErrorExpectation, successExpectation], timeout: 2.0)
        XCTAssertEqual(receivedAlbumId, 55)
        XCTAssertEqual(stub.callCount, 2)
    }

    // MARK: - submitAlbum: 재시도도 실패

    // 첫 시도 네트워크 오류 -> 재시도도 네트워크 오류 -> onFatalError 호출
    func test_submitAlbum_networkError_retryAlsoFails_callsOnFatalError() async {
        let urlError = URLError(.notConnectedToInternet)
        let stub = StubAlbumService(results: [
            .failure(APIClientError.networkError(urlError)),    // 첫 시도: 실패
            .failure(APIClientError.networkError(urlError))    // 재시도: 실패
        ])
        makeSUT(stub: stub)
        setupValidInput()

        let networkErrorExpectation = expectation(description: "onNetworkError 호출")
        let fatalErrorExpectation = expectation(description: "onFatalError 호출")

        sut.submitAlbum(
            onStarted: {},
            onSuccess: { _ in XCTFail("onSuccess가 호출되면 안 됩니다") },
            onNetworkError: { retryAction in
                networkErrorExpectation.fulfill()
                retryAction()
            },
            onFatalError: { fatalErrorExpectation.fulfill() }
        )

        await fulfillment(of: [networkErrorExpectation, fatalErrorExpectation], timeout: 2.0)
        XCTAssertEqual(stub.callCount, 2)
    }

    // MARK: - submitAlbum: 서버 오류

    // 서버 오류 (재시도 불가) -> 바로 onFatalError 호출
    func test_submitAlbum_serverError_callsOnFatalError() async {
        let stub = StubAlbumService(results: [.failure(APIClientError.serverError(.e400))])
        makeSUT(stub: stub)
        setupValidInput()

        let expectation = expectation(description: "onFatalError 호출")

        sut.submitAlbum(
            onStarted: {},
            onSuccess: { _ in XCTFail("onSuccess가 호출되면 안 됩니다") },
            onNetworkError: { _ in XCTFail("onNetworkError가 호출되면 안 됩니다") },
            onFatalError: { expectation.fulfill() }
        )

        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(stub.callCount, 1)
    }
}
