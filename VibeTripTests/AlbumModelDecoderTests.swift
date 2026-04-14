//
//  AlbumModelDecoderTests.swift
//  VibeTrip
//
//  Created by CHOI on 4/5/26.
//

import XCTest
@testable import VibeTrip

final class AlbumModelDecoderTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - AlbumCard

    // title: "" -> nil 변환 (title 미생성 상태)
    func test_albumCard_emptyTitle_decodesAsNil() throws {
        let json = """
        {"albumId":1,"title":"","region":"서울","travelStartDate":"2026-01-01","travelEndDate":"2026-01-05"}
        """.data(using: .utf8)!

        let card = try decoder.decode(AlbumCard.self, from: json)

        XCTAssertNil(card.title)
    }

    // title: null -> nil
    func test_albumCard_nullTitle_decodesAsNil() throws {
        let json = """
        {"albumId":1,"title":null,"region":"서울","travelStartDate":"2026-01-01","travelEndDate":"2026-01-05"}
        """.data(using: .utf8)!

        let card = try decoder.decode(AlbumCard.self, from: json)

        XCTAssertNil(card.title)
    }

    // title: 유효한 값 -> 그대로 유지
    func test_albumCard_validTitle_decodesCorrectly() throws {
        let json = """
        {"albumId":1,"title":"오사카 여행","region":"서울","travelStartDate":"2026-01-01","travelEndDate":"2026-01-05"}
        """.data(using: .utf8)!

        let card = try decoder.decode(AlbumCard.self, from: json)

        XCTAssertEqual(card.title, "오사카 여행")
    }

    // MARK: - AlbumDetail

    // title: "" -> nil 변환 (title 미생성 상태)
    func test_albumDetail_emptyTitle_decodesAsNil() throws {
        let json = """
        {"title":"","region":"서울","travelStartDate":"2026-01-01","travelEndDate":"2026-01-05","musicUrl":""}
        """.data(using: .utf8)!

        let detail = try decoder.decode(AlbumDetail.self, from: json)

        XCTAssertNil(detail.title)
    }

    // musicUrl: "" -> nil 변환 (title 미생성 상태)
    func test_albumDetail_emptyMusicUrl_decodesAsNil() throws {
        let json = """
        {"title":"타이틀","region":"서울","travelStartDate":"2026-01-01","travelEndDate":"2026-01-05","musicUrl":""}
        """.data(using: .utf8)!

        let detail = try decoder.decode(AlbumDetail.self, from: json)

        XCTAssertNil(detail.musicUrl)
    }

    // musicUrl: 유효한 URL -> URL로 디코딩
    func test_albumDetail_validMusicUrl_decodesCorrectly() throws {
        let json = """
        {"title":"타이틀","region":"서울","travelStartDate":"2026-01-01","travelEndDate":"2026-01-05","musicUrl":"https://example.com/music.mp3"}
        """.data(using: .utf8)!

        let detail = try decoder.decode(AlbumDetail.self, from: json)

        XCTAssertEqual(detail.musicUrl, URL(string: "https://example.com/music.mp3"))
    }

    // MARK: - AlbumDetail 신규 필드

    // 모든 신규 필드 포함 응답 -> 정상 디코딩
    func test_albumDetail_newFields_decodeCorrectly() throws {
        let json = """
        {
          "title":"타이틀","region":"서울",
          "travelStartDate":"2026-01-01","travelEndDate":"2026-01-05","musicUrl":"",
          "genre":"JAZZ","vocalGender":"F","withLyrics":true,"comment":"코멘트"
        }
        """.data(using: .utf8)!

        let detail = try decoder.decode(AlbumDetail.self, from: json)

        XCTAssertEqual(detail.genre, .jazz)
        XCTAssertEqual(detail.vocalGender, .female)
        XCTAssertTrue(detail.withLyrics)
        XCTAssertEqual(detail.comment, "코멘트")
    }

    // vocalGender: "N" -> nil (가사 없음)
    func test_albumDetail_vocalGenderN_decodesAsNil() throws {
        let json = """
        {"title":"타이틀","region":"서울","travelStartDate":"2026-01-01","travelEndDate":"2026-01-05","musicUrl":"","genre":"LO_FI","vocalGender":"N","withLyrics":false}
        """.data(using: .utf8)!

        let detail = try decoder.decode(AlbumDetail.self, from: json)

        XCTAssertNil(detail.vocalGender)
    }

    // vocalGender: "M" -> .male
    func test_albumDetail_vocalGenderM_decodesMale() throws {
        let json = """
        {"title":"타이틀","region":"서울","travelStartDate":"2026-01-01","travelEndDate":"2026-01-05","musicUrl":"","genre":"POP","vocalGender":"M","withLyrics":true}
        """.data(using: .utf8)!

        let detail = try decoder.decode(AlbumDetail.self, from: json)

        XCTAssertEqual(detail.vocalGender, .male)
    }

    // 신규 필드 누락 시 -> 기본값 적용 (기존 응답과의 하위 호환)
    func test_albumDetail_missingNewFields_usesDefaults() throws {
        let json = """
        {"title":"타이틀","region":"서울","travelStartDate":"2026-01-01","travelEndDate":"2026-01-05","musicUrl":""}
        """.data(using: .utf8)!

        let detail = try decoder.decode(AlbumDetail.self, from: json)

        XCTAssertNil(detail.genre)
        XCTAssertNil(detail.vocalGender)
        XCTAssertFalse(detail.withLyrics)
        XCTAssertNil(detail.comment)
    }

    // MARK: - AlbumGenre 서버값 디코딩

    // 알려진 서버값 -> 대응 case로 디코딩
    func test_albumGenre_knownServerValues_decodeCorrectly() throws {
        let cases: [(serverValue: String, expected: AlbumGenre)] = [
            ("POP", .pop), ("K_POP", .kPop), ("JAZZ", .jazz),
            ("LO_FI", .loFi), ("CLASSICAL", .classical), ("BOSSA_NOVA", .bossaNova)
        ]

        for (serverValue, expected) in cases {
            let json = "\"\(serverValue)\"".data(using: .utf8)!
            let genre = try decoder.decode(AlbumGenre.self, from: json)
            XCTAssertEqual(genre, expected, "서버값 \(serverValue) 디코딩 실패")
        }
    }

    // 알 수 없는 서버값 -> DecodingError throw
    func test_albumGenre_unknownServerValue_throwsDecodingError() {
        let json = "\"UNKNOWN_GENRE\"".data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(AlbumGenre.self, from: json))
    }
}
