//
//  AppleAuthService.swift
//  VibeTrip
//
//  Created by CHOI on 3/20/26.
//

// 애플 로그인 서비스 구현체
// ASAuthorizationController를 직접 생성해 코드로 Apple 로그인 UI 트리거
// 로그인 성공 시: (identityToken, fullName) 반환
// 사용자 취소 시: LoginError.cancelled throw

import Foundation
import AuthenticationServices
import UIKit

final class AppleAuthService: NSObject, AppleAuthServiceProtocol {

    private var continuation: CheckedContinuation<(identityToken: String, fullName: String?), Error>?
    // ASAuthorizationController를 강한 참조로 유지 (auth 완료 전 해제 방지)
    private var controller: ASAuthorizationController?

    func login() async throws -> (identityToken: String, fullName: String?) {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthService: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        defer { self.controller = nil }

        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let identityToken = String(data: tokenData, encoding: .utf8)
        else {
            continuation?.resume(throwing: LoginError.providerError)
            continuation = nil
            return
        }

        let nameParts = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
        let fullName: String? = nameParts.isEmpty ? nil : nameParts.joined(separator: " ")

        continuation?.resume(returning: (identityToken: identityToken, fullName: fullName))
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        defer { self.controller = nil }

        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation?.resume(throwing: LoginError.cancelled)
        } else {
            continuation?.resume(throwing: LoginError.providerError)
        }
        continuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleAuthService: ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return UIWindow()
        }
        return scene.windows.first ?? UIWindow(windowScene: scene)
    }
}
