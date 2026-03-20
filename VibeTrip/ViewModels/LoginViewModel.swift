//
//  LoginViewModel.swift
//  VibeTrip
//
//  Created by CHOI on 3/15/26.
//

// 로그인 화면 비즈니스 로직 담당
// 플로우: 소셜 로그인 -> 백엔드 JWT 요청 -> 결과 처리

import Foundation
import UIKit
import Combine
import AuthenticationServices
import FirebaseMessaging

@MainActor
final class LoginViewModel: ObservableObject {
    
    // MARK: - Published
    
    // 로그인 진행 여부: 버튼 비활성화 + 스피너 표시
    @Published var isLoading: Bool = false
    
    // 에러 발생 시 표시할 UI 결정
    @Published var errorState: LoginErrorState? = nil {   /// nil: 에러 UI X
        didSet {
            if case .toast = errorState {
                scheduleToastDismissal()
            }
        }
    }

    // 로그인 성공 시 true -> fullScreenCover 전환 트리거
    @Published var isLoggedIn: Bool = false

    // MARK: - Private

    private var toastTask: Task<Void, Never>?
    private var lastLoginProvider: LoginProvider?

    // MARK: - Dependencies
    
    private let kakaoAuthService: KakaoAuthServiceProtocol
    private let appleAuthService: AppleAuthServiceProtocol
    private let backendAuthService: BackendAuthServiceProtocol
    
    // MARK: - Init
    // 현재: MockBackendAuthService

    init(
        kakaoAuthService: KakaoAuthServiceProtocol? = nil,
        appleAuthService: AppleAuthServiceProtocol? = nil,
        backendAuthService: BackendAuthServiceProtocol? = nil     // TODO: BackendAuthService()로 교체
    ) {
        self.kakaoAuthService = kakaoAuthService ?? KakaoAuthService()
        self.appleAuthService = appleAuthService ?? AppleAuthService()
        self.backendAuthService = backendAuthService ?? MockBackendAuthService()
    }
    
    // MARK: - 카카오 로그인
    
    func loginWithKakao() {
        guard !isLoading else { return }
        lastLoginProvider = .kakao
        Task { await performKakaoLogin() }
    }

    // MARK: - 애플 로그인

    // SignInWithAppleButton onCompletion 결과 처리(초기 로그인)
    func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        guard !isLoading else { return }
        lastLoginProvider = .apple
        Task {
            isLoading = true
            errorState = nil
            defer { isLoading = false }

            do {
                let authorization = try result.get()
                guard
                    let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                    let tokenData = credential.identityToken,
                    let identityToken = String(data: tokenData, encoding: .utf8)
                else {
                    errorState = LoginError.providerError.errorState
                    return
                }

                let nameParts = [credential.fullName?.givenName, credential.fullName?.familyName]
                    .compactMap { $0 }
                let fullName: String? = nameParts.isEmpty ? nil : nameParts.joined(separator: " ")

                print("애플 identityToken: \(identityToken)")
                print("애플 fullName: \(fullName ?? "null")")

                try await performBackendAuth(token: identityToken, provider: .apple, fullName: fullName)

            } catch let authError as ASAuthorizationError where authError.code == .canceled {
                return
            } catch let loginError as LoginError {
                if loginError == .cancelled { return }
                errorState = loginError.errorState
            } catch {
                errorState = LoginError.providerError.errorState
            }
        }
    }

    // AppleAuthService를 통한 애플 로그인 (재시도 경로)
    func loginWithApple() {
        guard !isLoading else { return }
        lastLoginProvider = .apple
        Task { await performAppleLogin() }
    }

    // 재시도
    func retryLogin() {
        switch lastLoginProvider {
        case .kakao: loginWithKakao()
        case .apple: loginWithApple()
        case nil: break
        }
    }

    // MARK: - 토스트 자동 닫힘

    private func scheduleToastDismissal() {
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            if case .toast = errorState {
                errorState = nil
            }
        }
    }

    // MARK: - 로그인 플로우

    private func performKakaoLogin() async {
        isLoading = true
        errorState = nil
        defer { isLoading = false }

        do {
            /// 카카오 토큰 획득
            let token = try await kakaoAuthService.login()
            print("카카오 accessToken: \(token)")
            try await performBackendAuth(token: token, provider: .kakao)
        } catch let loginError as LoginError {
            if loginError == .cancelled { return }
            errorState = loginError.errorState
        } catch {
            errorState = LoginError.providerError.errorState
        }
    }

    private func performAppleLogin() async {
        isLoading = true
        errorState = nil
        defer { isLoading = false }

        do {
            let (identityToken, fullName) = try await appleAuthService.login()
            print("애플 identityToken: \(identityToken)")
            print("애플 fullName: \(fullName ?? "null")")
            try await performBackendAuth(token: identityToken, provider: .apple, fullName: fullName)
        } catch let loginError as LoginError {
            /// 취소: 에러 UI 없이 그대로 로그인 화면 유지
            if loginError == .cancelled { return }
            errorState = loginError.errorState
        } catch {
            errorState = LoginError.providerError.errorState
        }
    }

    // FCM 토큰 획득, 실패 시 LoginError.networkError throw
    private func fetchFCMToken() async throws -> String {
        do {
            return try await Messaging.messaging().token()
        } catch {
            throw LoginError.networkError
        }
    }

    // 카카오&애플 공통 백엔드 인증 요청
    private func performBackendAuth(token: String, provider: LoginProvider, fullName: String? = nil) async throws {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        let fcmToken = try await fetchFCMToken()
        print("deviceId: \(deviceId)")
        print("fcmToken: \(fcmToken)")
        print("백엔드 요청. provider: \(provider.rawValue)")

        let authToken = try await backendAuthService.authenticate(
            token: token,
            provider: provider,
            deviceId: deviceId,
            fcmToken: fcmToken,
            fullName: fullName
        )

        // TODO: Keychain 저장으로 변경
        print("로그인 성공. userId: \(authToken.userId), accessToken: \(authToken.accessToken)")
        isLoggedIn = true
    }
}
