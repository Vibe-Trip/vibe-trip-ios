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
        guard !isLoading else { return }   // 중복 탭 방지
        Task { await performLogin(provider: .kakao) }
    }
    
    // MARK: - 애플 로그인
    
    func loginWithApple() {
        guard !isLoading else { return }   // 중복 탭 방지
        Task { await performLogin(provider: .apple) }
    }
    
    // MARK: - 로그인 플로우(공통)
    
    private func performLogin(provider: LoginProvider) async {
        isLoading = true
        errorState = nil
        
        defer { isLoading = false }
        
        do {
            // 1. 소셜 토큰 획득
            let token: String
            switch provider {
            case .kakao:
                token = try await kakaoAuthService.login()
                print("카카오 accessToken: \(token)")
            case .apple:
                token = try await appleAuthService.login()
                print("애플 identityToken: \(token)")
            }
            
            // 2. 디바이스 ID 추출
            let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
            
            print("deviceId: \(deviceId)")

            // 3. 백엔드 JWT 요청
            print("백엔드 요청. provider: \(provider.rawValue)")
            let authToken = try await backendAuthService.authenticate(
                token: token,
                provider: provider,
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
