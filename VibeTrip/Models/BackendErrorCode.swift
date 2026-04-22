//
//  BackendErrorCode.swift
//  VibeTrip
//
//  Created by CHOI on 3/25/26.
//

// 백엔드 ErrorType.kt 기준 에러코드 정의
// response body의 error.errorCode 필드값과 동일한 rawValue 사용

import Foundation

enum BackendErrorCode: String {
    // MARK: - General
    case e400 = "E400"
    case e401 = "E401"
    case e403 = "E403"
    case e404 = "E404"
    case e409 = "E409"
    case e429 = "E429"
    case e500 = "E500"

    // MARK: - Member
    case e1000 = "E1000"
    case e1001 = "E1001"
    case e1002 = "E1002"
    case e1003 = "E1003"

    // MARK: - Security / JWT
    case e2000 = "E2000"
    case e2001 = "E2001"
    case e2002 = "E2002"
    case e2003 = "E2003"
    case e2004 = "E2004"
    case e2005 = "E2005"
    case e2006 = "E2006"

    // MARK: - OAuth
    case e2007 = "E2007"

    // MARK: - Apple
    case e2008 = "E2008"
    case e2009 = "E2009"
    case e2010 = "E2010"

    /// 미정의 에러코드 
    case unknown
}

// MARK: - LoginErrorState 변환

extension BackendErrorCode {
    var loginErrorState: LoginErrorState {
        switch self {
        case .e429:
            return .retryPopup(message: "지금은 로그인이 원활하지 않습니다.\n연결 상태를 확인하고 다시 시도해 주세요.")
        case .e400, .e401, .e403, .e404, .e409, .e500,
             .e1000, .e1001, .e1002, .e1003,
             .e2000, .e2001, .e2002, .e2003, .e2004, .e2005, .e2006, .e2007, .e2008, .e2009, .e2010,
             .unknown:
            return .toast(message: "로그인 서비스에 일시적인 문제가 생겼습니다.")
        }
    }
}
