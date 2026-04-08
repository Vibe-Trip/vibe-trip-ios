//
//  LoginViewModelTests.swift
//  VibeTripTests
//
//  Created by CHOI on 3/19/26.
//


import XCTest
@testable import VibeTrip

// MARK: - Mock

final class MockKakaoAuthService: KakaoAuthServiceProtocol {
    var result: Result<String, Error> = .success("mock-kakao-token")
    func login() async throws -> String { try result.get() }
}

// MARK: - Tests

@MainActor
final class LoginViewModelTests: XCTestCase {

    // ViewModel 생성 헬퍼
    func makeViewModel(
        kakaoResult: Result<String, Error> = .success("mock-kakao-token"),
        backendError: LoginError? = nil
    ) -> LoginViewModel {
        let kakao = MockKakaoAuthService()
        kakao.result = kakaoResult

        let backend = MockBackendAuthService()
        backend.simulatedError = backendError
        backend.delay = 0   // 테스트에서 딜레이 제거

        return LoginViewModel(kakaoAuthService: kakao, backendAuthService: backend)
    }

    // 로그인 Task 시작/종료를 기다리는 대기 헬퍼
    func waitForTask(_ vm: LoginViewModel) async {
        // Task가 아직 시작 전일 수 있어 한 번 양보
        await Task.yield()

        // isLoading=true 전환 대기 (최대 1초)
        for _ in 0..<100 where !vm.isLoading {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        // Task 종료 대기 (최대 3초)
        for _ in 0..<300 where vm.isLoading {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    // MARK: - 테스트 케이스

    // 카카오 로그인 성공:  isLoggedIn == true, errorState == nil
    func test_success_isLoggedIn() async {
        let vm = makeViewModel()
        vm.loginWithKakao()
        await waitForTask(vm)

        XCTAssertTrue(vm.isLoggedIn)
        XCTAssertNil(vm.errorState)
        XCTAssertFalse(vm.isLoading)
    }

    // 카카오 취소: errorState == nil, isLoggedIn == false
    func test_cancelled_noErrorUI() async {
        let vm = makeViewModel(kakaoResult: .failure(LoginError.cancelled))
        vm.loginWithKakao()
        await waitForTask(vm)

        XCTAssertNil(vm.errorState)
        XCTAssertFalse(vm.isLoggedIn)
    }

    // 카카오 공급자 오류(toast)
    func test_providerError_showsToast() async {
        let vm = makeViewModel(kakaoResult: .failure(LoginError.providerError))
        vm.loginWithKakao()
        await waitForTask(vm)

        if case .toast(let msg) = vm.errorState {
            XCTAssertFalse(msg.isEmpty)
        } else {
            XCTFail("toast가 표시되어야 합니다. 실제: \(String(describing: vm.errorState))")
        }
    }

    // 백엔드 네트워크 오류(toast)
    func test_networkError_showsToast() async {
        let vm = makeViewModel(backendError: .networkError)
        vm.loginWithKakao()
        await waitForTask(vm)

        if case .toast(let msg) = vm.errorState {
            XCTAssertFalse(msg.isEmpty)
        } else {
            XCTFail("toast가 표시되어야 합니다. 실제: \(String(describing: vm.errorState))")
        }
    }

    // 백엔드 타임아웃 (PopUp)
    func test_timeout_showsRetryPopup() async {
        let vm = makeViewModel(backendError: .timeout)
        vm.loginWithKakao()
        await waitForTask(vm)

        if case .retryPopup(let msg) = vm.errorState {
            XCTAssertFalse(msg.isEmpty)
        } else {
            XCTFail("retryPopup이 표시되어야 합니다. 실제: \(String(describing: vm.errorState))")
        }
    }

}
