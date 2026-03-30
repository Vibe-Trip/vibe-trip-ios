//
//  MakeAlbumLoadingView.swift
//  VibeTrip
//
//  Created by CHOI on 3/24/26.
//

import SwiftUI

// MARK: - MakeAlbumLoadingView

struct MakeAlbumLoadingView: View {

    // 화면 숨기기 탭 시, 알림 탭으로 복귀
    let onHide: () -> Void

    private enum Layout {
        static let topPadding: CGFloat            = 219
        static let imageWidth: CGFloat            = 260
        static let imageHeight: CGFloat           = 195
        static let imageToTitleSpacing: CGFloat   = 12
        static let titleToBodySpacing: CGFloat    = 12
        static let bodyToButtonMinSpacing: CGFloat = 53
        static let buttonWidth: CGFloat           = 240
        static let buttonVerticalPadding: CGFloat = 12
        static let buttonCornerRadius: CGFloat    = 12
        static let titleFontSize: CGFloat         = 22
        static let bodyFontSize: CGFloat          = 16
        static let buttonFontSize: CGFloat        = 16
        static let horizontalPadding: CGFloat     = 20
        static let bottomPadding: CGFloat         = 267
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: Layout.topPadding)

                // MOV 애니메이션
                LoopingVideoView(name: "AlbumGenerate")
                    .frame(width: Layout.imageWidth, height: Layout.imageHeight)

                Spacer().frame(height: Layout.imageToTitleSpacing)

                // 타이틀
                Text("여행의 여운을 음악으로 담아내고 있어요.")
                    .font(Font.setPretendard(weight: .semiBold, size: Layout.titleFontSize))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Layout.horizontalPadding)

                Spacer().frame(height: Layout.titleToBodySpacing)

                // 본문
                Text("사진 속 소중한 기억들이 멜로디로 변하고 있어요.\n잠시만 기다려 주세요!")
                    .font(Font.setPretendard(weight: .medium, size: Layout.bodyFontSize))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.placeholderText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Layout.horizontalPadding)

                Spacer(minLength: Layout.bodyToButtonMinSpacing)

                // 화면 숨기기 버튼
                Button(action: onHide) {
                    Text("화면 숨기기")
                        .font(Font.setPretendard(weight: .semiBold, size: Layout.buttonFontSize))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.GrayScale._50)
                        .frame(width: Layout.buttonWidth)
                        .padding(.vertical, Layout.buttonVerticalPadding)
                }
                .background(Color.appPrimary)
                .cornerRadius(Layout.buttonCornerRadius)

                Spacer().frame(height: Layout.bottomPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
    }
}

// MARK: - Preview

#Preview {
    MakeAlbumLoadingView(onHide: {})
}
