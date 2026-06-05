//
//  LogTextTruncationAnalyzerTests.swift
//  VibeTripTests
//
//  Created by CHOI on 6/5/26.
//

import XCTest
import UIKit
@testable import VibeTrip

final class LogTextTruncationAnalyzerTests: XCTestCase {

    private let font = UIFont.systemFont(ofSize: 16)
    private let width: CGFloat = 335
    private let reserved: CGFloat = 56
    private let lineLimit = 2

    private func analyze(_ text: String) -> LogTextTruncationAnalyzer.Result {
        LogTextTruncationAnalyzer.analyze(
            text: text, font: font, width: width,
            reservedTailWidth: reserved, lineLimit: lineLimit
        )
    }

    // 짧은 글: 잘림 없음 -> 버튼 없음
    func test_shortText_notTruncated() {
        let r = analyze("오늘 날씨 좋다")
        XCTAssertFalse(r.isTruncated)
    }

    // 자연 줄바꿈으로 3줄 이상: 잘림 + 마지막 줄은 줄바꿈으로 끝나지 않음(말줄임 표시)
    func test_longWrappedText_truncated_noNewlineEnd() {
        let r = analyze(String(repeating: "가나다라마바사 ", count: 12))
        XCTAssertTrue(r.isTruncated)
        XCTAssertFalse(r.lastVisibleLineEndsWithNewline)
    }

    // 엔터로 줄2 중간 종료 + 가려진 줄3: 잘림 + 마지막 줄이 줄바꿈으로 끝남(말줄임 생략)
    func test_newlineBrokenText_truncated_newlineEnd() {
        let r = analyze("첫째 줄\n둘째 줄\n셋째 줄은 가려진다")
        XCTAssertTrue(r.isTruncated)
        XCTAssertTrue(r.lastVisibleLineEndsWithNewline)
    }
}
