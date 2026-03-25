//
//  ProfileModel.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import Foundation

// 사용자 프로필 모델
struct UserProfile {
    let userId: String
    let nickname: String
    let profileImageUrl: String?
    let email: String?
    let provider: String  // Kakao or Apple
}

#if DEBUG
extension UserProfile {
    static let mock = UserProfile(
        userId: "mock-user-001",
        nickname: "여행자",
        profileImageUrl: nil,
        email: "traveler@example.com",
        provider: "KAKAO"
    )
}
#endif
