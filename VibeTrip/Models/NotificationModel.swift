//
//  NotificationModel.swift
//  VibeTrip
//
//  Created by CHOI on 3/25/26.
//

import Foundation

// MARK: - NotificationType

// 알림 종류: 앨범 생성 중 / 완료 / 실패
enum NotificationType {
    case generating
    case completed(albumId: String)
    case failed
}

// MARK: - NotificationItem

// 개별 알림 데이터
struct NotificationItem: Identifiable {
    let id: String
    let type: NotificationType
    let title: String
    let body: String
    let createdAt: Date
    var isRead: Bool
}
