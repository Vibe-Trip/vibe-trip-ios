//
//  AppToastView.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI

// 공통 하단 토스트 컴포넌트
struct AppToastView: View {

    let message: String
    var systemImageName: String = "exclamationmark.circle.fill"

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImageName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(Font.setPretendard(weight: .medium, size: 16))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.toastBackground)
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
}

#Preview {
    ZStack {
        Color.white
        VStack {
            Spacer()
            AppToastView(message: "필수 입력 항목을 모두 입력해 주세요.")
                .padding(.bottom, 40)
        }
    }
}
