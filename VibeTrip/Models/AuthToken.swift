//
//  AuthToken.swift
//  VibeTrip
//
//  Created by CHOI on 3/15/26.
//


// 백엔드 로그인 응답 데이터 구조 정의
// 카카오 or 애플 로그인 성공 후 서버 발급 JWT 토큰 수신

import Foundation

struct AuthToken: Decodable {
    /// API 요청 시 Authorization 헤더에 사용 토큰(단기)
    let accessToken: String

    /// accessToken 만료 시 갱신 요청에 사용 토큰(장기)
    let refreshToken: String
}

// MARK: - 공통 API 응답

struct ApiResponse<T: Decodable>: Decodable {
    /// 응답 결과 : SUCCESS or ERROR
    let resultType: String

    /// 성공 시 실제 데이터
    let data: T?

    /// 실패 시 에러 정보
    let error: ApiError?
}

struct ApiError: Decodable {
    let errorCode: String
    let message: String
}
