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
            AlbumDetailLogFeedSection()
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
            case .report:       return "AI 음악 신고하기"
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
                    .font(.setPretendard(weight: .medium, size: Constants.itemFontSize))
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .buttonStyle(AlbumMenuItemButtonStyle())
    }
}

// MARK: - AlbumDetailLogFeedSection

private struct AlbumDetailLogFeedSection: View {
    
    // 더미 데이터
    private let dateGroups: [(label: String, items: [LogItemDummy])] = [
        (
            label: "3월 25일 화요일",
            items: [
                LogItemDummy(
                    id: 1,
                    dateLabel: "2026년 3월 25일",
                    text: "이것은 더미 데이터 입니다. 여기서 뭐라고 더 말을 해야 할지 모르겠네요. 제가 만약 2줄이 넘는다면 보이지 않을 거에요. 그러니 우리 더보기로 만나요.이제 접어줘요.",
                    imageCount: 3
                ),
                LogItemDummy(
                    id: 2,
                    dateLabel: "2026년 3월 25일",
                    text: "이것은 더미 데이터 입니다. 여기서 뭐라고 더 말을 해야 할지 모르겠네요. 제가 만약 2줄이 넘는다면 보이지 않을 거에요. 그러니 우리 더보기로 만나요. 이제 접어줘요.",
                    imageCount: 0
                )
            ]
        ),
        (
            label: "3월 24일 월요일",
            items: [
                LogItemDummy(
                    id: 3,
                    dateLabel: "2026년 3월 24일",
                    text: "안녕하세요? 저는 더미 데이터입니다. 이번에 저는 딱 2줄이 되어 볼거에요. 아직 아니네요 좀 더 작성할게요.",
                    imageCount: 2
                )
            ]
        )
    ]
    
    private enum Constants {
        static let horizontalPadding: CGFloat = 20
        static let topPadding: CGFloat = 8
        static let bottomPadding: CGFloat = 40
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(dateGroups.indices, id: \.self) { groupIndex in
                AlbumDetailLogDateGroup(
                    label: dateGroups[groupIndex].label,
                    items: dateGroups[groupIndex].items
                )
            }
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.top, Constants.topPadding)
        .padding(.bottom, Constants.bottomPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - AlbumDetailLogDateGroup
// 날짜별 로그 그룹 (헤더 + 카드 목록)

private struct AlbumDetailLogDateGroup: View {
    let label: String
    let items: [LogItemDummy]
    
    private enum Constants {
        /// 로그 카드 간 간격
        static let itemSpacing: CGFloat = 20
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Constants.itemSpacing) {
            ForEach(items.indices, id: \.self) { index in
                AlbumDetailLogItemCard(item: items[index])
            }
        }
    }
}

// MARK: - AlbumDetailLogItemCard
// 개별 로그 아이템 카드

private struct AlbumDetailLogItemCard: View {
    let item: LogItemDummy
    
    private enum Constants {
        static let dateFontSize: CGFloat = 14
        static let menuIconSize: CGFloat = 16
        static let contentSpacing: CGFloat = 8
        static let labelColor = Color(red: 0.74, green: 0.75, blue: 0.76)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Constants.contentSpacing) {
            // 날짜 + 로그 옵션 버튼
            HStack {
                Text(item.dateLabel)
                    .font(.setPretendard(weight: .medium, size: Constants.dateFontSize))
                    .foregroundStyle(Constants.labelColor)
                Spacer()
                Button {
                    // TODO: 로그 옵션 팝업 표시
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: Constants.menuIconSize))
                        .foregroundStyle(Constants.labelColor)
                }
                .buttonStyle(.plain)
            }
            
            // 이미지 슬라이더 (이미지 있을 때만)
            if item.imageCount > 0 {
                AlbumDetailLogImageSlider(imageCount: item.imageCount)
            }
            
            // 텍스트 + 더보기/접기
            AlbumDetailLogTextSection(text: item.text)
        }
    }
}

// MARK: - AlbumDetailLogImageSlider
// 이미지 슬라이더

private struct AlbumDetailLogImageSlider: View {
    let imageCount: Int
    
    @State private var currentIndex: Int = 0
    
    private enum Constants {
        static let cornerRadius: CGFloat = 12
        static let dotSize: CGFloat = 6
        static let dotSpacing: CGFloat = 6
        static let indicatorBottomPadding: CGFloat = 10
        static let indicatorHPadding: CGFloat = 10
        static let indicatorVPadding: CGFloat = 6
        static let placeholderIconSize: CGFloat = 36
        /// 4:3 비율 높이 계산
        static var sliderHeight: CGFloat {
            (UIScreen.main.bounds.width - 40) * 3 / 4
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 이미지 슬라이더
            TabView(selection: $currentIndex) {
                ForEach(0..<imageCount, id: \.self) { index in
                    // 이미지 로드 실패 시 placeholder 표시
                    ZStack {
                        Color.secondary.opacity(0.12)
                        Image(systemName: "photo")
                            .font(.system(size: Constants.placeholderIconSize))
                            .foregroundStyle(Color.placeholderSymbol)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: Constants.sliderHeight)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            
            // 커스텀 페이지 인디케이터
            if imageCount > 1 {
                HStack(spacing: Constants.dotSpacing) {
                    ForEach(0..<imageCount, id: \.self) { index in
                        Circle()
                            .frame(width: Constants.dotSize, height: Constants.dotSize)
                            .foregroundStyle(
                                index == currentIndex ? Color.appPrimary : Color.white
                            )
                    }
                }
                .padding(.horizontal, Constants.indicatorHPadding)
                .padding(.vertical, Constants.indicatorVPadding)
                .padding(.bottom, Constants.indicatorBottomPadding)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.sliderHeight)
    }
}

// MARK: - AlbumDetailLogTextSection
// 텍스트 + 더보기/접기

private struct AlbumDetailLogTextSection: View {
    let text: String
    
    @State private var isExpanded: Bool = false
    /// GeometryReader로 측정한 실제 콘텐츠 너비
    @State private var contentWidth: CGFloat = 0
    
    private enum Constants {
        static let fontSize: CGFloat = 16
        static let lineLimit: Int = 2
        static let widthBuffer: CGFloat = 8
        static let truncationSuffix: String = "...더 보기"
    }
    
    private var textFont: Font { .setPretendard(weight: .regular, size: Constants.fontSize) }
    private let actionColor = Color(red: 0.74, green: 0.75, blue: 0.76)
    
    private var uiFont: UIFont {
        UIFont(name: "Pretendard-Regular", size: Constants.fontSize)
        ?? UIFont.systemFont(ofSize: Constants.fontSize)
    }
    
    private func truncatedText(for width: CGFloat) -> String? {
        guard width > 0 else { return nil }
        
        let attrs: [NSAttributedString.Key: Any] = [.font: uiFont]
        let measureWidth = width - Constants.widthBuffer
        let constraintSize = CGSize(width: measureWidth, height: .greatestFiniteMagnitude)
        let twoLineHeight = uiFont.lineHeight * CGFloat(Constants.lineLimit) + 1
        
        // 전체 텍스트가 2줄 이내면 truncation 불필요
        let fullRect = (text as NSString).boundingRect(
            with: constraintSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )
        guard fullRect.height > twoLineHeight else { return nil }
        
        let chars = Array(text)
        var lo = 0, hi = chars.count
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            let candidate = String(chars.prefix(mid)) + Constants.truncationSuffix
            let rect = (candidate as NSString).boundingRect(
                with: constraintSize,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs,
                context: nil
            )
            if rect.height <= twoLineHeight { lo = mid } else { hi = mid - 1 }
        }
        return String(chars.prefix(lo))
    }
    
    var body: some View {
        // 실제 너비 측정 후 truncation 계산
        let cutText = truncatedText(for: contentWidth)
        let isTruncated = cutText != nil
        
        Group {
            if isExpanded {
                // 펼친 상태
                ZStack(alignment: .bottomTrailing) {
                    Text(text)
                        .font(textFont)
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button("접기") {
                        withAnimation(.easeInOut(duration: 0.2)) { isExpanded = false }
                    }
                    .font(textFont)
                    .foregroundStyle(actionColor)
                    .background(Color.white)
                }
            } else if isTruncated, let cut = cutText {
                // 접힌 상태 + truncation
                (
                    Text(cut)
                        .foregroundStyle(Color.textPrimary)
                    + Text("...  ")
                        .foregroundStyle(Color.textPrimary)
                    + Text("더 보기")
                        .foregroundStyle(actionColor)
                )
                .font(textFont)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded = true }
                }
            } else {
                Text(text)
                    .font(textFont)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // 콘텐츠 너비 측정
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { w in
            if contentWidth == 0 { contentWidth = w }
        }
    }
}

// MARK: - LogItemDummy
// 더미 데이터 구조체 

private struct LogItemDummy {
    let id: Int
    let dateLabel: String
    let text: String
    let imageCount: Int
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
            destination: "그레이트브리튼 북아일랜드 연합왕국 런던 마을",
            dateText: "2026년 3월 20일 - 2026년 3월 24일",
            coverImage: nil,
            contentState: .hasLogs,
            isMusicPlaying: true
        )
    )
}
