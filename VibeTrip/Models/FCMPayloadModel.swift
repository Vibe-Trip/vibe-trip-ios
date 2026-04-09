//
//  FCMPayloadModel.swift
//  VibeTrip
//
//  Created by CHOI on 4/7/26.
//

import Foundation

// MARK: - FCMPayload

// FCM 커스텀 페이로드 최상위 구조
struct FCMPayload: Decodable {
    let type: String            // CREATING | COMPLETED | FAILED
    let data: FCMPayloadData?
    let error: FCMPayloadError?
}

// MARK: - FCMPayloadData

// 생성 중 or 완료 시 데이터
struct FCMPayloadData: Decodable {
    let albumId: Int?
    let taskId: String?
}

// MARK: - FCMPayloadError

// 생성 실패 시 에러 정보
struct FCMPayloadError: Decodable {
    let errorCode: String?
    let message: String?
    let data: FCMPayloadErrorData?
}

struct FCMPayloadErrorData: Decodable {
    let albumId: Int?
}

// MARK: - FCMPayload → NotificationNavigationAction 변환

extension FCMPayload {

    // 알림 타입에 따라 이동할 화면 반환
    func toNavigationAction() -> NotificationNavigationAction? {
        switch type {
        case "CREATING":
            return .openAlbumCreationLoading
        case "COMPLETED":
            guard let albumId = data?.albumId else { return nil }
            return .openAlbumDetail(albumId: String(albumId))
        case "FAILED":
            return .openMakeAlbum
        default:
            return nil
        }
    }
}
