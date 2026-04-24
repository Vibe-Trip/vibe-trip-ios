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
        static let titleToBodySpacing: CGFloat    = 8
        static let bodyToButtonMinSpacing: CGFloat = 36
        static let buttonHorizontalPadding: CGFloat = 101
        static let buttonVerticalPadding: CGFloat = 12
        static let buttonCornerRadius: CGFloat    = 8
        static let titleFontSize: CGFloat         = 22
        static let bodyFontSize: CGFloat          = 16
        static let minimumTypographyScale: CGFloat = 0.8
        static let buttonFontSize: CGFloat        = 14
        static let horizontalPadding: CGFloat     = 20
        static let bottomPadding: CGFloat         = 267
    }
    
    private enum Copy {
        static let title = "여행의 여운을 음악으로 담아내고 있어요."
        static let body = "사진 속 소중한 기억들이 멜로디로 변하고 있어요.\n잠시만 기다려 주세요!"
    }
    
    private func typographyScale(availableWidth: CGFloat) -> CGFloat {
        guard availableWidth > 0 else { return 1 }
        
        let uiFont = UIFont(
            name: "Pretendard-SemiBold",
            size: Layout.titleFontSize
        ) ?? UIFont.systemFont(
            ofSize: Layout.titleFontSize,
            weight: .semibold
        )
        
        let titleWidth = (Copy.title as NSString).size(withAttributes: [.font: uiFont]).width
        guard titleWidth > 0 else { return 1 }
        
        let fittedScale = availableWidth / titleWidth
        return min(1, max(Layout.minimumTypographyScale, fittedScale))
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            GeometryReader { proxy in
                let availableTextWidth = max(
                    0,
                    proxy.size.width - (Layout.horizontalPadding * 2)
                )
                let scale = typographyScale(availableWidth: availableTextWidth)
                
                VStack(spacing: 0) {
                    Spacer().frame(height: Layout.topPadding)
                    
                    // MOV 애니메이션
                    LoopingVideoView(name: "AlbumGenerate")
                        .frame(width: Layout.imageWidth, height: Layout.imageHeight)
                    
                    Spacer().frame(height: Layout.imageToTitleSpacing)
                    
                    // 타이틀
                    Text(Copy.title)
                        .font(
                            Font.setPretendard(
                                weight: .semiBold,
                                size: Layout.titleFontSize * scale
                            )
                        )
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .foregroundStyle(Color("GrayScale/500"))
                        .padding(.horizontal, Layout.horizontalPadding)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Spacer().frame(height: Layout.titleToBodySpacing)
                    
                    // 본문
                    Text(Copy.body)
                        .font(
                            Font.setPretendard(
                                weight: .medium,
                                size: Layout.bodyFontSize * scale
                            )
                        )
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color("GrayScale/400"))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Layout.horizontalPadding)
                    
                    Spacer().frame(height: Layout.bodyToButtonMinSpacing)
                    
                    // 화면 숨기기 버튼
                    Button {
                        onHide()
                    } label: {
                        Text("화면 숨기기")
                            .font(Font.setPretendard(weight: .semiBold, size: Layout.buttonFontSize))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color("GrayScale/50"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Layout.buttonVerticalPadding)
                            .background(isCreating ? Color("GrayScale/100") : Color.appPrimary)
                            .cornerRadius(Layout.buttonCornerRadius)
                    }
                    .padding(.horizontal, Layout.buttonHorizontalPadding)
                    .disabled(isCreating)
                    
                    Spacer().frame(height: Layout.bottomPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            }

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
