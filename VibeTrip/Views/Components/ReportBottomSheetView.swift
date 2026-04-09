//
//  ReportBottomSheetView.swift
//  VibeTrip
//

import SwiftUI

// MARK: - ReportReason

enum ReportReason: String, CaseIterable {
    case inappropriateLyrics = "부적절하거나 불쾌한 가사"
    case copyrightViolation  = "저작권 침해 의심"
    case etc                 = "기타"
}

// MARK: - ReportBottomSheetView

struct ReportBottomSheetView: View {

    @Binding var isPresented: Bool

    // 신고 이유 선택 후 "신고하기" 탭 시 호출
    let onConfirm: (ReportReason) -> Void

    @State private var selectedReason: ReportReason = .inappropriateLyrics

    private enum Layout {
        static let horizontalPadding: CGFloat  = 20
        static let topPadding: CGFloat         = 21
        static let titleBodySpacing: CGFloat   = 13
        static let bodyOptionsSpacing: CGFloat = 20
        static let optionSpacing: CGFloat      = 12
        static let radioSize: CGFloat          = 16
        static let radioDotSize: CGFloat       = 8
        static let radioStrokeWidth: CGFloat   = 1.5
        static let closeButtonSize: CGFloat    = 15
        static let buttonVerticalPadding: CGFloat = 12
        static let buttonCornerRadius: CGFloat = 12
        static let bottomPadding: CGFloat      = 8
        static let titleFontSize: CGFloat      = 20
        static let bodyFontSize: CGFloat       = 14
        static let optionFontSize: CGFloat     = 14
        static let buttonFontSize: CGFloat     = 16
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // 타이틀 + X 버튼
            HStack(alignment: .center) {
                Text("신고 사유를 선택해주세요")
                    .font(Font.setPretendard(weight: .bold, size: Layout.titleFontSize))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: Layout.closeButtonSize, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: Layout.closeButtonSize, height: Layout.closeButtonSize)
                }
            }
            .padding(.top, Layout.topPadding)

            Spacer().frame(height: Layout.titleBodySpacing)

            // 보조 타이틀
            Text("신고하신 내용은 리트립 팀에서 신속하고 꼼꼼하게 검토하여\n안전한 서비스 환경을 만드는 데 반영하겠습니다.")
                .font(Font.setPretendard(weight: .regular, size: Layout.bodyFontSize))
                .foregroundStyle(Color.black)
                .lineSpacing(4)

            Spacer().frame(height: Layout.bodyOptionsSpacing)

            // 라디오 버튼 목록
            VStack(alignment: .leading, spacing: Layout.optionSpacing) {
                ForEach(ReportReason.allCases, id: \.self) { reason in
                    radioButton(for: reason)
                }
            }

            Spacer()

            // 신고하기 버튼
            Button {
                onConfirm(selectedReason)
            } label: {
                Text("신고하기")
                    .font(Font.setPretendard(weight: .semiBold, size: Layout.buttonFontSize))
                    .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.98))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Layout.buttonVerticalPadding)
            }
            .background(Color.appPrimary)
            .cornerRadius(Layout.buttonCornerRadius)
            .padding(.bottom, Layout.bottomPadding)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .background(Color.white)
    }

    // MARK: - 라디오 버튼 항목

    @ViewBuilder
    private func radioButton(for reason: ReportReason) -> some View {
        let isSelected = selectedReason == reason

        HStack(spacing: 8) {
            // 라디오 서클
            ZStack {
                Circle()
                    .stroke(
                        isSelected ? Color.appPrimary : Color("GrayScale/300"),
                        lineWidth: 1
                    )
                    .frame(width: Layout.radioSize, height: Layout.radioSize)
                if isSelected {
                    Circle()
                        .fill(Color.appPrimary)
                        .frame(width: Layout.radioDotSize, height: Layout.radioDotSize)
                }
            }

            Text(reason.rawValue)
                .font(Font.setPretendard(weight: .regular, size: Layout.optionFontSize))
                .foregroundStyle(Color.black)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedReason = reason
        }
    }
}

// MARK: - Preview

#Preview("기본") {
    ReportBottomSheetView(isPresented: .constant(true), onConfirm: { _ in })
        .presentationDetents([.height(320)])
}

#Preview("선택됨") {
    struct PreviewWrapper: View {
        @State var isPresented = true
        var body: some View {
            Text("")
                .sheet(isPresented: $isPresented) {
                    ReportBottomSheetView(isPresented: $isPresented, onConfirm: { _ in })
                        .presentationDetents([.height(320)])
                        .presentationDragIndicator(.hidden)
                }
        }
    }
    return PreviewWrapper()
}
