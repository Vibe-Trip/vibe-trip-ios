//
//  AlbumModel.swift
//  VibeTrip
//
//  Created by CHOI on 3/24/26.
//

import Foundation

// MARK: - Decodable 확장 (MakeAlbumModel에 정의된 enum 재사용)

extension AlbumGenre: Decodable {}
extension LyricsOption: Decodable {}
extension VocalGender: Decodable {}

// MARK: - AlbumCard

// 메인 페이지 앨범 목록 카드 모델
struct AlbumCard: Identifiable, Decodable {
    let id: String
    let title: String
    let location: String
    
    // 서버 응답 포맷
    let startDate: String
    let endDate: String
    let coverImageUrl: URL?
    let thumbnailImageUrls: [URL]
    let musicTitle: String?
    let musicGenre: AlbumGenre
    let createdAt: Date
}

// MARK: - AlbumLog

// 앨범 로그 상세 모델 (로그 페이지)
struct AlbumLog: Decodable {
    let albumId: String
    let title: String
    let location: String
    let startDate: Date
    let endDate: Date
    let photoUrls: [URL]
    let musicUrl: URL?
    let musicTitle: String?
    let commentary: String
    let genre: AlbumGenre
    let lyricsOption: LyricsOption
    let vocalGender: VocalGender?
    let logText: String?         // 사용자가 작성한 로그 텍스트
    let logPhotoUrls: [URL]     // 로그에 첨부된 사진 URL 목록
}

// MARK: - AlbumListPayload

// 앨범 목록 응답 래퍼 (커서 기반 페이지네이션)
struct AlbumListPayload: Decodable {
    let albums: [AlbumCard]
    let totalCount: Int
    let hasNext: Bool
}

// MARK: - AlbumUpdateRequest

// 앨범 수정 요청 모델
struct AlbumUpdateRequest {
    let photoData: Data?
    let title: String
    let location: String
    let startDate: Date
    let endDate: Date
    let lyricsOption: LyricsOption
    let vocalGender: VocalGender?
    let genre: AlbumGenre
    let commentary: String
}

// MARK: - AlbumLogRequest

// 로그 저장 요청 모델 (텍스트 + 사진)
struct AlbumLogRequest {
    let albumId: String
    let logText: String
    let photoDataList: [Data]
}

// MARK: - AlbumError

// 앨범 관련 에러 타입
enum AlbumError: Error {
    case networkError
    case timeout
    case serverError
    case unauthorized
    case unknown
}

// MARK: - Mock Data (DEBUG 전용)

#if DEBUG
extension AlbumCard {
    static let mockItems: [AlbumCard] = [
        .init(
            id: "1", title: "오사카 도톤보리", location: "일본 오사카",
            startDate: "2026.01.12", endDate: "2026.01.15",
            coverImageUrl: nil, thumbnailImageUrls: [],
            musicTitle: "Neon Rain", musicGenre: .jazz, createdAt: Date()
        ),
        .init(
            id: "2", title: "보홀 에메랄드 바다", location: "필리핀 보홀",
            startDate: "2024.11.14", endDate: "2024.11.19",
            coverImageUrl: nil, thumbnailImageUrls: [],
            musicTitle: "Ocean Drift", musicGenre: .acoustic, createdAt: Date()
        ),
        .init(
            id: "3", title: "파리 에펠탑", location: "프랑스 파리",
            startDate: "2025.06.01", endDate: "2025.06.07",
            coverImageUrl: nil, thumbnailImageUrls: [],
            musicTitle: "Café Lune", musicGenre: .jazz, createdAt: Date()
        ),
    ]
}

extension AlbumLog {
    static let mock = AlbumLog(
        albumId: "1",
        title: "오사카 도톤보리",
        location: "일본 오사카",
        startDate: Date(),
        endDate: Date(),
        photoUrls: [],
        musicUrl: nil,
        musicTitle: "Neon Rain",
        commentary: "처음 가본 오사카, 도톤보리 야경이 압도적이었다.",
        genre: .jazz,
        lyricsOption: .include,
        vocalGender: .female,
        logText: "도톤보리 야경이 정말 아름다웠다. 네온사인 불빛이 강물에 반사되던 그 순간이 잊혀지지 않는다.",
        logPhotoUrls: []
    )
}
#endif
