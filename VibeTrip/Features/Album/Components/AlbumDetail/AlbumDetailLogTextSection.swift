//
//  AlbumDetailLogTextSection.swift
//  VibeTrip
//
//  Created by CHOI on 6/24/26.
//

import SwiftUI
import UIKit

// MARK: - AlbumDetailLogTextSection
// 텍스트 + 더보기/접기

struct AlbumDetailLogTextSection: View {
    let text: String
    /// 더보기로 펼쳐질 때 호출 
    var onExpand: (() -> Void)? = nil

    @State private var isExpanded: Bool = false
    /// GeometryReader로 측정한 실제 콘텐츠 너비
    @State private var contentWidth: CGFloat = 0
    
    private enum Constants {
        static let fontName: String = "Pretendard-Regular"
        static let fontSize: CGFloat = 16
        static let lineLimit: Int = 2
        static let moreButtonText: String = "더 보기"
        static let foldButtonText: String = "접기"
        static let foldSpacer: String = "  "    /// 접기 버튼과 본문 텍스트 사이 공간 예약용
        static let reservedGap: CGFloat = 8         // "더 보기"/"접기" 버튼과 본문 사이 간격
        static let buttonTrailingInset: CGFloat = 8 // 버튼과 우측 끝 사이 간격
        static let animationDuration: CGFloat = 0.2
    }

    // 접힌 본문(UITextView)과 동일하게 Dynamic Type 비스케일 고정 크기 사용
    private var textFont: Font { .custom(Constants.fontName, fixedSize: Constants.fontSize) }
    private let actionColor = Color("GrayScale/400")

    private var uiFont: UIFont {
        UIFont(name: Constants.fontName, size: Constants.fontSize)
        ?? UIFont.systemFont(ofSize: Constants.fontSize)
    }
    
    private var textUIColor: UIColor { UIColor(named: "text") ?? .label }

    // "더 보기" 버튼 폭 + 간격 = 마지막 줄 우측에 비워둘 예약 폭
    private var reservedTextWidth: CGFloat {
        (Constants.moreButtonText as NSString)
            .size(withAttributes: [.font: uiFont]).width
    }
    // 마지막 줄 우측 공간
    private var reservedTailWidth: CGFloat {
        reservedTextWidth + Constants.reservedGap + Constants.buttonTrailingInset
    }
    
    var body: some View {
        let truncation = LogTextTruncationAnalyzer.analyze(
            text: text,
            font: uiFont,
            width: contentWidth,
            reservedTailWidth: reservedTailWidth,
            lineLimit: Constants.lineLimit
        )

        Group {
            if isExpanded {
                expandedContent
            } else {
                collapsedContent(truncation: truncation)
            }
        }
        // 콘텐츠 너비 측정
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { w in
            if abs(contentWidth - w) > 0.5 {
                DispatchQueue.main.async { contentWidth = w }
            }
        }
    }
    
    // 펼친 상태: 접힘과 같은 UITextView 엔진으로 전체 표시 (편집 페이지와 줄바꿈 일치)
    // 마지막 줄 끝에 투명 "접기" 예약 텍스트로 공간을 비우고 그 위에 접기 버튼 배치
    private var expandedContent: some View {
        ZStack(alignment: .bottomTrailing) {
            CollapsibleLogTextView(
                text: text,
                font: uiFont,
                textColor: textUIColor,
                lineLimit: 0,
                reservedTailWidth: 0,
                showsEllipsis: false,
                trailingReserveText: Constants.foldSpacer + Constants.foldButtonText
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(Constants.foldButtonText) {
                withAnimation(.easeInOut(duration: Constants.animationDuration)) { isExpanded = false }
            }
            .font(textFont)
            .foregroundStyle(actionColor)
            .buttonStyle(.plain)
            .padding(.trailing, Constants.buttonTrailingInset)
        }
    }
    
    private func expand() {
        withAnimation(.easeInOut(duration: Constants.animationDuration)) { isExpanded = true }
        onExpand?()
    }

    // 접힌 상태: 2줄로 접고, 잘릴 때만 우측에 "더 보기" 버튼 표시
    private func collapsedContent(truncation: LogTextTruncationAnalyzer.Result) -> some View {
        ZStack(alignment: .bottomTrailing) {
            CollapsibleLogTextView(
                text: text,
                font: uiFont,
                textColor: textUIColor,
                lineLimit: Constants.lineLimit,
                reservedTailWidth: truncation.isTruncated ? reservedTailWidth : 0,
                showsEllipsis: truncation.isTruncated && !truncation.lastVisibleLineEndsWithNewline
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                guard truncation.isTruncated else { return }
                expand()
            }

            if truncation.isTruncated {
                Button(Constants.moreButtonText) {
                    expand()
                }
                .font(textFont)
                .foregroundStyle(actionColor)
                .buttonStyle(.plain)
                .frame(width: reservedTextWidth, alignment: .trailing)
                .padding(.trailing, Constants.buttonTrailingInset)
            }
        }
    }
}

