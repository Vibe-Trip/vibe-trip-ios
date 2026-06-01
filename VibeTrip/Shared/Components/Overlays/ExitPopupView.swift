//
//  ExitPopupView.swift
//  VibeTrip
//
//  Created by CHOI on 3/24/26.
//

import SwiftUI

// 커스텀 팝업
// title 및 message 주입형
// 타입: 두 버튼 / 두 버튼 + 체크박스 / 단일 버튼
struct ExitPopupView: View {

    // 제목
    let title: String

    // 내용 (빈 문자열이면 미표시)
    var message: String = ""

    // 취소 탭 핸들러
    let onCancel: () -> Void

    // 확인 탭 핸들러
    let onConfirm: () -> Void

    // 화면별로 바꿔 쓸 수 있는 확인 버튼 문구
    var confirmTitle: String = "확인"

    // nil: 취소 버튼 미표시 -> 단일 버튼 구조
    var cancelTitle: String? = "취소"

    // non-nil: 다시 보지 않기 체크박스 행 표시 -> 두 버튼 + 체크박스 구조
    var doNotShowAgain: Binding<Bool>? = nil

    var body: some View {
        ZStack {
            // 팝업 뒷배경 처리
            Color.dimmedOverlay
                .ignoresSafeArea()

            VStack(alignment: .center, spacing: 20) {
                // 타이틀 (+ message가 있을 때만 본문 표시)
                VStack(alignment: .center, spacing: 8) {
                    Text(title)
                        .font(Font.setPretendard(weight: .bold, size: 20))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.text)
                        .frame(maxWidth: .infinity, alignment: .top)

                    if !message.isEmpty {
                        Text(message)
                            .font(Font.setPretendard(weight: .regular, size: 14))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.text)
                    }
                }

                // 라디오 버튼: doNotShowAgain 바인딩이 있을 때만 표시
                if let binding = doNotShowAgain {
                    HStack(spacing: 4) {
                        Button {
                            binding.wrappedValue.toggle()
                        } label: {
                            ZStack {
                                Circle()
                                    .stroke(
                                        binding.wrappedValue ? Color.appPrimary : Color("GrayScale/300"),
                                        lineWidth: 1
                                    )
                                    .frame(width: 16, height: 16)
                                if binding.wrappedValue {
                                    Circle()
                                        .fill(Color.appPrimary)
                                        .frame(width: 8, height: 8)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Text("다시 보지 않기")
                            .font(Font.setPretendard(weight: .regular, size: 14))
                            .foregroundStyle(Color("GrayScale/300"))
                    }
                }

                // 버튼 행: cancelTitle nil -> 확인 버튼만 전체 너비로 표시
                HStack(spacing: 8) {
                    if let cancelText = cancelTitle {
                        popupButton(title: cancelText, isCancelStyle: true, action: onCancel)
                    }
                    popupButton(title: confirmTitle, isCancelStyle: false, action: onConfirm)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: 362, alignment: .top)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.fieldBorder, lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }

    // 버튼 색상 분기
    private func popupButton(
        title: String,
        isCancelStyle: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(Font.setPretendard(weight: .semiBold, size: 16))
                .multilineTextAlignment(.center)
                .foregroundStyle(isCancelStyle ? Color("GrayScale/400") : Color.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48, maxHeight: 48)
                .background(isCancelStyle ? Color("GrayScale/100") : Color.appPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .inset(by: 0.5)
                        .stroke(
                            isCancelStyle ? Color.fieldBorder : Color.dialogConfirmBorder,
                            lineWidth: 1
                        )
                )
                .appShadow(.buttonTextField)
        }
        .buttonStyle(.plain)
    }
}

#Preview("두 버튼") {
    ExitPopupView(
        title: "로그 작성을 멈출까요?",
        message: "페이지를 벗어나면 작성 중인 내용이\n저장되지 않고 사라지게 돼요.",
        onCancel: {},
        onConfirm: {}
    )
}

#Preview("두 버튼 + 체크박스") {
    struct PreviewWrapper: View {
        @State private var doNotShow = false
        var body: some View {
            ExitPopupView(
                title: "AI 음악을 만들까요?",
                message: "사진을 분석해 어울리는 노래를 만듭니다.\n데이터는 보안이 강화된 AI 엔진을 통해 분석되며\n음악 생성에만 활용됩니다.",
                onCancel: {},
                onConfirm: {},
                doNotShowAgain: $doNotShow
            )
        }
    }
    return PreviewWrapper()
}

#Preview("단일 버튼") {
    ExitPopupView(
        title: "음악 생성 실패",
        message: "음악 생성 중 오류가 발생했어요.\n잠시 후 다시 시도해 주세요.",
        onCancel: {},
        onConfirm: {},
        cancelTitle: nil
    )
}
