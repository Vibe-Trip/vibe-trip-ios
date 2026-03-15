//
//  AuthToken.swift
//  VibeTrip
//
//  Created by CHOI on 3/15/26.
//


// 백엔드 로그인 응답 데이터 구조 정의
// 카카오 or 애플 로그인 성공 후 서버 발급 JWT 토큰, 유저 식별자 수신

import Foundation

struct AuthToken: Decodable {
    /// API 요청 시 Authorization 헤더에 사용 토큰(단기)
    let accessToken: String

    /// accessToken 만료 시 갱신 요청에 사용 토큰(장기)
    let refreshToken: String

    /// 서버가 부여한 유저 식별자
    let userId: String
}
