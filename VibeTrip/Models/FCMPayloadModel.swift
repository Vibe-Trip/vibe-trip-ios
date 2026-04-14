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

// MARK: - FCMPayload 디코딩

extension FCMPayload {

    // FCM userInfo에서 커스텀 payload 디코딩 (래핑 유무 모두 지원)
    static func decode(from userInfo: [AnyHashable: Any]) -> FCMPayload? {
        let decoder = JSONDecoder()

        if let payloadObject = userInfo["payload"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: payloadObject),
           let payload = try? decoder.decode(FCMPayload.self, from: data) {
            return payload
        }

        if let payloadString = userInfo["payload"] as? String,
           let data = payloadString.data(using: .utf8),
           let payload = try? decoder.decode(FCMPayload.self, from: data) {
            return payload
        }

        // payload 래핑이 없는 형식도 대비
        if let data = try? JSONSerialization.data(withJSONObject: userInfo),
           let payload = try? decoder.decode(FCMPayload.self, from: data) {
            return payload
        }
        return nil
    }
}

// MARK: - FCMPayload → NotificationNavigationAction 변환

extension FCMPayload {

    // 알림 타입에 따라 이동할 화면 반환
    func toNavigationAction() -> NotificationNavigationAction? {
        switch type {
        case "CREATING":
            return .openAlbumCreationLoading
        case "COMPLETED":
            // albumId 누락 시 홈 탭으로 이동하는 fallback 처리
            guard let albumId = data?.albumId else { return .openHome }
            return .openAlbumDetail(albumId: String(albumId))
        case "FAILED":
            return .openMakeAlbum
        default:
            return nil
        }
    }
}
