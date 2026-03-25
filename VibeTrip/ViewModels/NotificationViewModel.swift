//
//  NotificationViewModel.swift
//  VibeTrip
//
//  Created by CHOI on 3/25/26.
//

import Foundation
import Combine

// MARK: - NotificationViewModel

@MainActor
final class NotificationViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) var notifications: [NotificationItem] = []
    @Published private(set) var toastMessage: String?

    // MARK: - Constants

    private enum ToastMessage {
        static let deleted = "알림이 삭제 되었어요"
    }

    private enum ToastDuration: Double {
        case standard = 2.5
    }

    // MARK: - Computed

    var isEmpty: Bool { notifications.isEmpty }

    // MARK: - Init

    nonisolated init() {}

    // MARK: - Public Methods

    func loadNotifications() async {
        // TODO: API 연동 후 notifications 업데이트
    }

    func deleteNotification(id: String) async {
        notifications.removeAll { $0.id == id }
        showToast(ToastMessage.deleted)
    }

    // 탭 진입 시 모든 알림을 읽음 처리 (레드 닷 제거용)
    func markAllAsRead() {
        notifications = notifications.map {
            var item = $0
            item.isRead = true
            return item
        }
    }

    // MARK: - Private Methods

    func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: UInt64(ToastDuration.standard.rawValue * 1_000_000_000))
            toastMessage = nil
        }
    }
}
