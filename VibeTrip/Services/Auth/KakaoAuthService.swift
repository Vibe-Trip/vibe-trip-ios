//
//  KakaoAuthService.swift
//  VibeTrip
//
//  Created by CHOI on 3/15/26.
//

// 카카오 SDK 호출 서비스 구현체
// 기기에 카카오톡 설치O :앱 로그인, 미설치: 웹 로그인
// 로그인 성공 시: accessToken을 반환
// 사용자가 취소 시: LoginError.cancelled throw

import Foundation
import KakaoSDKCommon
import KakaoSDKAuth
import KakaoSDKUser

final class KakaoAuthService: KakaoAuthServiceProtocol {
    
    func login() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            // 카카오톡 앱 설치 여부에 따라 분기
            if UserApi.isKakaoTalkLoginAvailable() {
                // 앱 로그인
                UserApi.shared.loginWithKakaoTalk { oauthToken, error in
                    continuation.resume(with: self.handle(oauthToken: oauthToken, error: error))
                }
            } else {
                // 웹 로그인
                UserApi.shared.loginWithKakaoAccount { oauthToken, error in
                    continuation.resume(with: self.handle(oauthToken: oauthToken, error: error))
                }
            }
        }
    }
    
    // MARK: - 콜백 결과 변환 함수
    
    private func handle(oauthToken: OAuthToken?, error: Error?) -> Result<String, Error> {
        if let error = error {
            // 사용자가 취소
            if let sdkError = error as? SdkError,
               sdkError.isClientFailed,
               sdkError.getClientError().reason == .Cancelled {
                return .failure(LoginError.cancelled)
            }
            return .failure(LoginError.providerError)
        }
        
        guard let accessToken = oauthToken?.accessToken else {
            return .failure(LoginError.providerError)
        }
        
        return .success(accessToken)
    }
}
