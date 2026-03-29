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

    // 화면에 표시할 알림 목록 (외부에서 직접 변경 불가)
    @Published private(set) var notifications: [NotificationItem] = []

    // 하단에 잠깐 보여줄 토스트 메시지 (nil이면 비표시)
    @Published private(set) var toastMessage: String?

    // MARK: - Constants

    private enum ToastMessage {
        static let deleted = "알림이 삭제 되었어요"
    }

    private enum ToastDuration: Double {
        case standard = 2.5
    }

    // MARK: - Computed

    // 빈 상태 UI 표시 플래그
    var isEmpty: Bool { notifications.isEmpty }

    // MARK: - Init

    nonisolated init() {}

    #if DEBUG
    // Preview 전용 초기화: 더미 데이터
    init(previewNotifications: [NotificationItem]) {
        self.notifications = previewNotifications
    }
    #endif

    // MARK: - Public Methods

    func loadNotifications() async {
        // TODO: 서버 API 연결
        // TODO: AppState.hasUnreadNotifications = true 세팅

        // 더미 데이터
        notifications = [
            // 생성 중: 미읽음 상태
            NotificationItem(
                id: "mock-1",
                type: .generating,
                title: "앨범을 생성하는 중입니다.",
                body: "나만의 음악이 곧 탄생합니다. 완료되면 바로 알려드릴게요.",
                createdAt: Date(timeIntervalSinceNow: -60 * 2),   // 2분 전
                isRead: false
            ),
            // 생성 완료: 읽음 상태
            NotificationItem(
                id: "mock-2",
                type: .completed(albumId: "album-mock-123"),
                title: "앨범 생성 완료!",
                body: "세상에 하나뿐인 '제주 여름 여행'이 완성되었습니다. 지금 바로 완성된 음악을 감상해 보세요.",
                createdAt: Date(timeIntervalSinceNow: -60 * 60),  // 1시간 전
                isRead: true
            ),
            // 생성 실패: 읽음 상태
            NotificationItem(
                id: "mock-3",
                type: .failed,
                title: "앨범 생성에 실패했습니다.",
                body: "서버 오류로 생성에 실패했습니다. 앨범 만들기를 다시 시도해 볼까요?",
                createdAt: Date(timeIntervalSinceNow: -60 * 60 * 2), // 2시간 전
                isRead: true
            )
        ]
    }

    // 탭 시 배경색 제거
    func markAsRead(id: String) {
        // TODO: [서버 연동] PATCH /api/notifications/{id}/read 호출
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[index].isRead = true
    }

    // 알림 삭제 시, 토스트 표시
    func deleteNotification(id: String) async {
        // TODO: 서버 연동 시, DELETE 호출 후 로컬 제거
        notifications.removeAll { $0.id == id }
        showToast(ToastMessage.deleted)
    }

    // 알림 뷰 탈출 시 전체 읽음 처리
    func markAllAsRead() {
        // TODO: 서버 연동 시, PATCH 호출
        notifications = notifications.map {
            var item = $0
            item.isRead = true
            return item
        }
    }

    // MARK: - Private Methods

    // 토스트 자동 숨김
    func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: UInt64(ToastDuration.standard.rawValue * 1_000_000_000))
            toastMessage = nil
        }
    }
}
