//
//  MainPageViewModel.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import Foundation
import Combine

// MARK: - MainPageViewModel

@MainActor
final class MainPageViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) var albums: [AlbumCard] = []   // 캐러셀에 표시할 앨범 목록
    @Published private(set) var isLoading: Bool = false     // 네트워크 요청 중 여부
    @Published private(set) var errorMessage: String? = nil // 에러 발생 시 메시지

    // 신고로 숨긴 앨범 ID 목록 (클라이언트 인메모리, API 연동 전 목 처리)
    private var hiddenAlbumIds: Set<Int> = []

    // 신고된 앨범을 제외한 표시용 앨범 목록
    var visibleAlbums: [AlbumCard] {
        albums.filter { !hiddenAlbumIds.contains($0.id) }
    }

    // MARK: - Pagination State

    private var cursor: Int? = nil       // 다음 요청에 사용할 cursor: 마지막 AlbumId
    private var hasNext: Bool = true     // 서버에 추가 데이터 존재 여부
    private var isFetching: Bool = false // 중복 요청 방지 플래그

    // MARK: - Dependencies

    private let albumService: AlbumServiceProtocol

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

    nonisolated init(albumService: AlbumServiceProtocol = AlbumService(),
                     pollingInterval: UInt64 = 5_000_000_000) {
        self.albumService = albumService
        self.pollingInterval = pollingInterval
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

    // 앨범 수정 완료 후 해당 앨범을 미준비 상태로 전환 -> 폴링 재시작 대상
    func markAlbumNotReady(albumId: Int) {
        readyAlbumIds.remove(albumId)
        pendingPollingIds.insert(albumId)
    }

    // 음악 생성 완료 여부
    func isReady(for albumId: Int) -> Bool {
        readyAlbumIds.contains(albumId)
    }

    // 결과: albums 배열에 누적, 완료 후 title nil 앨범 폴링 시작
    private func fetchNextPage() async {
        guard hasNext, !isFetching else { return }
        isFetching = true
        isLoading = true
        defer { isFetching = false; isLoading = false }
        do {
            let payload = try await albumService.fetchAlbums(cursor: cursor, limit: 10)
            albums.append(contentsOf: payload.content)
            hasNext = payload.hasNext
            cursor = payload.content.last?.id // 마지막 albumId: 다음 요청 cursor
            errorMessage = nil
            // title이 이미 있는 앨범은 음악 생성 완료 상태 → readyAlbumIds에 미리 등록
            // 수정 후 강제 폴링 대상(pendingPollingIds)은 제외
            for album in payload.content where album.title != nil && !pendingPollingIds.contains(album.id) {
                readyAlbumIds.insert(album.id)
            }
            startPollingIfNeeded()
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
    private func startPollingIfNeeded() {
        for album in albums where !readyAlbumIds.contains(album.id) {
            guard pollingTasks[album.id] == nil else { continue }
            let albumId = album.id
            pollingTasks[albumId] = Task { [weak self] in
                await self?.pollMusic(for: albumId)
            }
        }
    }

    // musicUrl 조회: 5초 간격, 최대 120회(10분)
    private func pollMusic(for albumId: Int) async {
        for _ in 0..<120 {
            try? await Task.sleep(nanoseconds: pollingInterval)
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
                coverImageUrl: old.coverImageUrl
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
