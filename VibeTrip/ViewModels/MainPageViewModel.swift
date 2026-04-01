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
}
