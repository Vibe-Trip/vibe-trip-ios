//
//  AlbumDetailView.swift
//  VibeTrip
//
//  Created by CHOI on 3/26/26.
//

import SwiftUI
import UIKit

// MARK: - AlbumDetailView
// contentState에 따라 스크롤 활성화 여부 분기

struct AlbumDetailView: View {

    private let displayModel: AlbumDetailDisplayModel
    private let onBackTap: () -> Void
    private let onMusicButtonTap: () -> Void
    private let onWriteLogTap: () -> Void
    private let onDownloadMusicTap: () -> Void
    private let onEditAlbumTap: () -> Void
    private let onDeleteAlbumTap: () -> Void
    private let onReportTap: () -> Void

    // 앨범 옵션 팝업 표시 여부
    @State private var isAlbumMenuVisible: Bool = false

    // 재생/일시정지 토글 상태
    // TODO: AVPlayer 연결
    @State private var isMusicPlaying: Bool

    // MARK: - Init

    init(
        displayModel: AlbumDetailDisplayModel,
        onBackTap: @escaping () -> Void = {},
        onMusicButtonTap: @escaping () -> Void = {},
        onWriteLogTap: @escaping () -> Void = {},
        onDownloadMusicTap: @escaping () -> Void = {},
        onEditAlbumTap: @escaping () -> Void = {},
        onDeleteAlbumTap: @escaping () -> Void = {},
        onReportTap: @escaping () -> Void = {}
    ) {
        self.displayModel = displayModel
        self.onBackTap = onBackTap
        self.onMusicButtonTap = onMusicButtonTap
        self.onWriteLogTap = onWriteLogTap
        self.onDownloadMusicTap = onDownloadMusicTap
        self.onEditAlbumTap = onEditAlbumTap
        self.onDeleteAlbumTap = onDeleteAlbumTap
        self.onReportTap = onReportTap
        _isMusicPlaying = State(initialValue: displayModel.isMusicPlaying)
    }

    // MARK: - Body

    var body: some View {
        
        ZStack(alignment: .topTrailing) {

            // ScrollView: empty-> scrollDisabled, hasLogs-> 스크롤 활성화
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    coverImageSection
                    actionButtonsSection
                    contentSection
                }
            }
            .scrollDisabled(displayModel.contentState == .empty)
            .ignoresSafeArea(edges: .top)
            .background(Color.white.ignoresSafeArea())

            AlbumDetailNavigationOverlay(
                onBackTap: onBackTap,
                onMoreTap: {
                    withAnimation(.easeInOut(duration: Constants.menuAnimationDuration)) {
                        isAlbumMenuVisible = true
                    }
                }
            )

            // 앨범 옵션 팝업
            if isAlbumMenuVisible {
                albumMenuOverlay
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Subviews

private extension AlbumDetailView {

    // 커버 이미지
    var coverImageSection: some View {
        VStack(spacing: 0) {
            coverImage
                .frame(width: Constants.coverWidth, height: Constants.coverHeight)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: Constants.coverBottomCornerRadius,
                        bottomTrailingRadius: Constants.coverBottomCornerRadius,
                        topTrailingRadius: 0
                    )
                )

            // 앨범 정보
            VStack(alignment: .leading, spacing: Constants.infoTextSpacing) {
                /// 앨범 제목
                Text(displayModel.title)
                    .font(.setPretendard(weight: .semiBold, size: Constants.titleFontSize))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                /// 여행지
                Text(displayModel.destination)
                    .font(.setPretendard(weight: .medium, size: Constants.subtitleFontSize))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)

                /// 여행 날짜
                Text(displayModel.dateText)
                    .font(.setPretendard(weight: .regular, size: Constants.dateFontSize))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, Constants.infoTopPadding)
            .padding(.bottom, Constants.infoBottomPadding)
            .background(Color.white)
        }
    }

    // 커버 이미지: URL 없으면 placeholder 표시
    @ViewBuilder
    var coverImage: some View {
        if let coverImage = displayModel.coverImage {
            Image(uiImage: coverImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            ZStack {
                Rectangle()
                    .fill(Color.placeholderSymbol)

                Image(systemName: "photo")
                    .font(.system(size: Constants.placeholderIconSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    var actionButtonsSection: some View {
        HStack(spacing: Constants.actionButtonSpacing) {
            /// 재생/일시정지
            AlbumDetailActionButton(
                title: isMusicPlaying ? "일시정지" : "재생",
                systemImageName: isMusicPlaying ? "pause.fill" : "play.fill",
                showSparkle: true,
                referenceTitle: "일시정지",
                action: {
                    isMusicPlaying.toggle()
                    onMusicButtonTap()
                }
            )

            /// 로그 작성 버튼
            AlbumDetailActionButton(
                title: "로그 작성",
                systemImageName: "pencil.line",
                action: onWriteLogTap
            )
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.bottom, Constants.actionsBottomPadding)
    }

    // contentState에 따라 빈 상태 or 로그 피드 표시
    @ViewBuilder
    var contentSection: some View {
        switch displayModel.contentState {
        case .empty:
            AlbumDetailEmptyStateSection()
                .padding(.top, Constants.emptyStateTopPadding)
                .padding(.horizontal, Constants.horizontalPadding)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Constants.emptyStateMinHeight, alignment: .top)

        case .hasLogs:
            // TODO: AlbumLogFeedItem 모델 추가 후 AlbumDetailLogFeedSection 연결
            EmptyView()
        }
    }

    // 앨범 옵션 팝업
    var albumMenuOverlay: some View {
        ZStack(alignment: .topTrailing) {
            // 팝업 외부 탭 감지: 투명 영역 전체 덮기
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: Constants.menuAnimationDuration)) {
                        isAlbumMenuVisible = false
                    }
                }
                .ignoresSafeArea()

            AlbumDetailAlbumMenuPopup(
                onDownloadMusic: {
                    isAlbumMenuVisible = false
                    onDownloadMusicTap()
                },
                onEditAlbum: {
                    isAlbumMenuVisible = false
                    onEditAlbumTap()
                },
                onDeleteAlbum: {
                    isAlbumMenuVisible = false
                    onDeleteAlbumTap()
                },
                onReport: {
                    isAlbumMenuVisible = false
                    onReportTap()
                }
            )
            .padding(.top, Constants.menuTopPadding)
            .padding(.trailing, Constants.menuTrailingPadding)
        }
    }
}

// MARK: - Constants

private extension AlbumDetailView {

    enum Constants {
        static let horizontalPadding: CGFloat = 20

        // 커버 이미지
        static let coverWidth: CGFloat = 402
        static let coverHeight: CGFloat = 460
        static let coverBottomCornerRadius: CGFloat = 32
        static let placeholderIconSize: CGFloat = 44

        // 앨범 정보 텍스트
        static let infoTopPadding: CGFloat = 12
        static let infoBottomPadding: CGFloat = 16
        static let infoTextSpacing: CGFloat = 4
        static let titleFontSize: CGFloat = 22
        static let subtitleFontSize: CGFloat = 14
        static let dateFontSize: CGFloat = 12

        // 액션 버튼 영역
        static let actionButtonSpacing: CGFloat = 12
        static let actionsBottomPadding: CGFloat = 28

        // 빈 상태 영역
        static let emptyStateTopPadding: CGFloat = 40
        static let emptyStateMinHeight: CGFloat = 240

        // 앨범 옵션 팝업 위치
        static let menuTopPadding: CGFloat = 56
        static let menuTrailingPadding: CGFloat = 20
        static let menuAnimationDuration: CGFloat = 0.15
    }
}

// MARK: - AlbumDetailNavigationOverlay

private struct AlbumDetailNavigationOverlay: View {

    private enum Constants {
        static let horizontalPadding: CGFloat = 20
        static let topPadding: CGFloat = 12
        static let iconSize: CGFloat = 22
        static let touchTargetSize: CGFloat = 44
    }

    let onBackTap: () -> Void
    let onMoreTap: () -> Void

    var body: some View {
        HStack {
            // 뒤로가기 버튼
            Button(action: onBackTap) {
                Image(systemName: "chevron.left")
                    .font(.system(size: Constants.iconSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: Constants.touchTargetSize, height: Constants.touchTargetSize)
            }

            Spacer()

            // 앨범 옵션 버튼
            Button(action: onMoreTap) {
                Image(systemName: "ellipsis")
                    .font(.system(size: Constants.iconSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: Constants.touchTargetSize, height: Constants.touchTargetSize)
            }
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.top, Constants.topPadding)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

// MARK: - AlbumDetailActionButton

private struct AlbumDetailActionButton: View {

    private enum Constants {
        static let height: CGFloat = 48
        static let cornerRadius: CGFloat = 28
        static let iconTextSpacing: CGFloat = 8
        static let fontSize: CGFloat = 16
        static let iconSize: CGFloat = 18

        static let iconFrameWidth: CGFloat = 22
        static let horizontalPadding: CGFloat = 20
        static let verticalPadding: CGFloat = 12

        // 스파클 데코
        static let bigSparkleSize: CGFloat = 9
        static let bigSparkleWidth: CGFloat = 9.38
        static let bigSparkleHeight: CGFloat = 9.66
        static let smallSparkleSize: CGFloat = 4.5
        static let smallSparkleWidth: CGFloat = 2.97
        static let smallSparkleHeight: CGFloat = 4.39
        /// 작은 스파클
        static let smallSparkleOffsetX: CGFloat = 0.31
        /// 스파클 그룹
        static let sparkleGroupOffsetX: CGFloat = 5
        static let sparkleGroupOffsetY: CGFloat = -5
    }

    let title: String
    let systemImageName: String
    var showSparkle: Bool = false   /// 스파클 데코 표시 여부
    var referenceTitle: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Constants.iconTextSpacing) {
                // 아이콘 고정 너비
                ZStack(alignment: .topTrailing) {
                    Image(systemName: systemImageName)
                        .font(.system(size: Constants.iconSize, weight: .medium))
                        .contentTransition(.symbolEffect(.replace.offUp)) /// 심볼 전환 효과
                        .frame(width: Constants.iconFrameWidth, height: Constants.iconSize)

                    if showSparkle {
                        // 큰 스파클 + 작은 스파클
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: "sparkle")
                                .font(.system(size: Constants.bigSparkleSize, weight: .medium))
                                .frame(width: Constants.bigSparkleWidth, height: Constants.bigSparkleHeight)

                            Image(systemName: "sparkle")
                                .font(.system(size: Constants.smallSparkleSize, weight: .medium))
                                .frame(width: Constants.smallSparkleWidth, height: Constants.smallSparkleHeight)
                                .offset(x: Constants.smallSparkleOffsetX)
                        }
                        .offset(x: Constants.sparkleGroupOffsetX, y: Constants.sparkleGroupOffsetY)
                    }
                }

                ZStack {
                    if let ref = referenceTitle {
                        Text(ref)
                            .opacity(0) // 레이아웃 너비 고정용
                    }
                    Text(title)
                        .fixedSize()
                        .id(title)
                        .transition(.asymmetric(    /// 타이틀 전환 효과
                            insertion: .opacity.animation(.easeIn(duration: 0.2)),
                            removal: .opacity.animation(.easeOut(duration: 0.05))
                        ))
                }
                .font(.setPretendard(weight: .medium, size: Constants.fontSize))
            }
            .foregroundStyle(Color.appPrimary)
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, Constants.verticalPadding)
            .frame(maxWidth: .infinity, minHeight: Constants.height)
            .background(Color.appPrimary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AlbumDetailEmptyStateSection
// 표시할 로그 없을 시 안내 문구

private struct AlbumDetailEmptyStateSection: View {

    private enum Constants {
        static let spacing: CGFloat = 8
        static let titleFontSize: CGFloat = 16
        static let descriptionFontSize: CGFloat = 14
    }

    var body: some View {
        VStack(spacing: Constants.spacing) {
            Text("아직 기록된 로그가 없어요.")
                .font(.setPretendard(weight: .semiBold, size: Constants.titleFontSize))
                .foregroundStyle(Color.placeholderText)
                .multilineTextAlignment(.center)

            Text("로그를 작성하고 여행의 추억을 완성해 보세요.")
                .font(.setPretendard(weight: .medium, size: Constants.descriptionFontSize))
                .foregroundStyle(Color.placeholderText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - AlbumMenuItemButtonStyle

private struct AlbumMenuItemButtonStyle: ButtonStyle {

    private enum Constants {
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 8
        static let cornerRadius: CGFloat = 8
        static let highlightBackground = Color(red: 0.92, green: 0.92, blue: 0.98)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, Constants.verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(configuration.isPressed ? Constants.highlightBackground : Color.clear)
            .cornerRadius(Constants.cornerRadius)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - AlbumDetailAlbumMenuPopup

private struct AlbumDetailAlbumMenuPopup: View {

    private enum Constants {
        static let popupWidth: CGFloat = 160
        static let padding: CGFloat = 8
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 3
        static let shadowOpacity: CGFloat = 0.3
        static let itemFontSize: CGFloat = 14
    }

    let onDownloadMusic: () -> Void
    let onEditAlbum: () -> Void
    let onDeleteAlbum: () -> Void
    let onReport: () -> Void

    // 팝업 메뉴 항목
    private enum MenuItem: CaseIterable {
        case downloadMusic, editAlbum, deleteAlbum, report

        var title: String {
            switch self {
            case .downloadMusic: return "배경 음악 다운로드"
            case .editAlbum:    return "앨범 수정"
            case .deleteAlbum:  return "앨범 삭제"
            case .report:       return "신고하기"
            }
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            ForEach(MenuItem.allCases, id: \.self) { item in
                menuItem(item)
            }
        }
        .padding(Constants.padding)
        .frame(width: Constants.popupWidth, alignment: .center)
        .background(.white)
        .cornerRadius(Constants.cornerRadius)
        .shadow(
            color: .black.opacity(Constants.shadowOpacity),
            radius: Constants.shadowRadius,
            x: 0,
            y: 0
        )
    }

    @ViewBuilder
    private func menuItem(_ item: MenuItem) -> some View {
        Button {
            switch item {
            case .downloadMusic: onDownloadMusic()
            case .editAlbum:     onEditAlbum()
            case .deleteAlbum:   onDeleteAlbum()
            case .report:        onReport()
            }
        } label: {
            HStack(alignment: .center, spacing: 0) {
                Text(item.title)
                    .font(.setPretendard(weight: .regular, size: Constants.itemFontSize))
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .buttonStyle(AlbumMenuItemButtonStyle())
    }
}

// MARK: - AlbumDetailDisplayModel
// 앨범 상세 화면 표시용

struct AlbumDetailDisplayModel {
    let title: String
    let destination: String
    let dateText: String
    let coverImage: UIImage?
    let contentState: AlbumDetailContentState
    let isMusicPlaying: Bool
}

// MARK: - AlbumDetailContentState
// 로그 유무에 따른 콘텐츠 상태

enum AlbumDetailContentState {
    case empty
    case hasLogs    // TODO: AlbumLogFeedItem 모델 추가 후 associated value([AlbumLogFeedItem]) 연결
}

// MARK: - Preview

#Preview("로그 없음") {
    AlbumDetailView(
        displayModel: AlbumDetailDisplayModel(
            title: "에펠탑 느낌나는 야경 도쿄타워",
            destination: "그레이트브리튼 북아일랜드 연합왕국 런던 마을",
            dateText: "2026년 11월 22일 - 2026년 11월 26일",
            coverImage: nil,
            contentState: .empty,
            isMusicPlaying: false
        )
    )
}

#Preview("로그 있음") {
    AlbumDetailView(
        displayModel: AlbumDetailDisplayModel(
            title: "에펠탑 느낌나는 야경 도쿄타워",
            destination: "일본 도쿄",
            dateText: "2026년 3월 20일 - 2026년 3월 24일",
            coverImage: nil,
            contentState: .hasLogs,
            isMusicPlaying: true
        )
    )
}
