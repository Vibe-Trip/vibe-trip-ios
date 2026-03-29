//
//  NotificationModel.swift
//  VibeTrip
//
//  Created by CHOI on 3/25/26.
//

import Foundation

// MARK: - NotificationType

// 알림 case
enum NotificationType {
    // 앨범 생성 중
    case generating
    // 앨범 생성 완료
    case completed(albumId: String) /// albumId: 이동할 앨범 식별자
    // 앨범 생성 실패
    case failed
}

// MARK: - NotificationItem

// 개별 알림 데이터
struct NotificationItem: Identifiable {
    let id: String              // 알림 고유 식별자
    let type: NotificationType  // 알림 종류
    let title: String           // 알림 제목
    let body: String            // 알림 본문
    let createdAt: Date         // 알림 생성 시각
    var isRead: Bool            // 읽음 여부
}
