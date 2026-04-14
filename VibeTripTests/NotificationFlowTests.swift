//
//  NotificationFlowTests.swift
//  VibeTripTests
//
//  Created by CHOI on 4/9/26.
//

import XCTest
@testable import VibeTrip

private final class StubAlarmServiceForNotificationFlow: AlarmServiceProtocol {
    var fetchResult: Result<[AlarmResponse], Error> = .success([])

    func fetchAlarms() async throws -> [AlarmResponse] {
        switch fetchResult {
        case .success(let responses): return responses
        case .failure(let error): throw error
        }
    }

    func deleteAlarm(alarmId: Int) async throws {}
}

@MainActor
final class NotificationFlowTests: XCTestCase {

    // MARK: - FCM -> Navigation

    // CREATING 푸시 payload는 생성 대기 화면 액션으로 매핑
    func test_fcmCreating_mapsToOpenAlbumCreationLoading() {
        let payload = FCMPayload(
            type: "CREATING",
            data: FCMPayloadData(albumId: 11, taskId: "task-1"),
            error: nil
        )

        XCTAssertEqual(payload.toNavigationAction(), .openAlbumCreationLoading)
    }

    // COMPLETED 푸시 payload는 해당 albumId 상세 화면 액션으로 매핑
    func test_fcmCompleted_mapsToOpenAlbumDetail() {
        let payload = FCMPayload(
            type: "COMPLETED",
            data: FCMPayloadData(albumId: 33, taskId: "task-2"),
            error: nil
        )

        XCTAssertEqual(payload.toNavigationAction(), .openAlbumDetail(albumId: "33"))
    }

    // FAILED 푸시 payload는 앨범 생성 화면 액션으로 매핑
    func test_fcmFailed_mapsToOpenMakeAlbum() {
        let payload = FCMPayload(
            type: "FAILED",
            data: nil,
            error: FCMPayloadError(
                errorCode: "ALBUM_CREATE_FAILED",
                message: "생성 실패",
                data: FCMPayloadErrorData(albumId: 44)
            )
        )

        XCTAssertEqual(payload.toNavigationAction(), .openMakeAlbum)
    }

    // MARK: - NotificationViewModel dedup scenario

    // 같은 albumId에 CREATING/COMPLETED가 섞여 오면 최종 상태(COMPLETED)만 표시
    func test_loadNotifications_sameAlbum_keepsLatestResolvedOne() async {
        let stub = StubAlarmServiceForNotificationFlow()
        stub.fetchResult = .success([
            AlarmResponse(
                alarmId: 1,
                title: "생성 중",
                description: "creating",
                alarmType: "CREATING",
                createdAt: "2026-04-09T10:00:00",
                albumId: 100
            ),
            AlarmResponse(
                alarmId: 2,
                title: "생성 완료",
                description: "completed-1",
                alarmType: "COMPLETED",
                createdAt: "2026-04-09T10:01:00",
                albumId: 100
            ),
            AlarmResponse(
                alarmId: 3,
                title: "생성 완료",
                description: "completed-2",
                alarmType: "COMPLETED",
                createdAt: "2026-04-09T10:02:00",
                albumId: 100
            )
        ])
        let sut = NotificationViewModel(alarmService: stub)

        await sut.loadNotifications()

        XCTAssertEqual(sut.notifications.count, 1)
        XCTAssertEqual(sut.notifications.first?.id, "3")
        if case .completed(let albumId) = sut.notifications.first?.type {
            XCTAssertEqual(albumId, "100")
        } else {
            XCTFail("기대 타입(.completed)과 다릅니다.")
        }
    }

    // 같은 albumId에 CREATING만 여러 건이면 최신 CREATING 표시
    func test_loadNotifications_sameAlbumCreatingOnly_keepsLatestCreatingOne() async {
        let stub = StubAlarmServiceForNotificationFlow()
        stub.fetchResult = .success([
            AlarmResponse(
                alarmId: 10,
                title: "생성 중",
                description: "creating-1",
                alarmType: "CREATING",
                createdAt: "2026-04-09T11:00:00",
                albumId: 200
            ),
            AlarmResponse(
                alarmId: 11,
                title: "생성 중",
                description: "creating-2",
                alarmType: "CREATING",
                createdAt: "2026-04-09T11:01:00",
                albumId: 200
            )
        ])
        let sut = NotificationViewModel(alarmService: stub)

        await sut.loadNotifications()

        XCTAssertEqual(sut.notifications.count, 1)
        XCTAssertEqual(sut.notifications.first?.id, "11")
        if case .generating = sut.notifications.first?.type {
            // expected
        } else {
            XCTFail("기대 타입(.generating)과 다릅니다.")
        }
    }

    // 같은 albumId에서 예전 COMPLETED 후 새 CREATING이 오면 최신 CREATING 표시
    func test_loadNotifications_sameAlbumOldCompletedAndNewCreating_keepsLatestCreatingOne() async {
        let stub = StubAlarmServiceForNotificationFlow()
        stub.fetchResult = .success([
            AlarmResponse(
                alarmId: 30,
                title: "생성 완료",
                description: "completed",
                alarmType: "COMPLETED",
                createdAt: "2026-04-09T12:00:00",
                albumId: 400
            ),
            AlarmResponse(
                alarmId: 31,
                title: "생성 중",
                description: "creating",
                alarmType: "CREATING",
                createdAt: "2026-04-09T12:05:00",
                albumId: 400
            )
        ])
        let sut = NotificationViewModel(alarmService: stub)

        await sut.loadNotifications()

        XCTAssertEqual(sut.notifications.count, 1)
        XCTAssertEqual(sut.notifications.first?.id, "31")
        if case .generating(let albumId) = sut.notifications.first?.type {
            XCTAssertEqual(albumId, "400")
        } else {
            XCTFail("기대 타입(.generating)과 다릅니다.")
        }
    }

    // 같은 albumId에서 CREATING 후 FAILED가 오면 최신 FAILED 표시
    func test_loadNotifications_sameAlbumCreatingAndFailed_keepsLatestFailedOne() async {
        let stub = StubAlarmServiceForNotificationFlow()
        stub.fetchResult = .success([
            AlarmResponse(
                alarmId: 40,
                title: "생성 중",
                description: "creating",
                alarmType: "CREATING",
                createdAt: "2026-04-09T13:00:00",
                albumId: 500
            ),
            AlarmResponse(
                alarmId: 41,
                title: "생성 실패",
                description: "failed",
                alarmType: "FAILED",
                createdAt: "2026-04-09T13:02:00",
                albumId: 500
            )
        ])
        let sut = NotificationViewModel(alarmService: stub)

        await sut.loadNotifications()

        XCTAssertEqual(sut.notifications.count, 1)
        XCTAssertEqual(sut.notifications.first?.id, "41")
        if case .failed = sut.notifications.first?.type {
            // expected
        } else {
            XCTFail("기대 타입(.failed)과 다릅니다.")
        }
    }

    // 알림 목록은 createdAt 기준 최신순(내림차순)으로 정렬되
    func test_loadNotifications_sortsByLatestCreatedAtFirst() async {
        let stub = StubAlarmServiceForNotificationFlow()
        stub.fetchResult = .success([
            AlarmResponse(
                alarmId: 21,
                title: "오래된 알림",
                description: "old",
                alarmType: "FAILED",
                createdAt: "2026-04-09T10:00:00",
                albumId: nil
            ),
            AlarmResponse(
                alarmId: 22,
                title: "가장 최신 알림",
                description: "latest",
                alarmType: "COMPLETED",
                createdAt: "2026-04-09T10:03:00",
                albumId: 301
            ),
            AlarmResponse(
                alarmId: 23,
                title: "중간 알림",
                description: "middle",
                alarmType: "CREATING",
                createdAt: "2026-04-09T10:02:00",
                albumId: 302
            )
        ])
        let sut = NotificationViewModel(alarmService: stub)

        await sut.loadNotifications()

        XCTAssertEqual(sut.notifications.map(\.id), ["22", "23", "21"])
    }
}
