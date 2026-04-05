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
}
