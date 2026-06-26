//
//  AlbumDetailModel.swift
//  VibeTrip
//
//  Created by CHOI on 6/23/26.
//

import Foundation

// MARK: - AlbumDetailDisplayModel
// 앨범 상세 화면 표시용

struct AlbumDetailDisplayModel {
    let albumId: Int
    let title: String
    let destination: String
    let dateText: String
    let coverImageUrl: URL?
    let contentState: AlbumDetailContentState
    let musicUrl: URL?           // nil : 아직 생성 중
}

// MARK: - AlbumDetailContentState
// 로그 유무에 따른 콘텐츠 상태

enum AlbumDetailContentState {
    case empty
    case hasLogs    // TODO: AlbumLogFeedItem 모델 추가 후 associated value([AlbumLogFeedItem]) 연결
}
