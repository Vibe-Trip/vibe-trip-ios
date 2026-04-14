//
//  MainPageViewModel.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import Foundation
import Combine
import UserNotifications

// MARK: - MainPageViewModel

@MainActor
final class MainPageViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) var albums: [AlbumCard] = []   // 캐러셀에 표시할 앨범 목록
    @Published private(set) var isLoading: Bool = false     // 네트워크 요청 중 여부
    @Published private(set) var errorMessage: String? = nil // 에러 발생 시 메시지
    @Published private(set) var didFinishInitialLoad: Bool = false // 최초 API 응답 완료 여부

    // 신고로 숨긴 앨범 ID 목록 (클라이언트 인메모리, API 연동 전 목 처리)
    private var hiddenAlbumIds: Set<Int> = []

    // 신고된 앨범을 제외한 표시용 앨범 목록
    var visibleAlbums: [AlbumCard] {
        albums.filter { !hiddenAlbumIds.contains($0.id) }
    }
    
    // 최초 응답 전에는 empty state 대신 로딩 placeholder를 노출
    var isInitialLoading: Bool {
        !didFinishInitialLoad
    }

    // MARK: - Pagination State

    private var cursor: Int? = nil       // 다음 요청에 사용할 cursor: 마지막 AlbumId
    private var hasNext: Bool = true     // 서버에 추가 데이터 존재 여부
    private var isFetching: Bool = false // 중복 요청 방지 플래그

    // MARK: - Dependencies

    private let albumService: AlbumServiceProtocol
    // 알림 권한 상태 조회 클로저 (테스트 시 주입 가능)
    private let notificationAuthorizationChecker: @Sendable () async -> UNAuthorizationStatus

    // MARK: - Load State

    // 최초 로드 완료 여부 (재진입 시 풀 리셋 방지)
    private var hasLoaded = false

    // MARK: - Polling

    // albumId별 음악 생성 완료 폴링 Task (중복 방지)
    private var pollingTasks: [Int: Task<Void, Never>] = [:]
    // 음악 생성 완료된 앨범 ID 집합 (재조회 시 유지 -> 이미 준비된 앨범 스켈레톤 방지)
    private var readyAlbumIds: Set<Int> = []
    // 수정 후 강제 폴링 대상 앨범 ID 집합 (title 있어도 폴링 재시작)
    private var pendingPollingIds: Set<Int> = []
    // 폴링 간격 (기본 5초, 테스트 시 0으로 주입 가능)
    private let pollingInterval: UInt64

    // MARK: - Init

    nonisolated init(
        albumService: AlbumServiceProtocol = AlbumService(),
        pollingInterval: UInt64 = 5_000_000_000,
        notificationAuthorizationChecker: @escaping @Sendable () async -> UNAuthorizationStatus = {
            await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }
    ) {
        self.albumService = albumService
        self.pollingInterval = pollingInterval
        self.notificationAuthorizationChecker = notificationAuthorizationChecker
    }

    // MARK: - Load

    // 화면 진입 시 호출 (재진입 시 스킵)
    func loadAlbums() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        cursor = nil
        hasNext = true
        albums = []
        await fetchNextPage()
    }

    // 명시적 새로고침 (needsAlbumRefresh, 앨범 삭제/수정 후 복귀)
    // readyAlbumIds는 초기화하지 않음 -> 이미 준비된 앨범은 재조회 후에도 스켈레톤 없이 바로 표시
    func reloadAlbums() async {
        hasLoaded = false
        cancelAllPolling()
        await loadAlbums()
    }

    // 화면 전환 중 백그라운드 새로고침 전용
    func refreshAlbumsWithoutClearing() async {
        guard !isFetching else { return }
        cancelAllPolling()
        isFetching = true
        isLoading = true
        defer { isFetching = false; isLoading = false }
        do {
            let payload = try await albumService.fetchAlbums(cursor: nil, limit: 10)
            albums = payload.content
            hasNext = payload.hasNext
            cursor = payload.content.last?.id
            hasLoaded = true
            errorMessage = nil
            await startPollingIfNeeded()
        } catch {
            // 실패 시 기존 목록을 유지하고 에러만 갱신
            errorMessage = "앨범을 불러오지 못했습니다."
            // fetch 실패 시에도 기존 앨범 목록 기준으로 폴링 복구
            await startPollingIfNeeded()
        }
    }

    // 앨범 수정 완료 후 해당 앨범을 미준비 상태로 전환 -> 폴링 재시작 대상
    func markAlbumNotReady(albumId: Int) {
        readyAlbumIds.remove(albumId)
        pendingPollingIds.insert(albumId)
    }

    // 음악 생성 완료 여부
    func isReady(for albumId: Int) -> Bool {
        readyAlbumIds.contains(albumId)
    }

    // 결과: albums 배열에 누적, 완료 후 musicUrl 미준비 앨범 폴링 시작
    private func fetchNextPage() async {
        guard hasNext, !isFetching else { return }
        isFetching = true
        isLoading = true
        defer {
            isFetching = false
            isLoading = false
            if !didFinishInitialLoad {
                didFinishInitialLoad = true
            }
        }
        do {
            let payload = try await albumService.fetchAlbums(cursor: cursor, limit: 10)
            albums.append(contentsOf: payload.content)
            hasNext = payload.hasNext
            cursor = payload.content.last?.id // 마지막 albumId: 다음 요청 cursor
            errorMessage = nil
            await startPollingIfNeeded()
        } catch {
            errorMessage = "앨범을 불러오지 못했습니다."
        }
    }

    // 캐러셀 끝에서 2번째 카드 도달 시 추가 로드 트리거
    func loadMoreIfNeeded(currentIndex: Int) async {
        guard currentIndex >= albums.count - 2 else { return }
        await fetchNextPage()
    }

    // MARK: - Polling

    // 음악 미생성 앨범에 대해 폴링 Task 시작 (이미 준비됐거나 폴링 중이면 스킵)
    // 알림 권한이 있는 경우: 이미 완료된 앨범 감지를 위해 1회 즉시 확인만 수행, 반복 폴링 스킵
    // 알림 권한이 없는 경우: 기존 반복 폴링 유지
    private func startPollingIfNeeded() async {
        let status = await notificationAuthorizationChecker()
        let shouldPoll = status != .authorized
        for album in albums where !readyAlbumIds.contains(album.id) {
            guard pollingTasks[album.id] == nil else { continue }
            let albumId = album.id
            // title이 있고 재생성 대기 중이 아닌 앨범: 서버에서 이미 완료된 것으로 즉시 ready 처리
            if album.title != nil && !pendingPollingIds.contains(albumId) {
                readyAlbumIds.insert(albumId)
                continue
            }
            if shouldPoll {
                pollingTasks[albumId] = Task { [weak self] in
                    await self?.pollMusic(for: albumId)
                }
            } else {
                // 앱 진입 시 이미 완료된 앨범을 감지하기 위한 1회 즉시 확인
                pollingTasks[albumId] = Task { [weak self] in
                    await self?.checkMusicOnce(for: albumId)
                }
            }
        }
    }

    // 권한 있는 경우 앱 진입 시 1회만 완료 여부 확인 (이후 완료는 FCM으로 수신)
    // 1회 확인 실패 시(서버 반영 지연 등) 반복 폴링으로 폴백 -> 영구 스켈레톤 방지
    private func checkMusicOnce(for albumId: Int) async {
        guard !Task.isCancelled else {
            pollingTasks[albumId] = nil
            return
        }
        if let detail = try? await albumService.fetchAlbum(albumId: albumId),
           detail.musicUrl != nil {
            applyAlbumReady(title: detail.title, for: albumId)
            return
        }
        // 단건 확인 실패: 반복 폴링으로 폴백
        guard !Task.isCancelled else {
            pollingTasks[albumId] = nil
            return
        }
        await pollMusic(for: albumId)
    }

    // FCM COMPLETED 수신 시 호출: 기존 폴링 취소 후 fetchAlbum 1회로 완료 처리
    // 1회 확인 실패 시(서버 replication 지연 등) 반복 폴링으로 폴백 -> 영구 스켈레톤 방지
    func handleAlbumCompleted(albumId: Int) async {
        pollingTasks[albumId]?.cancel()
        pollingTasks[albumId] = nil
        if let detail = try? await albumService.fetchAlbum(albumId: albumId),
           detail.musicUrl != nil {
            applyAlbumReady(title: detail.title, for: albumId)
            return
        }
        // 단건 확인 실패: 반복 폴링으로 폴백
        pollingTasks[albumId] = Task { [weak self] in
            await self?.pollMusic(for: albumId)
        }
    }

    // musicUrl 조회: 즉시 1회 확인 후 5초 간격, 최대 120회(10분)
    private func pollMusic(for albumId: Int) async {
        for attempt in 0..<120 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: pollingInterval)
            }
            guard !Task.isCancelled else { return }
            guard let detail = try? await albumService.fetchAlbum(albumId: albumId),
                  detail.musicUrl != nil else { continue }
            applyAlbumReady(title: detail.title, for: albumId)
            return
        }
        pollingTasks[albumId] = nil
    }

    // 음악 생성 완료 시: title 업데이트 + readyAlbumIds 등록 + 폴링 Task 정리
    private func applyAlbumReady(title: String?, for albumId: Int) {
        if let title, let idx = albums.firstIndex(where: { $0.id == albumId }) {
            let old = albums[idx]
            albums[idx] = AlbumCard(
                id: old.id,
                title: title,
                location: old.location,
                startDate: old.startDate,
                endDate: old.endDate,
                coverImageUrl: old.coverImageUrl,
                logImageCount: old.logImageCount,
                previewLogImages: old.previewLogImages
            )
        }
        readyAlbumIds.insert(albumId)
        pendingPollingIds.remove(albumId)
        pollingTasks[albumId] = nil
    }

    // 신고된 앨범을 로컬에서 숨김 처리
    func hideAlbum(id: Int) {
        // TODO: 신고하기 API 연동 후 서버 요청 추가
        hiddenAlbumIds.insert(id)
    }

    // 뷰 사라질 때 모든 폴링 Task 취소
    func cancelAllPolling() {
        pollingTasks.values.forEach { $0.cancel() }
        pollingTasks.removeAll()
    }
}
