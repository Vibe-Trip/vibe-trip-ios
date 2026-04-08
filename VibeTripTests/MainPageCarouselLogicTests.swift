//
//  MainPageCarouselLogicTests.swift
//  VibeTripTests
//
//  Created by CHOI on 4/8/26.
//

import XCTest
@testable import VibeTrip

final class MainPageCarouselLogicTests: XCTestCase {

    // 현재 카드 주변 preloadRange 범위의 커버 이미지만 미리 준비
    func test_preloadCoverImageURLs_returnsURLsAroundCurrentIndex() {
        let albums = makeAlbums(urls: [
            "https://example.com/1.jpg",
            "https://example.com/2.jpg",
            "https://example.com/3.jpg",
            "https://example.com/4.jpg",
            "https://example.com/5.jpg"
        ])

        let urls = MainPageCarouselLogic.preloadCoverImageURLs(
            albums: albums,
            currentIndex: 2,
            preloadRange: 1
        )

        XCTAssertEqual(
            urls,
            [
                URL(string: "https://example.com/2.jpg")!,
                URL(string: "https://example.com/3.jpg")!,
                URL(string: "https://example.com/4.jpg")!
            ]
        )
    }

    // 같은 URL은 한 번만 preload 대상에 포함
    func test_preloadCoverImageURLs_deduplicatesDuplicateURLs() {
        let albums = makeAlbums(urls: [
            "https://example.com/a.jpg",
            "https://example.com/b.jpg",
            "https://example.com/b.jpg",
            "https://example.com/c.jpg"
        ])

        let urls = MainPageCarouselLogic.preloadCoverImageURLs(
            albums: albums,
            currentIndex: 1,
            preloadRange: 2
        )

        XCTAssertEqual(
            urls,
            [
                URL(string: "https://example.com/a.jpg")!,
                URL(string: "https://example.com/b.jpg")!,
                URL(string: "https://example.com/c.jpg")!
            ]
        )
    }

    // 왼쪽 스와이프 기준을 넘기면 다음 카드로 이동
    func test_nextIndex_swipeLeft_returnsNextIndex() {
        let nextIndex = MainPageCarouselLogic.nextIndex(
            currentIndex: 1,
            albumCount: 5,
            dragOffset: -150,
            velocity: -50,
            threshold: 100,
            swipeVelocityThreshold: 200
        )

        XCTAssertEqual(nextIndex, 2)
    }

    // 속도가 충분히 빠르면 dragOffset이 작아도 다음 카드로 이동
    func test_nextIndex_fastSwipeLeft_usesVelocityThreshold() {
        let nextIndex = MainPageCarouselLogic.nextIndex(
            currentIndex: 1,
            albumCount: 5,
            dragOffset: -40,
            velocity: -240,
            threshold: 100,
            swipeVelocityThreshold: 200
        )

        XCTAssertEqual(nextIndex, 2)
    }

    // 첫 카드에서는 오른쪽 스와이프해도 인덱스가 0 아래로 내려가지 않음
    func test_nextIndex_clampsAtFirstIndex() {
        let nextIndex = MainPageCarouselLogic.nextIndex(
            currentIndex: 0,
            albumCount: 5,
            dragOffset: 140,
            velocity: 50,
            threshold: 100,
            swipeVelocityThreshold: 200
        )

        XCTAssertEqual(nextIndex, 0)
    }

    // 마지막 카드에서는 왼쪽 스와이프해도 인덱스가 범위를 넘지 않음
    func test_nextIndex_clampsAtLastIndex() {
        let nextIndex = MainPageCarouselLogic.nextIndex(
            currentIndex: 4,
            albumCount: 5,
            dragOffset: -140,
            velocity: -50,
            threshold: 100,
            swipeVelocityThreshold: 200
        )

        XCTAssertEqual(nextIndex, 4)
    }

    // 스와이프 기준을 넘지 못하면 현재 카드 유지
    func test_nextIndex_belowThreshold_keepsCurrentIndex() {
        let nextIndex = MainPageCarouselLogic.nextIndex(
            currentIndex: 2,
            albumCount: 5,
            dragOffset: 40,
            velocity: 50,
            threshold: 100,
            swipeVelocityThreshold: 200
        )

        XCTAssertEqual(nextIndex, 2)
    }

    private func makeAlbums(urls: [String]) -> [AlbumCard] {
        urls.enumerated().map { index, rawURL in
            AlbumCard(
                id: index + 1,
                title: "앨범\(index + 1)",
                location: "서울",
                startDate: "2026-01-01",
                endDate: "2026-01-05",
                coverImageUrl: URL(string: rawURL)
            )
        }
    }
}
