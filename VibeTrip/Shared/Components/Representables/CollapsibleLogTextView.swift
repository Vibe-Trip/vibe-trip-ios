//
//  CollapsibleLogTextView.swift
//  VibeTrip
//
//  Created by CHOI on 6/5/26.
//

import SwiftUI
import UIKit

// MARK: - LogTextTruncationAnalyzer


// 측정과 실제 렌더링을 같은 TextKit 엔진으로 통일하기 위한 함수
enum LogTextTruncationAnalyzer {

    struct Result: Equatable {
        let isTruncated: Bool   // 본문이 lineLimit 줄을 초과해 가려진 내용이 있는지
        let lastVisibleLineEndsWithNewline: Bool // 표시되는 마지막 줄이 하드 줄바꿈(`\n`)으로 끝나는지 (true면 말줄임 생략)

        static let none = Result(isTruncated: false, lastVisibleLineEndsWithNewline: false)
    }

    static func analyze(
        text: String,
        font: UIFont,
        width: CGFloat,
        reservedTailWidth: CGFloat, // 마지막 줄 우측에 비워둘 버튼 예약 폭
        lineLimit: Int              // 접힌 상태에서 보여줄 최대 줄 수
    ) -> Result {
        guard width > 0, lineLimit > 0, !text.isEmpty else { return .none }

        // 1. 전체 너비 기준으로 실제 줄 수가 limit을 넘는지 -> 버튼 표시 여부
        guard lineCount(text: text, font: font, width: width, exclusion: nil) > lineLimit else {
            return .none
        }

        // 2. 예약 영역을 반영한 레이아웃에서 마지막 표시 줄이 줄바꿈으로 끝나는지 판정
        let endsWithNewline = lastVisibleLineEndsWithNewline(
            text: text,
            font: font,
            width: width,
            reservedTailWidth: reservedTailWidth,
            lineLimit: lineLimit
        )
        return Result(isTruncated: true, lastVisibleLineEndsWithNewline: endsWithNewline)
    }

    // MARK: Layout helpers

    private static func makeLayoutManager(
        text: String,
        font: UIFont,
        width: CGFloat,
        exclusion: CGRect?
    ) -> (manager: NSLayoutManager, storage: NSTextStorage) {
        let storage = NSTextStorage(string: text, attributes: [.font: font])
        let container = NSTextContainer(
            size: CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        container.lineFragmentPadding = 0
        container.lineBreakMode = .byWordWrapping
        container.maximumNumberOfLines = 0
        if let exclusion {
            container.exclusionPaths = [UIBezierPath(rect: exclusion)]
        }

        let manager = NSLayoutManager()
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        return (manager, storage)
    }

    private static func lineCount(
        text: String,
        font: UIFont,
        width: CGFloat,
        exclusion: CGRect?
    ) -> Int {
        let (manager, _) = makeLayoutManager(text: text, font: font, width: width, exclusion: exclusion)
        var count = 0
        manager.enumerateLineFragments(
            forGlyphRange: NSRange(location: 0, length: manager.numberOfGlyphs)
        ) { _, _, _, _, _ in
            count += 1
        }
        return count
    }

    // lineLimit번째 줄의 문자 범위 마지막 글자가 개행인지 검사
    private static func lastVisibleLineEndsWithNewline(
        text: String,
        font: UIFont,
        width: CGFloat,
        reservedTailWidth: CGFloat,
        lineLimit: Int
    ) -> Bool {
        let lineHeight = font.lineHeight
        let exclusion: CGRect? = reservedTailWidth > 0
            ? CGRect(
                x: max(0, width - reservedTailWidth),
                y: lineHeight * CGFloat(lineLimit - 1),
                width: reservedTailWidth,
                height: lineHeight
            )
            : nil

        let (manager, storage) = makeLayoutManager(
            text: text, font: font, width: width, exclusion: exclusion
        )

        var currentLine = 0
        var targetGlyphRange: NSRange?
        manager.enumerateLineFragments(
            forGlyphRange: NSRange(location: 0, length: manager.numberOfGlyphs)
        ) { _, _, _, glyphRange, stop in
            currentLine += 1
            if currentLine == lineLimit {
                targetGlyphRange = glyphRange
                stop.pointee = true
            }
        }

        guard let targetGlyphRange else { return false }
        let charRange = manager.characterRange(forGlyphRange: targetGlyphRange, actualGlyphRange: nil)
        guard charRange.length > 0 else { return false }

        let lastIndex = charRange.location + charRange.length - 1
        let lastChar = (storage.string as NSString).substring(with: NSRange(location: lastIndex, length: 1))
        return lastChar == "\n"
    }
}

// MARK: - CollapsibleLogTextView

// 읽기 전용 본문을 지정한 줄 수로 접어 보여주는 컴포넌트
struct CollapsibleLogTextView: UIViewRepresentable {

    // MARK: Inputs

    let text: String
    let font: UIFont
    let textColor: UIColor
    let lineLimit: Int
    let reservedTailWidth: CGFloat // 마지막 줄 우측에 비워둘 버튼 예약 폭 (0이면 예약/절단 없음)
    let showsEllipsis: Bool        // 예약 영역에 닿아 잘릴 때 말줄임(…)을 붙일지

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        // 탭은 SwiftUI 측 제스처가 처리하도록 UIKit 상호작용 차단
        textView.isUserInteractionEnabled = false
        textView.contentInsetAdjustmentBehavior = .never
        textView.contentInset = .zero
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = false
        textView.backgroundColor = .clear
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // 기본 속성만 갱신 -> 너비 의존적인 예약/줄바꿈 설정은 sizeThatFits에서 처리
        if uiView.text != text { uiView.text = text }
        uiView.font = font
        uiView.textColor = textColor
        uiView.textContainer.maximumNumberOfLines = lineLimit
    }

    // 최종 너비를 알 수 있는 시점에 예약 영역/줄바꿈 모드를 확정하고 높이를 계산
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        configure(uiView, width: width)
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitting.height)
    }

    // MARK: - Helpers

    private func configure(_ textView: UITextView, width: CGFloat) {
        if textView.text != text { textView.text = text }
        textView.font = font
        textView.textColor = textColor
        textView.textContainer.maximumNumberOfLines = lineLimit

        guard reservedTailWidth > 0 else {
            textView.textContainer.exclusionPaths = []
            textView.textContainer.lineBreakMode = .byWordWrapping
            return
        }

        let lineHeight = font.lineHeight
        let reservedRect = CGRect(
            x: max(0, width - reservedTailWidth),
            y: lineHeight * CGFloat(lineLimit - 1),
            width: reservedTailWidth,
            height: lineHeight
        )
        textView.textContainer.exclusionPaths = [UIBezierPath(rect: reservedRect)]
        // 예약 영역에 닿아 잘릴 때만 말줄임, 줄바꿈으로 끝난 경우는 그냥 클립
        textView.textContainer.lineBreakMode = showsEllipsis ? .byTruncatingTail : .byWordWrapping
    }
}

// MARK: - Preview

#Preview("절단 케이스 모음") {
    let font = UIFont(name: "Pretendard-Regular", size: 16) ?? .systemFont(ofSize: 16)
    let reserved: CGFloat = 56

    func row(_ title: String, _ text: String) -> some View {
        let result = LogTextTruncationAnalyzer.analyze(
            text: text, font: font, width: UIScreen.main.bounds.width - 40,
            reservedTailWidth: reserved, lineLimit: 2
        )
        return VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            CollapsibleLogTextView(
                text: text,
                font: font,
                textColor: .label,
                lineLimit: 2,
                reservedTailWidth: result.isTruncated ? reserved : 0,
                showsEllipsis: result.isTruncated && !result.lastVisibleLineEndsWithNewline
            )
            .background(Color(.systemGray6))
            Text("truncated=\(String(result.isTruncated)) newlineEnd=\(String(result.lastVisibleLineEndsWithNewline))")
                .font(.caption2).foregroundStyle(.blue)
        }
    }

    return VStack(alignment: .leading, spacing: 20) {
        row("① 짧은 글 (버튼 없음)", "오늘 날씨가 정말 좋았다.")
        row("② 자연 줄바꿈 2줄 꽉 + 초과", String(repeating: "아", count: 80))
        row("③ 엔터로 중간 종료 + 가려진 줄", "오전 11:40\n오전 11:40\n숨겨진 셋째 줄 내용입니다")
        row("④ 최대 길이 경계", String(repeating: "가나다라 ", count: 12))
    }
    .padding(20)
}
