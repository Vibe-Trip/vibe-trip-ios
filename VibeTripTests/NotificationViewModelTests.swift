//
//  NotificationViewModelTests.swift
//  VibeTripTests
//
//  Created by CHOI on 4/10/26.
//

import XCTest
@testable import VibeTrip

// MARK: - Stub

private final class StubAlarmServiceForViewModel: AlarmServiceProtocol {

    var fetchResult: Result<[AlarmResponse], Error> = .success([])
    var deleteResult: Result<Void, Error> = .success(())
    private(set) var deletedAlarmId: Int? = nil

    func fetchAlarms() async throws -> [AlarmResponse] {
        try fetchResult.get()
    }

    func deleteAlarm(alarmId: Int) async throws {
        deletedAlarmId = alarmId
        try deleteResult.get()
    }
}

// MARK: - NotificationViewModelTests

@MainActor
final class NotificationViewModelTests: XCTestCase {

    private var sut: NotificationViewModel!
    private var stub: StubAlarmServiceForViewModel!

    override func setUp() {
        super.setUp()
        // 테스트 간 UserDefaults 격리
        UserDefaults.standard.removeObject(forKey: "readAlarmIds")
        stub = StubAlarmServiceForViewModel()
        sut = NotificationViewModel(alarmService: stub)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "readAlarmIds")
        sut = nil
        stub = nil
        super.tearDown()
    }

    // MARK: - checkUnread()

    // FAILED 알림 존재 시 hasUnread, hasFailed 모두 true
    func test_checkUnread_withFailedAlarm_returnsTrueForBoth() async {
        stub.fetchResult = .success([
            makeAlarmResponse(alarmId: 1, alarmType: "FAILED", albumId: nil)
        ])

        let result = await sut.checkUnread()

        XCTAssertTrue(result.hasUnread)
        XCTAssertTrue(result.hasFailed)
    }

    // COMPLETED 알림만 존재 시 hasUnread: true, hasFailed: false
    func test_checkUnread_withCompletedAlarmOnly_returnsFalseForFailed() async {
        stub.fetchResult = .success([
            makeAlarmResponse(alarmId: 1, alarmType: "COMPLETED", albumId: 100)
        ])

        let result = await sut.checkUnread()

        XCTAssertTrue(result.hasUnread)
        XCTAssertFalse(result.hasFailed)
    }

    // 알림 없음 시 hasUnread, hasFailed 모두 false
    func test_checkUnread_withNoAlarms_returnsFalseForBoth() async {
        stub.fetchResult = .success([])

        let result = await sut.checkUnread()

        XCTAssertFalse(result.hasUnread)
        XCTAssertFalse(result.hasFailed)
    }

    // API 실패 시 (false, false) 반환
    func test_checkUnread_onAPIFailure_returnsFalseForBoth() async {
        stub.fetchResult = .failure(URLError(.notConnectedToInternet))

        let result = await sut.checkUnread()

        XCTAssertFalse(result.hasUnread)
        XCTAssertFalse(result.hasFailed)
    }

    // 같은 albumId에 CREATING + FAILED 공존 시 deduplicated 후 FAILED만 남아 hasFailed: true
    func test_checkUnread_deduplicatesBeforeCheck() async {
        stub.fetchResult = .success([
            makeAlarmResponse(alarmId: 1, alarmType: "CREATING", albumId: 100),
            makeAlarmResponse(alarmId: 2, alarmType: "FAILED", albumId: 100)
        ])

        let result = await sut.checkUnread()

        XCTAssertTrue(result.hasUnread)
        XCTAssertTrue(result.hasFailed)
    }

    // checkUnread 호출 후 notifications 배열이 변경되지 않아야 함
    func test_checkUnread_doesNotMutateNotifications() async {
        stub.fetchResult = .success([
            makeAlarmResponse(alarmId: 1, alarmType: "COMPLETED", albumId: 100)
        ])
        await sut.loadNotifications()
        let beforeIds = sut.notifications.map(\.id)

        stub.fetchResult = .success([
            makeAlarmResponse(alarmId: 2, alarmType: "FAILED", albumId: nil)
        ])
        _ = await sut.checkUnread()

        XCTAssertEqual(sut.notifications.map(\.id), beforeIds)
    }

    func test_handleIncomingNotification_outsideNotificationTab_turnsBadgeOnWhenUnreadExists() async {
        stub.fetchResult = .success([
            makeAlarmResponse(alarmId: 7, alarmType: "FAILED", albumId: nil)
        ])

        await sut.handleIncomingNotification(isViewingNotificationTab: false)

        XCTAssertTrue(sut.showsUnreadBadge)
        XCTAssertEqual(sut.notifications.map(\.id), ["7"])
    }

    // 알림탭 밖에서 이미 읽은 알림만 있는 경우(시스템 알림센터 잔존 후 재탭 등) 배지 OFF 유지
    func test_handleIncomingNotification_outsideNotificationTab_keepsBadgeOffWhenAllRead() async {
        stub.fetchResult = .success([
            makeAlarmResponse(alarmId: 7, alarmType: "FAILED", albumId: nil)
        ])
        await sut.loadNotifications()
        sut.markAllAsRead()

        await sut.handleIncomingNotification(isViewingNotificationTab: false)

        XCTAssertFalse(sut.showsUnreadBadge)
    }

    func test_handleIncomingNotification_insideNotificationTab_reloadsListAndKeepsBadgeOff() async {
        stub.fetchResult = .success([
            makeAlarmResponse(alarmId: 7, alarmType: "FAILED", albumId: nil)
        ])

        await sut.handleIncomingNotification(isViewingNotificationTab: true)

        XCTAssertFalse(sut.showsUnreadBadge)
        XCTAssertEqual(sut.notifications.map(\.id), ["7"])
        XCTAssertFalse(sut.notifications.first?.isRead ?? true)
    }

    func test_handleAppBecameActive_withDeliveredNotification_keepsBadgeOnEvenBeforeAPISync() async {
        stub.fetchResult = .success([])

        await sut.handleAppBecameActive(
            isViewingNotificationTab: false,
            hasDeliveredNotifications: true
        )

        XCTAssertTrue(sut.showsUnreadBadge)
    }

    func test_handleAppBecameActive_withoutDeliveredOrUnread_clearsBadge() async {
        stub.fetchResult = .success([
            makeAlarmResponse(alarmId: 7, alarmType: "FAILED", albumId: nil)
        ])
        await sut.handleIncomingNotification(isViewingNotificationTab: false)
        XCTAssertTrue(sut.showsUnreadBadge)

        stub.fetchResult = .success([])
        await sut.handleAppBecameActive(
            isViewingNotificationTab: false,
            hasDeliveredNotifications: false
        )

        XCTAssertFalse(sut.showsUnreadBadge)
    }

    // 알림센터에 푸시가 남아있어도 서버 기준 모두 읽음이면 최종 배지 OFF
    // -> 알림센터 잔존 알림으로 배지 고착되는 문제 방지
    func test_handleAppBecameActive_withDeliveredButAllRead_clearsBadge() async {
        stub.fetchResult = .success([
            makeAlarmResponse(alarmId: 7, alarmType: "FAILED", albumId: nil)
        ])
        await sut.loadNotifications()
        sut.markAllAsRead()

        await sut.handleAppBecameActive(
            isViewingNotificationTab: false,
            hasDeliveredNotifications: true
        )

        XCTAssertFalse(sut.showsUnreadBadge)
    }

    // MARK: - UserDefaults 읽음 상태 영구 저장

    // markAsRead 후 앱 재시작(새 ViewModel) 시 해당 알림 읽음 상태 복원
    func test_markAsRead_persistsToUserDefaults() async {
        stub.fetchResult = .success([
            makeAlarmResponse(alarmId: 1, alarmType: "FAILED", albumId: nil),
            makeAlarmResponse(alarmId: 2, alarmType: "COMPLETED", albumId: 100)
        ])
        await sut.loadNotifications()

        sut.markAsRead(id: "1")

        // 새 ViewModel = 인메모리 초기화 (앱 재시작 시뮬레이션)
        let newSut = NotificationViewModel(alarmService: stub)
        await newSut.loadNotifications()

        XCTAssertTrue(newSut.notifications.first(where: { $0.id == "1" })?.isRead == true)
        XCTAssertFalse(newSut.notifications.first(where: { $0.id == "2" })?.isRead == true)
    }

    // markAllAsRead 후 앱 재시작 시 전체 알림 읽음 상태 복원
    func test_markAllAsRead_persistsToUserDefaults() async {
        stub.fetchResult = .success([
            makeAlarmResponse(alarmId: 1, alarmType: "FAILED", albumId: nil),
            makeAlarmResponse(alarmId: 2, alarmType: "COMPLETED", albumId: 100)
        ])
        await sut.loadNotifications()

        sut.markAllAsRead()

        let newSut = NotificationViewModel(alarmService: stub)
        await newSut.loadNotifications()

        XCTAssertTrue(newSut.notifications.allSatisfy { $0.isRead })
    }

    // markAsRead 후 deleteNotification 성공 시 UserDefaults에서 해당 ID 제거
    func test_deleteNotification_removesIdFromUserDefaults() async {
        stub.fetchResult = .success([
            makeAlarmResponse(alarmId: 1, alarmType: "FAILED", albumId: nil),
            makeAlarmResponse(alarmId: 2, alarmType: "COMPLETED", albumId: 100)
        ])
        await sut.loadNotifications()
        sut.markAsRead(id: "1")

        await sut.deleteNotification(id: "1")

        // 새 ViewModel에서 재조회: 삭제된 ID가 읽음 목록에서 제거되어 isRead: false로 복원됨
        let newSut = NotificationViewModel(alarmService: stub)
        await newSut.loadNotifications()

        XCTAssertFalse(newSut.notifications.first(where: { $0.id == "1" })?.isRead == true)
    }

    // 앱 재시작 후 loadNotifications 시 UserDefaults와 인메모리 합집합으로 읽음 상태 복원
    func test_loadNotifications_mergesUserDefaultsReadIds() async {
        stub.fetchResult = .success([
            makeAlarmResponse(alarmId: 1, alarmType: "FAILED", albumId: nil),
            makeAlarmResponse(alarmId: 2, alarmType: "FAILED", albumId: nil),
            makeAlarmResponse(alarmId: 3, alarmType: "COMPLETED", albumId: 100)
        ])
        await sut.loadNotifications()
        sut.markAsRead(id: "1")
        sut.markAsRead(id: "2")

        let newSut = NotificationViewModel(alarmService: stub)
        await newSut.loadNotifications()

        XCTAssertTrue(newSut.notifications.first(where: { $0.id == "1" })?.isRead == true)
        XCTAssertTrue(newSut.notifications.first(where: { $0.id == "2" })?.isRead == true)
        XCTAssertFalse(newSut.notifications.first(where: { $0.id == "3" })?.isRead == true)
    }

    // MARK: - Helpers

    private func makeAlarmResponse(
        alarmId: Int,
        alarmType: String,
        albumId: Int?
    ) -> AlarmResponse {
        AlarmResponse(
            alarmId: alarmId,
            title: "테스트 알림",
            description: "테스트 본문",
            alarmType: alarmType,
            createdAt: "2026-04-10T10:00:00",
            albumId: albumId
        )
    }
}
