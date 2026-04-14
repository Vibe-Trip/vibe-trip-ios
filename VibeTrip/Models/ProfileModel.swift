//
//  ProfileModel.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import Foundation

// 사용자 프로필 모델
struct UserProfile: Decodable {
    let nickname: String
    let email: String?
    let profileImageUrl: String?
    let albumCount: Int
    let albumLogCount: Int

    private enum CodingKeys: String, CodingKey {
        case nickname       = "name"
        case email
        case profileImageUrl = "profileImage"
        case albumCount
        case albumLogCount
    }
}

#if DEBUG
extension UserProfile {
    static let mock = UserProfile(
        nickname: "여행자",
        email: "traveler@example.com",
        profileImageUrl: nil,
        albumCount: 3,
        albumLogCount: 12
    )
}
#endif
