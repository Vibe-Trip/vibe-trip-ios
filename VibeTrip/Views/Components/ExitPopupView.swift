//
//  ExitPopupView.swift
//  VibeTrip
//
//  Created by CHOI on 3/24/26.
//

import SwiftUI

// 커스텀 팝업
// title 및 message 주입형
struct ExitPopupView: View {

    // 제목
    let title: String

    // 내용
    let message: String

    // 취소 탭 핸들러
    let onCancel: () -> Void

    // 확인 탭 핸들러
    let onConfirm: () -> Void

    // 화면별로 바꿔 쓸 수 있는 확인 버튼 문구
    var confirmTitle: String = "확인"

    var body: some View {
        ZStack {
            // 팝업 뒷배경 처리
            Color.dimmedOverlay
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text(title)
                    .font(Font.setPretendard(weight: .bold, size: 20))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .top)

                Text(message)
                    .font(Font.setPretendard(weight: .regular, size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.top, 8)

                HStack(spacing: 10) {
                    popupButton(
                        title: "취소",
                        foregroundColor: Color.textPrimary,
                        backgroundColor: .white,
                        borderColor: Color.fieldBorder,
                        action: onCancel
                    )

                    popupButton(
                        title: confirmTitle,
                        foregroundColor: .white,
                        backgroundColor: Color.appPrimary,
                        borderColor: Color.dialogConfirmBorder,
                        action: onConfirm
                    )
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 136, alignment: .top)
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
        foregroundColor: Color,
        backgroundColor: Color,
        borderColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(Font.setPretendard(weight: .semiBold, size: 18))
                .foregroundStyle(foregroundColor)
                .frame(width: 160, height: 48)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 1.5, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ExitPopupView(
        title: "기록을 멈출까요?",
        message: "페이지를 벗어나면 작성 중인 내용이\n저장되지 않고 사라지게 돼요.",
        onCancel: {},
        onConfirm: {}
    )
}
