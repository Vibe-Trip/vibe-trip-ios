//
//  MainPageView.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI

// MARK: - MainPageView

struct MainPageView: View {

    var body: some View {
        VStack(spacing: 0) {

            Spacer()

            // MARK: 빈 상태 콘텐츠
            emptyStateView

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - emptyStateView

    private var emptyStateView: some View {
        VStack(alignment: .center, spacing: 8) {

            // 빈 상태 아이콘
            Image(systemName: "rectangle.stack.fill.badge.plus")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .offset(x: -8)
                .foregroundStyle(Color.placeholderSymbol)


            // 메인 텍스트
            Text("첫 번째 여행 앨범을 만들어보세요.")
                .font(Font.setPretendard(weight: .semiBold, size: 22))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.placeholderText)
                .padding(.horizontal, 39)
                .frame(maxWidth: .infinity, alignment: .center)

            // 서브 텍스트
            Text("지금 바로 아래 '앨범 만들기'를 눌러 시작 해보세요!")
                .font(Font.setPretendard(weight: .medium, size: 16))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.placeholderText)
                .padding(.horizontal, 39)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    MainPageView()
}
