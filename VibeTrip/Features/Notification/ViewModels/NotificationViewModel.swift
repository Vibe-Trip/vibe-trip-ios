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
    @Published private(set) var showsUnreadBadge = false

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
            // 인메모리 읽음 ID와 UserDefaults 저장값의 합집합으로 읽음 상태 보존
            let memoryReadIds = Set(notifications.filter { $0.isRead }.map { $0.id })
            let existingReadIds = memoryReadIds.union(loadReadIds())
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

    // 앱 내부에서 새 알림 이벤트를 받았을 때 레드닷/목록 상태를 함께 갱신
    // 알림탭 밖: 최신 목록을 로드해 실제 미읽음 항목이 있을 때만 배지 ON -> 이미 읽은 알림을 시스템 알림센터에서 탭한 경우 배지가 잘못 켜지는 문제 방지
    func handleIncomingNotification(isViewingNotificationTab: Bool) async {
        if isViewingNotificationTab {
            showsUnreadBadge = false
            await loadNotifications()
        } else {
            await loadNotifications()
            showsUnreadBadge = notifications.contains { !$0.isRead }
        }
    }

    // 앱 복귀 시 현재 위치에 맞춰 레드닷/목록 상태를 한 곳에서 처리
    func handleAppBecameActive(
        isViewingNotificationTab: Bool,
        hasDeliveredNotifications: Bool
    ) async {
        if isViewingNotificationTab {
            showsUnreadBadge = false
            await loadNotifications()
            if hasDeliveredNotifications {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await loadNotifications()
            }
            return
        }

        // API 응답 지연 대비 표시 -> API 결과로 최종 덮어씀
        if hasDeliveredNotifications {
            showsUnreadBadge = true
        }

        // readAlarmIds 기반 실제 미읽음 여부만 최종 반영 -> 알림센터에 남은 이미 읽은 알림 때문에 배지가 고착되는 문제 방지
        let result = await checkUnread()
        showsUnreadBadge = result.hasUnread
    }

    func clearUnreadBadge() {
        showsUnreadBadge = false
    }

    // 앱 포그라운드 진입 시 미읽음/FAILED 알림 여부만 확인 (notifications 배열 미변경)
    func checkUnread() async -> (hasUnread: Bool, hasFailed: Bool) {
        guard let responses = try? await alarmService.fetchAlarms() else { return (false, false) }
        let deduped = deduplicated(responses)
        let storedReadIds = loadReadIds()
        return (
            deduped.contains { !storedReadIds.contains(String($0.alarmId)) },
            deduped.contains { $0.alarmType == "FAILED" }
        )
    }

    // 탭 시 배경색 제거 + UserDefaults에 읽음 상태 저장
    func markAsRead(id: String) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[index].isRead = true
        var stored = loadReadIds()
        stored.insert(id)
        saveReadIds(stored)
        if notifications.allSatisfy({ $0.isRead }) {
            showsUnreadBadge = false
        }
    }

    // 알림 삭제 + UserDefaults에서 읽음 ID 제거
    func deleteNotification(id: String) async {
        guard let alarmId = Int(id) else { return }
        do {
            try await alarmService.deleteAlarm(alarmId: alarmId)
            notifications.removeAll { $0.id == id }
            var stored = loadReadIds()
            stored.remove(id)
            saveReadIds(stored)
        } catch {
            // 삭제 실패 시 목록 유지 (조용히 처리)
        }
    }

    // 알림 뷰 탈출 시 전체 읽음 처리 + UserDefaults에 저장
    func markAllAsRead() {
        notifications = notifications.map {
            var item = $0
            item.isRead = true
            return item
        }
        var stored = loadReadIds()
        stored.formUnion(notifications.map { $0.id })
        saveReadIds(stored)
        showsUnreadBadge = false
    }

    // MARK: - Private Methods

    // MARK: UserDefaults 읽음 상태 영구 저장

    private enum UserDefaultsKeys {
        static let readAlarmIds = "readAlarmIds"
    }

    // 읽음 처리된 alarmId 목록을 UserDefaults에 저장
    private func saveReadIds(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: UserDefaultsKeys.readAlarmIds)
    }

    // UserDefaults에서 읽음 처리된 alarmId 목록 로드
    private func loadReadIds() -> Set<String> {
        let stored = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.readAlarmIds) ?? []
        return Set(stored)
    }

    // 같은 albumId: 가장 최신 항목 하나만 유지
    private func deduplicated(_ responses: [AlarmResponse]) -> [AlarmResponse] {
        // albumId 없는 항목은 그대로 유지
        let noAlbumIdItems = responses.filter { $0.albumId == nil }

        // albumId 있는 항목들을 그룹핑 후 각 그룹에서 하나만 선택
        let grouped = Dictionary(grouping: responses.filter { $0.albumId != nil }, by: { $0.albumId! })
        let deduped: [AlarmResponse] = grouped.values.compactMap { group in
            group.max { lhs, rhs in
                let lhsDate = parseAlarmDate(lhs.createdAt)
                let rhsDate = parseAlarmDate(rhs.createdAt)
                if lhsDate == rhsDate {
                    return lhs.alarmId < rhs.alarmId
                }
                return lhsDate < rhsDate
            }
        }

        return noAlbumIdItems + deduped
    }

    private func parseAlarmDate(_ string: String) -> Date {
        if let date = Self.isoFormatterWithFraction.date(from: string) { return date }
        if let date = Self.isoFormatterWithoutFraction.date(from: string) { return date }
        if let date = Self.plainDateTimeFormatter.date(from: string) { return date }
        return Date.distantPast
    }

    private static let isoFormatterWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterWithoutFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let plainDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

}
