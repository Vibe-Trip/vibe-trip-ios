//
//  GrowingTextEditor.swift
//  VibeTrip
//
//  Created by CHOI on 5/26/26.
//

import SwiftUI
import UIKit

struct GrowingTextEditor: UIViewRepresentable {

    // MARK: - Bindings

    @Binding var text: String
    @Binding var isFocused: Bool

    // MARK: - Style

    let font: UIFont
    let lineSpacing: CGFloat
    let textColor: UIColor
    let textContainerInset: UIEdgeInsets

    // MARK: - Constraints

    // 입력 가능한 최대 글자 수
    let maxLength: Int?

    // MARK: - Init

    init(
        text: Binding<String>,
        isFocused: Binding<Bool>,
        font: UIFont = UIFont(name: "Pretendard-Regular", size: 16) ?? .systemFont(ofSize: 16),
        lineSpacing: CGFloat = 8,
        textColor: UIColor = .label,
        textContainerInset: UIEdgeInsets = .zero,
        maxLength: Int? = nil
    ) {
        _text = text
        _isFocused = isFocused
        self.font = font
        self.lineSpacing = lineSpacing
        self.textColor = textColor
        self.textContainerInset = textContainerInset
        self.maxLength = maxLength
    }

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        // intrinsicContentSize -> 텍스트 양에 따라 늘어남
        textView.isScrollEnabled = false
        // UITextView는 UIScrollView 서브클래스라 부모 safe area를 contentInset으로 자동 반영 -> 빈 상태에서 캐럿 시작 위치가 아래로 밀리는 원인이라 명시적으로 차단
        textView.contentInsetAdjustmentBehavior = .never
        textView.contentInset = .zero
        textView.backgroundColor = .clear
        textView.textContainerInset = textContainerInset
        // 좌우 기본 inset 제거 -> 외부 SwiftUI padding으로 시각 위치 일원화
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = false
        textView.font = font
        textView.textColor = textColor
        // 외곽 ScrollView 안에서 높이 압축 방지
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        // 새로 타이핑되는 글자도 동일 줄간격 유지
        textView.typingAttributes = Self.makeAttributes(font: font, lineSpacing: lineSpacing, textColor: textColor)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // 외부 text가 내부와 다를 때만 갱신 -> 한글 조합 중 IME 깨짐/커서 점프 방지
        if uiView.text != text {
            uiView.attributedText = NSAttributedString(
                string: text,
                attributes: Self.makeAttributes(font: font, lineSpacing: lineSpacing, textColor: textColor)
            )
            // attributedText 설정 후에도 새 입력에 줄간격이 유지되도록 재설정
            uiView.typingAttributes = Self.makeAttributes(font: font, lineSpacing: lineSpacing, textColor: textColor)
        }

        // 포커스 동기화: 외부 isFocused 변경을 first responder 상태에 반영
        // 업데이트 사이클과 충돌 방지를 위해 async로 호출
        if isFocused && !uiView.isFirstResponder {
            DispatchQueue.main.async { uiView.becomeFirstResponder() }
        } else if !isFocused && uiView.isFirstResponder {
            DispatchQueue.main.async { uiView.resignFirstResponder() }
        }
    }

    // 화면 너비에 맞춰 자동 줄바꿈 동작 보장
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitting.height)
    }

    // MARK: - Helpers

    // 폰트/줄간격/색상을 묶은 공통 속성 생성
    private static func makeAttributes(font: UIFont, lineSpacing: CGFloat, textColor: UIColor) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        return [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ]
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {

        private var parent: GrowingTextEditor

        init(_ parent: GrowingTextEditor) {
            self.parent = parent
        }

        // 입력 전 단계에서 maxLength 초과 분량은 차단
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if textView.markedTextRange != nil { return true }
            guard let maxLength = parent.maxLength else { return true }
            let current = textView.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return true }
            let after = current.replacingCharacters(in: swiftRange, with: text)
            return after.count <= maxLength
        }

        // 사용자 입력 -> 외부 text 바인딩 갱신
        // 조합 종료 시점에 maxLength 초과 상태면 prefix 로 잘라 정합화
        func textViewDidChange(_ textView: UITextView) {
            if let maxLength = parent.maxLength,
               textView.markedTextRange == nil,
               (textView.text?.count ?? 0) > maxLength {
                textView.text = String((textView.text ?? "").prefix(maxLength))
            }
            parent.text = textView.text
        }

        // first responder 진입/해제 -> 외부 isFocused 바인딩 갱신
        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
        }
    }
}

// MARK: - Preview

#Preview("빈 상태 & 자유 입력") {
    struct PreviewWrapper: View {
        @State private var text: String = ""
        @State private var isFocused: Bool = false

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("focus: \(isFocused ? "true" : "false")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    GrowingTextEditor(text: $text, isFocused: $isFocused)
                        .padding(20)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button(isFocused ? "키보드 내리기" : "키보드 올리기") {
                        isFocused.toggle()
                    }
                }
                .padding(20)
            }
        }
    }
    return PreviewWrapper()
}

#Preview("긴 텍스트 - 외곽 스크롤 동작") {
    struct PreviewWrapper: View {
        @State private var text: String = String(repeating: "동적 높이 텍스트뷰 동작 확인 줄입니다.\n", count: 30)
        @State private var isFocused: Bool = false

        var body: some View {
            ScrollView {
                GrowingTextEditor(text: $text, isFocused: $isFocused)
                    .padding(20)
            }
        }
    }
    return PreviewWrapper()
}
