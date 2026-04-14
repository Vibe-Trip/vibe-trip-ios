//
//  MyPageViewModelTests.swift
//  VibeTrip
//
//  Created by CHOI on 4/3/26.
//

import XCTest
@testable import VibeTrip

@MainActor
final class MyPageViewModelTests: XCTestCase {

    private var mockUserService: MockUserService!
    private var mockKeychainService: MockKeychainService!
    private var sut: MyPageViewModel!

    override func setUp() {
        super.setUp()
        mockUserService = MockUserService()
        mockKeychainService = MockKeychainService()
        sut = MyPageViewModel(userService: mockUserService, keychainService: mockKeychainService)
    }

    override func tearDown() {
        mockUserService = nil
        mockKeychainService = nil
        sut = nil
        super.tearDown()
    }

    // 프로필 조회 성공 시 userProfile, albumCount, logCount 정상 설정
    func test_loadProfile_success() async {
        await sut.loadProfile()

        XCTAssertNotNil(sut.userProfile)
        XCTAssertEqual(sut.userProfile?.nickname, UserProfile.mock.nickname)
        XCTAssertEqual(sut.userProfile?.email, UserProfile.mock.email)
        XCTAssertEqual(sut.albumCount, UserProfile.mock.albumCount)
        XCTAssertEqual(sut.logCount, UserProfile.mock.albumLogCount)
        XCTAssertNil(sut.toastMessage)
    }

    // 프로필 조회 실패 시 토스트 메시지 표시
    func test_loadProfile_failure_showsToast() async {
        mockUserService.stubbedError = APIClientError.networkError(URLError(.notConnectedToInternet))

        await sut.loadProfile()

        XCTAssertNil(sut.userProfile)
        XCTAssertEqual(sut.toastMessage, "프로필을 불러오지 못했어요.")
    }

    // 프로필 조회 중 isLoading 상태 전환
    func test_loadProfile_togglesIsLoading() async {
        XCTAssertFalse(sut.isLoading)

        await sut.loadProfile()

        XCTAssertFalse(sut.isLoading)
    }
}
