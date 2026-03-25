//
//  MakeAlbumModel.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import Foundation

// 앨범 생성 플로우의 단계 전환 상태
enum AlbumCreationStep: Hashable {
    case requiredInput
    case optionalInput
    case loading
}

// 가사 포함 여부로 분기
enum LyricsOption: String, CaseIterable, Identifiable {
    case include
    case exclude

    var id: String { rawValue }

    var title: String {
        switch self {
        case .include:
            return "가사 포함"
        case .exclude:
            return "가사 미포함"
        }
    }

    var defaultGenreTitle: String {
        switch self {
        case .include:
            return "Pop"
        case .exclude:
            return "Classical"
        }
    }
}

// 가사 포함: 보컬 성별 선택
enum VocalGender: String, CaseIterable, Identifiable {
    case male
    case female

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male:
            return "남성 보컬"
        case .female:
            return "여성 보컬"
        }
    }
}

// 선택 입력 단계: 장르목록
enum AlbumGenre: String, CaseIterable, Identifiable {
    case pop = "Pop"
    case kPop = "K-Pop"
    case ballad = "Ballad"
    case hipHop = "HipHop"
    case rnb = "R&B"
    case rock = "Rock"
    case cityPop = "City Pop"
    case edm = "EDM"
    case latinPop = "Latin Pop"
    case country = "Country"
    case indie = "Indie"
    case gospel = "Gospel"
    case classical = "Classical"
    case loFi = "Lo-fi"
    case jazz = "Jazz"
    case ambient = "Ambient"
    case cinematic = "Cinematic"
    case newAge = "New Age"
    case acoustic = "Acoustic"
    case electronic = "Electronic"
    case bossaNova = "Bossa Nova"
    case chillHop = "Chill-hop"
    case tropicalHouse = "Tropical House"
    case techno = "Techno"

    var id: String { rawValue }

    // 장르(가사 포함)
    static var vocalGenres: [AlbumGenre] {
        [
            .pop,
            .kPop,
            .ballad,
            .hipHop,
            .rnb,
            .rock,
            .cityPop,
            .edm,
            .latinPop,
            .country,
            .indie,
            .gospel
        ]
    }

    // 장르(가사 포함X)
    static var instrumentalGenres: [AlbumGenre] {
        [
            .classical,
            .loFi,
            .jazz,
            .ambient,
            .cinematic,
            .newAge,
            .acoustic,
            .electronic,
            .bossaNova,
            .chillHop,
            .tropicalHouse,
            .techno
        ]
    }
}

// 장르 설명 모달 텍스트
struct GenreDescriptionModel: Identifiable, Equatable {
    let genre: AlbumGenre
    let description: String

    var id: String { genre.rawValue }
}

// 입력 상태 모델
struct MakeAlbumModel: Equatable {
    var travelDestination: String = ""
    var startDate: Date?
    var endDate: Date?
    var lyricsOption: LyricsOption = .exclude
    var vocalGender: VocalGender?
    var selectedGenre: AlbumGenre?
    var albumCommentary: String = ""

    // 여행기간 텍스트
    var formattedTravelDateRange: String {
        guard let startDate, let endDate else {
            return ""
        }

        return "\(startDate.albumDateString) ~ \(endDate.albumDateString)"
    }
}

extension Date {

    // 화면 표시용 포맷
    var albumDateString: String {
        Self.albumDateFormatter.string(from: self)
    }

    private static let albumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}
