//
//  AlbumDetailViewModel.swift
//  VibeTrip
//
//  Created by CHOI on 6/23/26.
//

import Foundation
import Combine

// MARK: - AlbumDetailViewModel

@MainActor final class AlbumDetailViewModel: ObservableObject {
    
    @Published private(set) var logs: [AlbumLogEntry] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var hasNext: Bool = false
    @Published private(set) var showDeleteConfirm: Bool = false
    @Published private(set) var isDeleting: Bool = false
    @Published private(set) var deleteAlbumToastMessage: String? = nil
    @Published private(set) var didDeleteAlbum: Bool = false
    @Published private(set) var pendingDeleteLogId: Int? = nil
    @Published private(set) var showDeleteLogConfirm: Bool = false
    @Published private(set) var isDeletingLog: Bool = false
    @Published private(set) var deleteLogToastMessage: String? = nil
    @Published private(set) var musicUrl: URL? = nil
    @Published private(set) var isMusicUrlReady: Bool = false
    @Published private(set) var isDownloadingMusic: Bool = false
    @Published private(set) var downloadedMusicFileURL: URL? = nil  // 공유 시트 트리거
    @Published private(set) var isStorageFull: Bool = false
    @Published private(set) var awaitingImageLogIds: Set<Int> = []  // 방금 저장한 로그 중 이미지 응답이 아직 비어 있는 id 모음 -> 카드 이미지 영역을 스켈레톤으로 표시

    private let albumId: String
    private let albumIdInt: Int    // Int 변환값, init에서 1회만 처리
    private var cursor: Int? = nil
    private let limit = 20
    private let service: AlbumServiceProtocol
    // 초기 로드 Task: 새 호출 시 이전 진행 중 fetch 를 cancel 해 race 로 인한 조용한 스킵 방지
    private var loadTask: Task<Void, Never>? = nil
    // 밀리초 포함 ISO8601 파싱
    private static let isoFormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    // 일반 ISO8601 파싱
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    // 지정 init: albumId 저장 + Int 변환
    @MainActor init(albumId: String, service: AlbumServiceProtocol) {
        self.albumId = albumId
        self.albumIdInt = Int(albumId) ?? 0
        self.service = service
    }
    
    // 운영용 init: 실제 AlbumService 를 주입해 지정 init 으로 위임
    @MainActor convenience init(albumId: String) {
        self.init(albumId: albumId, service: AlbumService())
    }
    
    // 초기 페이지 로드: 진행 중 fetch 를 cancel 한 뒤 새 fetch 시작 -> race 로 인한 스킵 방지
    // 실패 시 기존 logs 유지 -> 로그 목록 화면 깜빡임 방지
    func loadInitialLogs() async {
        loadTask?.cancel()
        let task = Task { await performInitialLoad() }
        loadTask = task
        await task.value
    }

    // 첫 페이지 실제 fetch: 로딩 플래그 관리, 취소/실패 시 기존 목록 보존
    private func performInitialLoad() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let payload = try await service.fetchAlbumLogs(albumId: albumId, cursor: nil, limit: limit)
            try Task.checkCancellation()
            for log in payload.content {
                print("[AlbumLog] id:\(log.id) postedAt:\(log.postedAt) parsedDate:\(String(describing: Self.parseISO8601Date(log.postedAt)))")
                // 저장 직후 사진 미표시 원인 진단용: 응답에 images 가 비어 오는지(케이스 ①) 확인
                print("[AlbumLog] id:\(log.id) images.count:\(log.images.count) urls:\(log.images.map(\.imageUrl.absoluteString))")
            }
            // 성공 시점에만 교체: 사전 클리어 X -> 실패 시 기존 목록 유지
            cursor = payload.content.last?.id
            hasNext = payload.hasNext
            logs = payload.content
        } catch is CancellationError {
            return
        } catch {
            // 실패 시 기존 logs 유지. 사용자 알림은 별도 작업으로 분리됨
        }
    }

    // 저장 직후 호출: 목록을 재조회하고 이미지가 곧장 안 채워진 경우 짧은 backoff 로 폴링
    // 대상 로그 카드의 이미지 영역만 스켈레톤으로 표시하고 나머지 영역/카드는 그대로 유지
    func refreshAfterSave(info: SavedLogInfo) async {
        await loadInitialLogs()
        guard info.hasImages else { return }

        // 어떤 id 를 기다릴 것인지 확정
        let targetId: Int?
        switch info.mode {
        case .edit(let id):
            targetId = id
        case .create:
            targetId = logs.first?.id
        }
        guard let id = targetId else { return }

        // 이미 이미지가 채워졌으면 폴링 불필요
        if let entry = logs.first(where: { $0.id == id }), !entry.images.isEmpty { return }

        awaitingImageLogIds.insert(id)
        defer { awaitingImageLogIds.remove(id) }

        // backoff 폴링: 매 시도마다 첫 페이지 재조회 후 대상 id 의 images 채워졌는지 확인
        for delay in [0.3, 0.8, 1.5] as [TimeInterval] {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await loadInitialLogs()
            if let entry = logs.first(where: { $0.id == id }), !entry.images.isEmpty { return }
        }
        // 최대 시도 후에도 비어 있으면 스켈레톤만 사라짐
    }
    
    // 음악 파일을 임시 폴더에 다운로드 후 공유 시트 트리거
    func downloadMusic(albumTitle: String?) async {
        guard let url = musicUrl else { return }
        isDownloadingMusic = true
        defer { isDownloadingMusic = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
            let baseName = albumTitle.flatMap { $0.isEmpty ? nil : $0 } ?? "vibe_trip_\(albumId)"
            let sanitized = baseName.replacingOccurrences(of: "[/:\\\\*?\"<>|]", with: "_", options: .regularExpression)
            let filename = "\(sanitized).\(ext)"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: tempURL)
            downloadedMusicFileURL = tempURL
        } catch CocoaError.fileWriteOutOfSpace {
            isStorageFull = true
        } catch {
            // 기타 에러 무시
        }
    }
    
    // 공유 시트 닫힌 후 임시 파일 정리
    func clearDownloadedMusicFile() {
        if let url = downloadedMusicFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        downloadedMusicFileURL = nil
    }
    
    // 저장공간 부족 토스트 표시 후 플래그 초기화
    func consumeStorageFullFlag() {
        isStorageFull = false
    }
    
    // 상세 진입 시 1회 호출: null -> 버튼 비활성, null X -> isMusicUrlReady = true
    func loadMusicUrl() async {
        guard let detail = await fetchAlbumDetail() else { return }
        musicUrl = detail.musicUrl
        isMusicUrlReady = detail.musicUrl != nil
    }
    
    // 앨범 상세 단건 조회 -> 잘못된 id 면 nil
    func fetchAlbumDetail() async -> AlbumDetail? {
        guard albumIdInt > 0 else { return nil }
        return try? await service.fetchAlbum(albumId: albumIdInt)
    }
    
    // 앨범 삭제 확인 팝업 표시 요청
    func requestDeleteAlbum() {
        showDeleteConfirm = true
    }
    
    // ExitPopupView 취소 탭 시 팝업 비활성화
    func dismissDeleteConfirm() {
        showDeleteConfirm = false
    }
    
    // 앨범 삭제 실패 토스트 표시 후 메시지 초기화
    func consumeDeleteAlbumToast() {
        deleteAlbumToastMessage = nil
    }
    
    // 앨범 삭제 실행: 성공 시 닫기 신호, 실패 시 토스트 메시지 설정
    func confirmDeleteAlbum() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await service.deleteAlbum(albumId: albumId)
            didDeleteAlbum = true
        } catch {
            deleteAlbumToastMessage = "앨범 삭제에 실패했습니다."
        }
    }
    
    // 로그 삭제 확인 팝업 표시 요청 (대상 id 보관)
    func requestDeleteLog(id: Int) {
        pendingDeleteLogId = id
        showDeleteLogConfirm = true
    }
    
    // 팝업 취소 탭: 팝업 비활성화
    func dismissDeleteLogConfirm() {
        showDeleteLogConfirm = false
        pendingDeleteLogId = nil
    }
    
    // 로그 삭제 실패 토스트 표시 후 메시지 초기화
    func consumeDeleteLogToast() {
        deleteLogToastMessage = nil
    }
    
    // 로그 삭제 실행: 성공 시 목록에서 제거, 실패 시 토스트 메시지 설정
    func confirmDeleteLog() async {
        guard let logId = pendingDeleteLogId else { return }
        isDeletingLog = true
        showDeleteLogConfirm = false
        defer { isDeletingLog = false }
        do {
            try await service.deleteAlbumLog(albumId: albumId, albumLogId: logId)
            pendingDeleteLogId = nil
            logs.removeAll { $0.id == logId }
        } catch {
            deleteLogToastMessage = "로그 삭제에 실패했습니다."
        }
    }
    
    // 무한 스크롤: 마지막 카드 도달 시 다음 페이지 fetch
    func loadMoreIfNeeded(lastId: Int) async {
        guard hasNext, !isLoading, logs.last?.id == lastId else { return }
        await fetchLogs()
    }
    
    // 다음 페이지 fetch: 기존 목록에 이어붙이고 커서, hasNext 갱신
    private func fetchLogs() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let payload = try await service.fetchAlbumLogs(
                albumId: albumId, cursor: cursor, limit: limit
            )
            for log in payload.content {
                print("[AlbumLog] id:\(log.id) postedAt:\(log.postedAt) parsedDate:\(String(describing: Self.parseISO8601Date(log.postedAt)))")
            }
            logs.append(contentsOf: payload.content)
            hasNext = payload.hasNext
            cursor = payload.content.last?.id
        } catch {
            // TODO: 에러 토스트 처리 (로그 수정/삭제 작업 시 함께 정리)
        }
    }
    
    // postedAt(ISO8601) 기준 날짜별 그룹핑
    var groupedLogs: [(dateLabel: String, logs: [AlbumLogEntry])] {
        let labelFormatter = DateFormatter()
        labelFormatter.locale = Locale(identifier: "ko_KR")
        labelFormatter.dateFormat = "M월 d일 EEEE"
        
        let grouped = Dictionary(grouping: logs) { entry -> String in
            guard let date = Self.parseISO8601Date(entry.postedAt) else { return "" }
            return labelFormatter.string(from: date)
        }
        
        return grouped.compactMap { label, items -> (String, [AlbumLogEntry])? in
            guard !label.isEmpty else { return nil }
            return (label, items)
        }
        .sorted { lhs, rhs in
            guard let l = Self.parseISO8601Date(lhs.1.first!.postedAt),
                  let r = Self.parseISO8601Date(rhs.1.first!.postedAt) else { return false }
            return l > r
        }
    }
    
    // postedAt 문자열을 Date 로 파싱 (밀리초/타임존 없는 포맷까지 단계적 폴백)
    static func parseISO8601Date(_ value: String) -> Date? {
        if let date = isoFormatterWithFractionalSeconds.date(from: value) { return date }
        if let date = isoFormatter.date(from: value) { return date }
        // timezone 없는 포맷 대응 (Spring Boot LocalDateTime 등)
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        for format in [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss"
        ] {
            fallback.dateFormat = format
            if let date = fallback.date(from: value) { return date }
        }
        print("[AlbumDetailViewModel] postedAt 파싱 실패: \(value)")
        return nil
    }
}
