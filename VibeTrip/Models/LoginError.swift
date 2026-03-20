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

    /// 운영 정책에 의해 차단된 계정
    case accountBlocked

    /// 사용자가 시스템 팝업에서 직접 취소
    case cancelled
}

// MARK: - 에러 UI 상태 타입

enum LoginErrorState: Equatable {
    /// 토스트 메시지
    case toast(message: String)

    /// 재시도 팝업
    case retryPopup(message: String)

    /// 확인 팝업
    case alertPopup(message: String)
}

// MARK: - LoginError -> LoginErrorState 변환

extension LoginError {
    /// 에러 타입 별 UI 상태 반환
    var errorState: LoginErrorState? {
        switch self {
        case .providerError:
            return .toast(message: "소셜 로그인 서비스에 일시적인 문제가 생겼습니다. 한 번 다시 시도해주세요.")
        case .networkError:
            return .toast(message: "네트워크 연결이 원활하지 않습니다.")
        case .timeout:
            return .retryPopup(message: "로그인 서버 응답이 지연되고 있어요. \n잠시 후 다시 시도해주세요.")
        case .accountBlocked:
            return .alertPopup(message: "운영 정책에 따라 이용이 제한된 계정입니다. 고객센터에 문의해 주세요.")
        case .cancelled:
            return nil
        }
    }
}
