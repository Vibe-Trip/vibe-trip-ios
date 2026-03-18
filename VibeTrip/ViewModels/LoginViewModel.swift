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

@MainActor
final class LoginViewModel: ObservableObject {
    
    // MARK: - Published
    // View 바인딩
    
    // 로그인 진행 여부: 버튼 비활성화 + 스피너 표시
    @Published var isLoading: Bool = false
    
    // 에러 발생 시 표시할 UI 결정
    @Published var errorState: LoginErrorState? = nil   /// nil: 에러 UI X
    
    // 로그인 성공 시 true -> fullScreenCover 전환 트리거
    @Published var isLoggedIn: Bool = false
    
    // MARK: - Dependencies
    
    private let kakaoAuthService: KakaoAuthServiceProtocol
    private let backendAuthService: BackendAuthServiceProtocol
    
    // MARK: - Init
    // 현재: MockBackendAuthService

    init(
        kakaoAuthService: KakaoAuthServiceProtocol? = nil,
        backendAuthService: BackendAuthServiceProtocol? = nil     // TODO: BackendAuthService()로 교체
    ) {
        self.kakaoAuthService = kakaoAuthService ?? KakaoAuthService()
        self.backendAuthService = backendAuthService ?? MockBackendAuthService()
    }
    
    // MARK: - 카카오 로그인
    
    func loginWithKakao() {
        guard !isLoading else { return }   // 중복 탭 방지
        Task { await performLogin() }
    }
    
    // MARK: - 애플 로그인
    
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        guard !isLoading else { return }
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

                let nameParts = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }
                let fullName: String? = nameParts.isEmpty ? nil : nameParts.joined(separator: " ")
                let email = credential.email

                print("애플 identityToken: \(identityToken)")
                print("애플 fullName: \(fullName ?? "null")")
                print("애플 email: \(email ?? "null")")

                let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
                print("deviceId: \(deviceId)")
                print("백엔드 요청. provider: apple")

                let authToken = try await backendAuthService.authenticate(
                    token: identityToken,
                    provider: .apple,
                    deviceId: deviceId,
                    fullName: fullName
                )

                // TODO: Keychain 저장으로 변경
                print("로그인 성공. userId: \(authToken.userId), accessToken: \(authToken.accessToken)")
                isLoggedIn = true

            } catch let authError as ASAuthorizationError where authError.code == .canceled {
                return  // 취소: 에러 UI 없이 유지
            } catch let loginError as LoginError {
                if loginError == .cancelled { return }
                errorState = loginError.errorState
            } catch {
                errorState = LoginError.providerError.errorState
            }
        }
    }

    // MARK: - 카카오 로그인 플로우

    private func performLogin() async {
        isLoading = true
        errorState = nil
        
        defer { isLoading = false }
        
        do {
            // 1. 카카오 토큰 획득
            let token = try await kakaoAuthService.login()
            print("카카오 accessToken: \(token)")

            // 2. 디바이스 ID 추출
            let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
            print("deviceId: \(deviceId)")

            // 3. 백엔드 JWT 요청
            print("백엔드 요청. provider: kakao")
            let authToken = try await backendAuthService.authenticate(
                token: token,
                provider: .kakao,
                deviceId: deviceId
            )
            
            // 4. JWT 저장
            // TODO: Keychain 저장으로 변경
            print("로그인 성공. userId: \(authToken.userId), accessToken: \(authToken.accessToken)")
            
            // 5. 화면 전환 트리거
            isLoggedIn = true
            
        } catch let loginError as LoginError {
            // 취소: 에러 UI 없이 그대로 로그인 화면 유지
            if loginError == .cancelled { return }
            errorState = loginError.errorState
        } catch {
            errorState = LoginError.providerError.errorState
        }
    }
}
