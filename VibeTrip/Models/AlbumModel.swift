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
        case .jPop:         return "J_POP"
        case .latin:        return "LATIN"
        case .rnb:          return "R_AND_B"
        case .rock:         return "ROCK"
        case .country:      return "COUNTRY"
        case .acoustic:     return "ACOUSTIC"
        case .indie:        return "INDIE"
        case .ballad:       return "BALLAD"
        case .classical:    return "CLASSICAL"
        case .jazz:         return "JAZZ"
        case .loFi:         return "LO_FI"
        case .ambient:      return "AMBIENT"
        case .cinematic:    return "CINEMATIC"
        case .newAge:       return "NEW_AGE"
        case .chillout:     return "CHILLOUT"
        case .bossaNova:    return "BOSSA_NOVA"
        case .tropicalHouse: return "TROPICAL_HOUSE"
        case .postRock:     return "POST_ROCK"
        case .classicSolo:  return "CLASSIC_SOLO"
        case .acousticFolk: return "ACOUSTIC_FOLK"
        case .deepHouse:    return "DEEP_HOUSE"
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
    let title: String?      // nil: 서버에서 타이틀 생성 중 상태 (빈 문자열도 nil 처리)
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

    // mock 데이터 생성용 memberwise init
    init(id: Int, title: String?, location: String, startDate: String, endDate: String, coverImageUrl: URL?) {
        self.id = id
        self.title = title
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.coverImageUrl = coverImageUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        // 빈 문자열("")은 서버 미생성 상태이므로 nil로 처리
        let rawTitle = try container.decodeIfPresent(String.self, forKey: .title)
        title = rawTitle?.isEmpty == true ? nil : rawTitle
        location = try container.decode(String.self, forKey: .location)
        startDate = try container.decode(String.self, forKey: .startDate)
        endDate = try container.decode(String.self, forKey: .endDate)
        coverImageUrl = try container.decodeIfPresent(URL.self, forKey: .coverImageUrl)
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

// MARK: - AlbumLogUpdateRequest

// 로그 수정 요청 모델 (텍스트 + 새 사진 + 삭제할 이미지 ID)
struct AlbumLogUpdateRequest {
    let albumId: String
    let albumLogId: Int
    let logText: String
    let newPhotoDataList: [Data]
    let removeImageIds: [Int64]  // 삭제할 기존 이미지 ID 목록 (서버 Int64 기준)
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
    let id: Int64      // 이미지 식별자 (삭제 시 removeImageIds에 사용)
    let imageUrl: URL
}

// MARK: - AlbumLogListPayload

// 로그 목록 응답 래퍼 (커서 기반 페이지네이션)
struct AlbumLogListPayload: Decodable {
    let content: [AlbumLogEntry]
    let hasNext: Bool
}

// MARK: - AlbumDetail

// 단일 앨범 조회 응답 (GET /api/v1/albums/{albumId})
struct AlbumDetail: Decodable {
    let title: String?
    let coverImageUrl: URL?
    let region: String
    let travelStartDate: String
    let travelEndDate: String
    let musicUrl: URL?        // 생성 전: nil (빈 문자열도 nil로 처리)
    // 수정 화면 Pre-fill용 필드 (백엔드 단일 앨범 조회 응답에 추가됨)
    let genre: AlbumGenre?
    let vocalGender: VocalGender?
    let withLyrics: Bool
    let comment: String?

    // memberwise init: mock 데이터 생성용
    init(
        title: String?,
        coverImageUrl: URL?,
        region: String,
        travelStartDate: String,
        travelEndDate: String,
        musicUrl: URL?,
        genre: AlbumGenre? = nil,
        vocalGender: VocalGender? = nil,
        withLyrics: Bool = false,
        comment: String? = nil
    ) {
        self.title = title
        self.coverImageUrl = coverImageUrl
        self.region = region
        self.travelStartDate = travelStartDate
        self.travelEndDate = travelEndDate
        self.musicUrl = musicUrl
        self.genre = genre
        self.vocalGender = vocalGender
        self.withLyrics = withLyrics
        self.comment = comment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // 빈 문자열(""): 서버 미생성 상태 -> nil 처리
        let rawTitle = try container.decodeIfPresent(String.self, forKey: .title)
        title = rawTitle?.isEmpty == true ? nil : rawTitle
        coverImageUrl = try container.decodeIfPresent(URL.self, forKey: .coverImageUrl)
        region = try container.decode(String.self, forKey: .region)
        travelStartDate = try container.decode(String.self, forKey: .travelStartDate)
        travelEndDate = try container.decode(String.self, forKey: .travelEndDate)
        // URL(string: ""): nil 반환하므로 빈 문자열 자동 처리
        let rawMusicUrl = try container.decodeIfPresent(String.self, forKey: .musicUrl)
        musicUrl = rawMusicUrl.flatMap { $0.isEmpty ? nil : URL(string: $0) }
        genre = try container.decodeIfPresent(AlbumGenre.self, forKey: .genre)
        vocalGender = try container.decodeIfPresent(VocalGender.self, forKey: .vocalGender)
        withLyrics = try container.decodeIfPresent(Bool.self, forKey: .withLyrics) ?? false
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
    }

    private enum CodingKeys: String, CodingKey {
        case title, coverImageUrl, region, travelStartDate, travelEndDate, musicUrl
        case genre, vocalGender, withLyrics, comment
    }
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
        // title: nil -> 타이틀 생성 중 skeleton UI 테스트용
        .init(
            id: 4, title: nil,
            location: "한국 제주도",
            startDate: "2026-04-01", endDate: "2026-04-03",
            coverImageUrl: nil
        ),
    ]
}

extension AlbumLogEntry {
    static var mock: AlbumLogEntry {
        .init(
            id: 1,
            description: "도톤보리 야경이 정말 아름다웠다. 네온사인 불빛이 강물에 반사되던 그 순간이 잊혀지지 않는다.",
            postedAt: "2026-01-13T21:00:00Z",
            images: []
        )
    }

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

extension AlbumDetail {
    // title + musicUrl 모두 준비된 상태
    static let mockReady = AlbumDetail(
        title: "오사카 도톤보리",
        coverImageUrl: nil,
        region: "일본 오사카",
        travelStartDate: "2026-01-12",
        travelEndDate: "2026-01-15",
        musicUrl: URL(string: "https://example.com/music.mp3"),
        genre: .jazz,
        vocalGender: .female,
        withLyrics: true,
        comment: "처음 가본 오사카, 도톤보리 야경이 압도적이었다."
    )
    // 둘 다 아직 생성 중
    static let mockPending = AlbumDetail(
        title: nil,
        coverImageUrl: nil,
        region: "한국 제주도",
        travelStartDate: "2026-04-01",
        travelEndDate: "2026-04-03",
        musicUrl: nil,
        genre: .loFi,
        vocalGender: nil,
        withLyrics: false,
        comment: nil
    )
}
#endif
