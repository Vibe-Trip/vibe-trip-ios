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

    // albumId별 title 폴링 Task (중복 방지)
    private var pollingTasks: [Int: Task<Void, Never>] = [:]
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

    // 명시적 새로고침 (needsAlbumRefresh, 앨범 삭제 후 복귀)
    func reloadAlbums() async {
        hasLoaded = false
        cancelAllPolling()
        await loadAlbums()
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

    // title nil 앨범에 대해 폴링 Task 시작 (이미 폴링 중이면 스킵)
    private func startPollingIfNeeded() {
        for album in albums where album.title == nil {
            guard pollingTasks[album.id] == nil else { continue }
            let albumId = album.id
            pollingTasks[albumId] = Task { [weak self] in
                await self?.pollTitle(for: albumId)
            }
        }
    }

    // 타이틀 조회: 5초 간격, 최대 120회(10분)
    private func pollTitle(for albumId: Int) async {
        for _ in 0..<120 {
            try? await Task.sleep(nanoseconds: pollingInterval)
            guard !Task.isCancelled else { return }
            guard let detail = try? await albumService.fetchAlbum(albumId: albumId),
                  let title = detail.title else { continue }
            applyTitle(title, for: albumId)
            return
        }
        pollingTasks[albumId] = nil
    }

    // 타이틀 수신 시: 해당 앨범 -> albums 배열에서 교체 후 폴링 Task 정리
    private func applyTitle(_ title: String, for albumId: Int) {
        guard let idx = albums.firstIndex(where: { $0.id == albumId }) else { return }
        let old = albums[idx]
        albums[idx] = AlbumCard(
            id: old.id,
            title: title,
            location: old.location,
            startDate: old.startDate,
            endDate: old.endDate,
            coverImageUrl: old.coverImageUrl
        )
        pollingTasks[albumId] = nil
    }

    // 뷰 사라질 때 모든 폴링 Task 취소
    func cancelAllPolling() {
        pollingTasks.values.forEach { $0.cancel() }
        pollingTasks.removeAll()
    }
}
