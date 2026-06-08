//
//  AlarmServiceProtocol.swift
//  VibeTrip
//
//  Created by CHOI on 4/7/26.
//

import Foundation

// MARK: - AlarmResponse

/// 서버 알림 응답 DTO
struct AlarmResponse: Decodable {
    let alarmId: Int
    let title: String
    let description: String         // 알림 본문
    let alarmType: String           // CREATING | COMPLETED | FAILED
    let createdAt: String           // ISO8601 형식
    let albumId: Int?               // 앨범 식별자
}

// MARK: - AlarmResponse -> NotificationItem 변환

extension AlarmResponse {

    // 서버 DTO  -> 앱 도메인 모델 변환
    func toNotificationItem() -> NotificationItem? {
        guard let type = toNotificationType() else {
            return nil
        }
        return NotificationItem(
            id: String(alarmId),
            type: type,
            title: title,
            body: formattedDescription(for: type),
            createdAt: Self.parseDate(from: createdAt),
            isRead: false
        )
    }

    // alarmType 문자열 -> NotificationType 매핑
    private func toNotificationType() -> NotificationType? {
        switch alarmType {
        case "CREATING":
            return .generating(albumId: albumId.map { String($0) })
        case "COMPLETED":
            // COMPLETED는 반드시 albumId가 필요
            guard let albumId else { return nil }
            return .completed(albumId: String(albumId))
        case "FAILED":
            return .failed
        default:
            return nil
        }
    }

    // 서버 본문 문구를 타입별로 줄바꿈 적용
    private func formattedDescription(for type: NotificationType) -> String {
        let normalized = normalizeLineSeparators(in: description)
        switch type {
        case .completed:
            return forceLineBreak(in: normalized, after: "완성되었습니다.")
        case .failed:
            return "앨범 만들기를 다시 시도해 주세요."
        case .generating:
            return normalized
        }
    }

    private func normalizeLineSeparators(in text: String) -> String {
        text
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private func forceLineBreak(in text: String, after marker: String) -> String {
        guard let markerRange = text.range(of: marker) else { return text }
        let splitIndex = markerRange.upperBound
        guard splitIndex < text.endIndex else { return text }

        let next = text[splitIndex]
        if next == "\n" { return text }

        var result = text
        if next == " " {
            result.replaceSubrange(splitIndex...splitIndex, with: "\n")
        } else {
            result.insert("\n", at: splitIndex)
        }
        return result
    }

    // ISO8601 날짜 파싱
    private static func parseDate(from string: String) -> Date {
        if let date = isoFormatterWithFraction.date(from: string) { return date }
        if let date = isoFormatterWithoutFraction.date(from: string) { return date }
        if let date = plainDateTimeFormatter.date(from: string) { return date }
        return Date()
    }

    // "2026-04-07T10:00:00.000Z"
    private static let isoFormatterWithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // "2026-04-07T10:00:00Z"
    private static let isoFormatterWithoutFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // "2026-04-08T00:04:20" (timezone 없는 서버 응답 포맷)
    private static let plainDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

// MARK: - AlarmServiceProtocol

// 알림 관련 네트워크 서비스 인터페이스
protocol AlarmServiceProtocol {
    // 알림 목록 조회
    func fetchAlarms() async throws -> [AlarmResponse]
    // 알림 삭제
    func deleteAlarm(alarmId: Int) async throws
}

// MARK: - AlarmService

final class AlarmService: AlarmServiceProtocol {

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    func fetchAlarms() async throws -> [AlarmResponse] {
        let endpoint = APIEndpoint(path: "/api/v1/alarms", method: .get)
        return try await apiClient.request(endpoint)
    }

    func deleteAlarm(alarmId: Int) async throws {
        let endpoint = APIEndpoint(path: "/api/v1/alarms/\(alarmId)", method: .delete)
        try await apiClient.perform(endpoint)
    }
}

// MARK: - MockAlarmService

#if DEBUG
final class MockAlarmService: AlarmServiceProtocol {

    var simulatedError: Error? = nil    // 에러 시나리오 테스트
    var isEmpty: Bool = false           // 빈 목록 테스트
    var delay: UInt64 = 500_000_000     // 응답 지연 시뮬레이션 (0.5초)

    func fetchAlarms() async throws -> [AlarmResponse] {
        try await Task.sleep(nanoseconds: delay)
        if let error = simulatedError { throw error }
        if isEmpty { return [] }
        return AlarmResponse.mockItems
    }

    func deleteAlarm(alarmId: Int) async throws {
        try await Task.sleep(nanoseconds: delay)
        if let error = simulatedError { throw error }
    }
}

extension AlarmResponse {
    static let mockItems: [AlarmResponse] = [
        AlarmResponse(
            alarmId: 1,
            title: "앨범을 생성하는 중입니다.",
            description: "나만의 음악이 곧 탄생합니다. 완료되면 바로 알려드릴게요.",
            alarmType: "CREATING",
            createdAt: "2026-04-07T10:00:00.000Z",
            albumId: 101
        ),
        AlarmResponse(
            alarmId: 2,
            title: "앨범 생성 완료!",
            description: "세상에 하나뿐인 '리트립 테스트'가 완성되었습니다. 지금 바로 완성된 음악을 감상해 보세요.",
            alarmType: "COMPLETED",
            createdAt: "2026-04-07T09:00:00.000Z",
            albumId: 102
        ),
        AlarmResponse(
            alarmId: 3,
            title: "앨범 생성에 실패했습니다",
            description: "앨범 만들기를 다시 시도해 주세요.",
            alarmType: "FAILED",
            createdAt: "2026-04-07T08:00:00.000Z",
            albumId: nil
        )
    ]
}
#endif
