//
//  LoginError.swift
//  VibeTrip
//
//  Created by CHOI on 3/15/26.
//


// 로그인 에러 케이스

import Foundation

enum LoginError: Error {
    /// 카카오 또는 애플 SDK 내부 오류
    case providerError

    /// 네트워크 연결 불안정
    case networkError

    /// 백엔드 응답 지연
    case timeout

    /// 백엔드 에러코드 기반 오류
    case backendError(BackendErrorCode)

    /// 사용자가 시스템 팝업에서 직접 취소
    case cancelled
}

// MARK: - 에러 UI 상태 타입

enum LoginErrorState: Equatable {
    /// 토스트 메시지
    case toast(message: String)

    /// 재시도 팝업
    case retryPopup(message: String)
}

// MARK: - LoginError -> LoginErrorState 변환

extension LoginError {
    /// 에러 타입 별 UI 상태 반환
    var errorState: LoginErrorState? {
        switch self {
        case .providerError:
            return .toast(message: "로그인 서비스에 일시적인 문제가 생겼습니다.")
        case .networkError:
            return .toast(message: "네트워크 연결이 원활하지 않습니다.")
        case .timeout:
            return .retryPopup(message: "지금은 로그인이 원활하지 않습니다.\n연결 상태를 확인하고 다시 시도해 주세요.")
        case .backendError(let code):
            return code.loginErrorState
        case .cancelled:
            return nil
        }
    }
}
