//
//  AppleAuthService.swift
//  VibeTrip
//
//  Created by CHOI on 3/15/26.
//


// Apple 로그인 SDK 호출
// 로그인 성공 시: Apple identityToken(JWT) 반환
// 사용자가 취소 시: LoginError.cancelled throw
// "나의 이메일 가리기" 선택 시: Apple relay 이메일(가상 이메일) 전달

import Foundation
import AuthenticationServices

final class AppleAuthService: NSObject, AppleAuthServiceProtocol {
    
    private var continuation: CheckedContinuation<String, Error>?
    
    func login() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            // 요청할 정보: 이름, 이메일 (최초 로그인 시에만 제공됨)
            request.requestedScopes = [.fullName, .email]
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthService: ASAuthorizationControllerDelegate {
    
    // 로그인 성공
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let identityToken = String(data: tokenData, encoding: .utf8)
        else {
            continuation?.resume(throwing: LoginError.providerError)
            continuation = nil
            return
        }
        
        continuation?.resume(returning: identityToken)
        continuation = nil
    }
    
    // 로그인 실패 or 취소
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let authError = error as? ASAuthorizationError
        if authError?.code == .canceled {
            continuation?.resume(throwing: LoginError.cancelled)
        } else {
            continuation?.resume(throwing: LoginError.providerError)
        }
        continuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleAuthService: ASAuthorizationControllerPresentationContextProviding {
    
    // Apple 로그인 시트를 표시할 윈도우 지정
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
