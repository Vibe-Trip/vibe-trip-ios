//
//  NotificationViewModel.swift
//  VibeTrip
//
//  Created by CHOI on 3/25/26.
//

import Foundation

// MARK: - NotificationViewModel

@MainActor
final class NotificationViewModel: ObservableObject {

    // MARK: - Published

    // 화면에 표시할 알림 목록 (외부에서 직접 변경 불가)
    @Published private(set) var notifications: [NotificationItem] = []

    // MARK: - Dependencies

    private let alarmService: AlarmServiceProtocol

    // MARK: - Computed

    // 빈 상태 UI 표시 플래그
    var isEmpty: Bool { notifications.isEmpty }

    // MARK: - Init

    nonisolated init(alarmService: AlarmServiceProtocol = AlarmService()) {
        self.alarmService = alarmService
    }

    #if DEBUG
    // Preview 전용 초기화: 더미 데이터 직접 주입
    init(previewNotifications: [NotificationItem]) {
        self.alarmService = MockAlarmService()
        self.notifications = previewNotifications
    }
    #endif

    // MARK: - Public Methods

    // 서버에서 알림 목록 호출 및 표시
    func loadNotifications() async {
        do {
            let responses = try await alarmService.fetchAlarms()
            // 변환 실패 항목(albumId 없는 COMPLETED 등) 필터링
            notifications = responses.compactMap { $0.toNotificationItem() }
        } catch {
            // 에러 시 기존 목록 유지
        }
    }

    // FCM 포그라운드 수신 시 목록 재조회 -> albumId 기반 교체 자동 처리
    func refreshNotifications() async {
        await loadNotifications()
    }

    // 탭 시 배경색 제거
    func markAsRead(id: String) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[index].isRead = true
    }

    // 알림 삭제
    func deleteNotification(id: String) async {
        guard let alarmId = Int(id) else { return }
        do {
            try await alarmService.deleteAlarm(alarmId: alarmId)
            notifications.removeAll { $0.id == id }
        } catch {
            // 삭제 실패 시 목록 유지 (조용히 처리)
        }
    }

    // 알림 뷰 탈출 시 전체 읽음 처리
    func markAllAsRead() {
        notifications = notifications.map {
            var item = $0
            item.isRead = true
            return item
        }
    }

}
