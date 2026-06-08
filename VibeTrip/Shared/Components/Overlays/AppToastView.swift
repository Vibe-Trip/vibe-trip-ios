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
    var systemImageName: String? = "exclamationmark.circle"

    var body: some View {
        Group {
            if let systemImageName {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: systemImageName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(message)
                        .font(Font.setPretendard(weight: .medium, size: 16))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(message)
                        .font(Font.custom("Pretendard", size: 16).weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.white)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .background(Color("GrayScale/500"))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
}

#Preview {
    ZStack {
        Color.white
        VStack {
            Spacer()
            AppToastView(message: "사진은 최대 5장까지 고를 수 있어요.")
            AppToastView(message: "로그아웃이 완료되었습니다", systemImageName: nil)
                .padding(.bottom, 40)
        }
    }
}
