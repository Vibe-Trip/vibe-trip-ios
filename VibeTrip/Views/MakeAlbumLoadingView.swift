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

    // API 요청 진행 중 여부: true -> 화면 숨기기 버튼 비활성화
    let isCreating: Bool

    // 에러 상태: non-nil -> 해당 팝업 표시
    let loadingError: MakeAlbumViewModel.AlbumCreationLoadingError?

    // 다시시도 시,호출
    let onRetry: () -> Void

    // 팝업: 나중에 하기 or 확인 탭 -> 메인 페이지로 이동
    let onDismissToMain: () -> Void

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
                Button {
                    onHide()
                } label: {
                    Text("화면 숨기기")
                        .font(Font.setPretendard(weight: .semiBold, size: Layout.buttonFontSize))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.GrayScale._50)
                        .frame(width: Layout.buttonWidth)
                        .padding(.vertical, Layout.buttonVerticalPadding)
                }
                .background(isCreating ? Color("GrayScale/100") : Color.appPrimary)
                .cornerRadius(Layout.buttonCornerRadius)
                .disabled(isCreating)

                Spacer().frame(height: Layout.bottomPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            // 에러 팝업
            if let error = loadingError {
                switch error {
                case .networkError:
                    // 네트워크 오류: 재시도 가능
                    ExitPopupView(
                        title: "네트워크 오류",
                        message: "연결 상태가 원활하지 않아 음악 생성이 중단 되었습니다.\n연결 확인 후 음악 생성을 다시 시도해 주세요.",
                        onCancel: onDismissToMain,
                        onConfirm: onRetry,
                        confirmTitle: "다시 시도",
                        cancelTitle: "나중에 하기"
                    )
                case .fatalError:
                    // 생성 실패: 재시도 불가
                    ExitPopupView(
                        title: "음악을 만들지 못했어요",
                        message: "음악 생성 중 오류가 발생했습니다.\n잠시 후 다시 시도해 주세요.",
                        onCancel: {},
                        onConfirm: onDismissToMain,
                        confirmTitle: "확인",
                        cancelTitle: nil
                    )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("기본") {
    MakeAlbumLoadingView(
        onHide: {},
        isCreating: false,
        loadingError: nil,
        onRetry: {},
        onDismissToMain: {}
    )
}

#Preview("요청 진행 중") {
    MakeAlbumLoadingView(
        onHide: {},
        isCreating: true,
        loadingError: nil,
        onRetry: {},
        onDismissToMain: {}
    )
}

#Preview("네트워크 오류 팝업") {
    MakeAlbumLoadingView(
        onHide: {},
        isCreating: false,
        loadingError: .networkError,
        onRetry: {},
        onDismissToMain: {}
    )
}

#Preview("생성 실패 팝업") {
    MakeAlbumLoadingView(
        onHide: {},
        isCreating: false,
        loadingError: .fatalError,
        onRetry: {},
        onDismissToMain: {}
    )
}
