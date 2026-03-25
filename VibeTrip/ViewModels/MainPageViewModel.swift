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

    // 앨범 카드 수
    // TODO: (서버 연결 시 [AlbumCardItem]으로 교체)
    @Published private(set) var albumCount: Int

    // MARK: - Init

    nonisolated init(albumCount: Int = 0) {
        self._albumCount = Published(initialValue: albumCount)
    }

    // MARK: - Load

    func loadAlbums() async {
        // TODO: 서버 연결 시 AlbumService.fetchAlbums() 호출로 교체
        albumCount = 4
    }
}
