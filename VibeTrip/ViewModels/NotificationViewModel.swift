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

    // 화면에 표시할 알림 목록
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
            let logItems = responses.map {
                "{alarmId: \($0.alarmId), albumId: \($0.albumId?.description ?? "nil"), alarmType: \($0.alarmType), title: \($0.title)}"
            }.joined(separator: "\n")
            print("[Alarm API] \(logItems)")
            // 재조회 시 기존 읽음 처리된 알림 ID 보존
            let existingReadIds = Set(notifications.filter { $0.isRead }.map { $0.id })
            let newItems = deduplicated(responses)
                .compactMap { $0.toNotificationItem() }
                .sorted {
                    if $0.createdAt == $1.createdAt {
                        return Int($0.id) ?? 0 > Int($1.id) ?? 0
                    }
                    return $0.createdAt > $1.createdAt
                }
            notifications = newItems.map { item in
                guard existingReadIds.contains(item.id) else { return item }
                var read = item
                read.isRead = true
                return read
            }
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

    // MARK: - Private Methods

    // 같은 albumId: 최신 항목 하나만 유지
    // CREATING -> COMPLETED or FAILED
    private func deduplicated(_ responses: [AlarmResponse]) -> [AlarmResponse] {
        // albumId 없는 항목은 그대로 유지
        let noAlbumIdItems = responses.filter { $0.albumId == nil }

        // albumId 있는 항목들을 그룹핑 후 각 그룹에서 하나만 선택
        let grouped = Dictionary(grouping: responses.filter { $0.albumId != nil }, by: { $0.albumId! })
        let deduped: [AlarmResponse] = grouped.values.compactMap { group in
            // COMPLETED or FAILED 중 가장 최신(alarmId 높은) 우선
            let resolved = group.filter { $0.alarmType == "COMPLETED" || $0.alarmType == "FAILED" }
            if let latest = resolved.max(by: { $0.alarmId < $1.alarmId }) { return latest }
            // CREATING만 있으면 그 중 최신
            return group.max(by: { $0.alarmId < $1.alarmId })
        }

        return noAlbumIdItems + deduped
    }

}
