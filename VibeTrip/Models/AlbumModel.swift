//
//  AlbumModel.swift
//  VibeTrip
//
//  Created by CHOI on 3/24/26.
//

import Foundation

// MARK: - Decodable 확장 (MakeAlbumModel에 정의된 enum 재사용)

extension AlbumGenre: Decodable {

    // 서버 전송용 enum 값
    var serverValue: String {
        switch self {
        case .pop:          return "POP"
        case .kPop:         return "K_POP"
        case .ballad:       return "BALLAD"
        case .hipHop:       return "HIP_HOP"
        case .rnb:          return "R_AND_B"
        case .rock:         return "ROCK"
        case .cityPop:      return "CITY_POP"
        case .edm:          return "EDM"
        case .latinPop:     return "LATIN_POP"
        case .country:      return "COUNTRY"
        case .indie:        return "INDIE"
        case .gospel:       return "GOSPEL"
        case .classical:    return "CLASSICAL"
        case .loFi:         return "LO_FI"
        case .jazz:         return "JAZZ"
        case .ambient:      return "AMBIENT"
        case .cinematic:    return "CINEMATIC"
        case .newAge:       return "NEW_AGE"
        case .acoustic:     return "ACOUSTIC"
        case .electronic:   return "ELECTRONIC"
        case .bossaNova:    return "BOSSA_NOVA"
        case .chillHop:     return "CHILL_HOP"
        case .tropicalHouse: return "TROPICAL_HOUSE"
        case .techno:       return "TECHNO"
        }
    }
}

extension LyricsOption: Decodable {}

extension VocalGender: Decodable {

    // 서버 전송용 enum 값
    var serverValue: String {
        switch self {
        case .male:   return "M"
        case .female: return "F"
        }
    }
}

// MARK: - AlbumCard

// 메인 페이지 앨범 목록 카드 모델 (GET /api/v1/albums)
struct AlbumCard: Identifiable, Decodable {
    let id: Int             // "albumId": 페이지네이션 cursor값
    let title: String
    let location: String    // "region"
    let startDate: String   // "travelStartDate"
    let endDate: String     // "travelEndDate"
    let coverImageUrl: URL?

    // Swift 프로퍼티명 <-> 서버 필드명 매핑
    enum CodingKeys: String, CodingKey {
        case id = "albumId"
        case title
        case location = "region"
        case startDate = "travelStartDate"
        case endDate = "travelEndDate"
        case coverImageUrl
    }
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

// 앨범 목록 응답 래퍼
struct AlbumListPayload: Decodable {
    let content: [AlbumCard] // "content"
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

// MARK: - AlbumLogEntry

// 로그 목록 아이템 (GET /api/v1/albums/{albumId}/album-logs)
struct AlbumLogEntry: Identifiable, Decodable {
    let id: Int
    let description: String
    let postedAt: String        // ISO8601 date-time — ViewModel에서 파싱
    let images: [AlbumLogImage]
}

// MARK: - AlbumLogImage

// 로그 첨부 이미지
struct AlbumLogImage: Decodable {
    let imageUrl: URL
}

// MARK: - AlbumLogListPayload

// 로그 목록 응답 래퍼 (커서 기반 페이지네이션)
struct AlbumLogListPayload: Decodable {
    let content: [AlbumLogEntry]
    let hasNext: Bool
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
            id: 1, title: "오사카 도톤보리",
            location: "일본 오사카",
            startDate: "2026-01-12", endDate: "2026-01-15",
            coverImageUrl: nil
        ),
        .init(
            id: 2, title: "보홀 에메랄드 바다",
            location: "필리핀 보홀",
            startDate: "2024-11-14", endDate: "2024-11-19",
            coverImageUrl: nil
        ),
        .init(
            id: 3, title: "파리 에펠탑",
            location: "프랑스 파리",
            startDate: "2025-06-01", endDate: "2025-06-07",
            coverImageUrl: nil
        ),
    ]
}

extension AlbumLogEntry {
    static let mockItems: [AlbumLogEntry] = [
        .init(
            id: 1,
            description: "도톤보리 야경이 정말 아름다웠다. 네온사인 불빛이 강물에 반사되던 그 순간이 잊혀지지 않는다.",
            postedAt: "2026-01-13T21:00:00Z",
            images: []
        ),
        .init(
            id: 2,
            description: "신사이바시에서 쇼핑을 실컷 했다. 발이 아플 정도로 걸었지만 너무 즐거웠다.",
            postedAt: "2026-01-13T14:30:00Z",
            images: []
        ),
        .init(
            id: 3,
            description: "오사카 성 아침 산책. 조용하고 평화로운 시간이었다.",
            postedAt: "2026-01-12T09:00:00Z",
            images: []
        )
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
