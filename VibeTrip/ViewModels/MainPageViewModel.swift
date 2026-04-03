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

    // MARK: - Init

    nonisolated init(albumService: AlbumServiceProtocol = AlbumService()) {
        self.albumService = albumService
    }

    // MARK: - Load

    // 화면 진입 시 호출
    func loadAlbums() async {
        cursor = nil
        hasNext = true
        albums = []
        await fetchNextPage()
    }

    // 결과: albums 배열에 누적
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
        } catch {
            errorMessage = "앨범을 불러오지 못했습니다."
        }
    }

    // 캐러셀 끝에서 2번째 카드 도달 시 추가 로드 트리거
    func loadMoreIfNeeded(currentIndex: Int) async {
        guard currentIndex >= albums.count - 2 else { return }
        await fetchNextPage()
    }

    // 앨범 삭제 완료 후 캐러셀에서 해당 앨범 제거
    func removeAlbum(id: Int) {
        albums.removeAll { $0.id == id }
    }
}
