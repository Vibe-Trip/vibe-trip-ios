//
//  AlbumDetailView.swift
//  VibeTrip
//
//  Created by CHOI on 3/26/26.
//

import SwiftUI
import Combine

// MARK: - AlbumDetailViewModel

@MainActor final class AlbumDetailViewModel: ObservableObject {

    @Published private(set) var logs: [AlbumLogEntry] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var hasNext: Bool = false
    @Published private(set) var showDeleteConfirm: Bool = false
    @Published private(set) var isDeleting: Bool = false
    @Published private(set) var deleteError: String? = nil
    @Published private(set) var didDeleteAlbum: Bool = false
    @Published private(set) var pendingDeleteLogId: Int? = nil
    @Published private(set) var showDeleteLogConfirm: Bool = false
    @Published private(set) var isDeletingLog: Bool = false
    @Published private(set) var deleteLogError: String? = nil

    private let albumId: String
    private var cursor: Int? = nil
    private let limit = 20
    private let service: AlbumServiceProtocol
    // 밀리초 포함 ISO8601 파싱
    private static let isoFormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    // 일반 ISO8601 파싱
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated init(albumId: String, service: AlbumServiceProtocol = AlbumService()) {
        self.albumId = albumId
        self.service = service
    }

    func loadInitialLogs() async {
        guard !isLoading else { return }
        cursor = nil
        logs = []
        await fetchLogs()
    }

    func requestDeleteAlbum() {
        showDeleteConfirm = true
    }

    // ExitPopupView 취소 탭 시 팝업 비활성화
    func dismissDeleteConfirm() {
        showDeleteConfirm = false
    }

    // alert 바인딩 setter에서 에러 alert 닫힘 시 호출
    func dismissDeleteError() {
        deleteError = nil
    }

    func confirmDeleteAlbum() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await service.deleteAlbum(albumId: albumId)
            didDeleteAlbum = true
        } catch {
            deleteError = "앨범 삭제에 실패했습니다."
        }
    }

    func requestDeleteLog(id: Int) {
        pendingDeleteLogId = id
        showDeleteLogConfirm = true
    }

    // 팝업 취소 탭: 팝업 비활성화
    func dismissDeleteLogConfirm() {
        showDeleteLogConfirm = false
        pendingDeleteLogId = nil
    }

    // alert 바인딩 setter: 에러 alert 닫힘 시 호출
    func dismissDeleteLogError() {
        deleteLogError = nil
    }

    func confirmDeleteLog() async {
        guard let logId = pendingDeleteLogId else { return }
        isDeletingLog = true
        showDeleteLogConfirm = false
        defer { isDeletingLog = false }
        do {
            try await service.deleteAlbumLog(albumId: albumId, albumLogId: logId)
            pendingDeleteLogId = nil
            await loadInitialLogs()
        } catch {
            deleteLogError = "로그 삭제에 실패했습니다."
        }
    }

    func loadMoreIfNeeded(lastId: Int) async {
        guard hasNext, !isLoading, logs.last?.id == lastId else { return }
        await fetchLogs()
    }

    private func fetchLogs() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let payload = try await service.fetchAlbumLogs(
                albumId: albumId, cursor: cursor, limit: limit
            )
            logs.append(contentsOf: payload.content)
            hasNext = payload.hasNext
            cursor = payload.content.last?.id
        } catch {
            // TODO: 에러 토스트 처리 (로그 수정/삭제 작업 시 함께 정리)
        }
    }

    // postedAt(ISO8601) 기준 날짜별 그룹핑
    // 반환: [(dateLabel: "3월 25일 화요일", logs: [AlbumLogEntry])]
    var groupedLogs: [(dateLabel: String, logs: [AlbumLogEntry])] {
        let labelFormatter = DateFormatter()
        labelFormatter.locale = Locale(identifier: "ko_KR")
        labelFormatter.dateFormat = "M월 d일 EEEE"

        let grouped = Dictionary(grouping: logs) { entry -> String in
            guard let date = Self.parseISO8601Date(entry.postedAt) else { return "" }
            return labelFormatter.string(from: date)
        }

        return grouped.compactMap { label, items -> (String, [AlbumLogEntry])? in
            guard !label.isEmpty else { return nil }
            return (label, items)
        }
        .sorted { lhs, rhs in
            guard let l = Self.parseISO8601Date(lhs.1.first!.postedAt),
                  let r = Self.parseISO8601Date(rhs.1.first!.postedAt) else { return false }
            return l > r
        }
    }

    static func parseISO8601Date(_ value: String) -> Date? {
        isoFormatterWithFractionalSeconds.date(from: value)
            ?? isoFormatter.date(from: value)
    }
}

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
    
    @StateObject private var logViewModel: AlbumDetailViewModel

    // 앨범 옵션 팝업 표시 여부
    @State private var isAlbumMenuVisible: Bool = false

    // 신고 바텀시트 표시 여부
    @State private var isReportSheetPresented: Bool = false

    // 로그 작성 화면 표시 여부
    @State private var isWritingLog: Bool = false
    // 로그 저장 성공 여부 -> onDismiss에서 재조회 여부 판단
    @State private var didSaveLog: Bool = false
    
    // 재생/일시정지 토글 상태
    // TODO: AVPlayer 연결
    @State private var isMusicPlaying: Bool
    
    // 스크롤 offset: ScrollOffsetKey로 감지
    @State private var scrollOffset: CGFloat = 0
    
    // 네비게이션 바 진입 시점 계산에 사용
    @State private var titleGlobalMinY: CGFloat = .greatestFiniteMagnitude
    
    //최상단 이동 버튼 표시 -> 블러 네비게이션 바 전환 시
    private var showScrollToTop: Bool { overlayOpacity < 1 }
    
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
        _logViewModel = StateObject(wrappedValue: AlbumDetailViewModel(albumId: String(displayModel.albumId)))
    }
    
    // MARK: - Body
    
    var body: some View {
        
        ZStack(alignment: .topTrailing) {
            
            // ScrollView: empty -> scrollDisabled, hasLogs -> 스크롤 활성화
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // 스크롤 offset 감지 + 최상단 이동 앵커
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetKey.self,
                                    value: geo.frame(in: .global).minY
                                )
                        }
                        .frame(height: 0)
                        .id("scrollTop")
                        
                        coverImageSection
                        actionButtonsSection
                        contentSection
                    }
                }
                .scrollDisabled(logViewModel.logs.isEmpty)
                .ignoresSafeArea(edges: .top)
                .background(Color.white.ignoresSafeArea())
                .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = $0 }
                .overlay(alignment: .bottomTrailing) {
                    scrollToTopButton {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo("scrollTop", anchor: .top)
                        }
                    }
                }
            }
            
            // 블러 네비게이션 바 -> 커버 이미지 지날 때 사용
            AppNavigationBar(
                title: displayModel.title,
                style: .blurTransition(scrollOffset: titleNavOffset),
                onBackTap: onBackTap
            ) {
                Button(action: showAlbumMenu) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: Constants.navIconSize, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .opacity(1 - overlayOpacity)
            .allowsHitTesting(overlayOpacity < 1)
            
            // 투명 네비게이션 바
            AlbumDetailNavigationOverlay(
                onBackTap: onBackTap,
                onMoreTap: showAlbumMenu
            )
            .opacity(overlayOpacity)
            .allowsHitTesting(overlayOpacity > 0)
            
            // 앨범 옵션 팝업
            if isAlbumMenuVisible {
                albumMenuOverlay
            }

            // 앨범 삭제 확인 팝업
            if logViewModel.showDeleteConfirm {
                ExitPopupView(
                    title: "앨범을 삭제 하시겠어요?",
                    onCancel: { logViewModel.dismissDeleteConfirm() },
                    onConfirm: { Task { await logViewModel.confirmDeleteAlbum() } }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $isWritingLog, onDismiss: {
            // 저장 성공 시에만 목록 재조회
            if didSaveLog {
                didSaveLog = false
                Task { await logViewModel.loadInitialLogs() }
            }
        }) {
            AlbumLogView(albumId: String(displayModel.albumId), mode: .create, onSaved: {
                didSaveLog = true
            })
        }
        // 신고 바텀시트
        .sheet(isPresented: $isReportSheetPresented) {
            ReportBottomSheetView(isPresented: $isReportSheetPresented) { reason in
                isReportSheetPresented = false
                // TODO: 신고하기 API 연동
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onReportTap()  // 시트 닫힘 후 메인 이동 + 토스트
                }
            }
            .presentationDetents([.height(286)])
            .presentationDragIndicator(.hidden)
        }
        .task { await logViewModel.loadInitialLogs() }
        // 삭제 실패 시 에러 메시지 alert
        .alert(
            "삭제 실패",
            isPresented: Binding(
                get: { logViewModel.deleteError != nil },
                set: { if !$0 { logViewModel.dismissDeleteError() } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(logViewModel.deleteError ?? "")
        }
        // 삭제 성공 시: fullScreenCover 닫기
        .onChange(of: logViewModel.didDeleteAlbum) { _, didDelete in
            if didDelete { onDeleteAlbumTap() }
        }
    }
}

// MARK: - Subviews

private extension AlbumDetailView {
    
    // MARK: - 블러 네비게이션 바
    
    // 네비게이션 바 콘텐츠 하단 Y (safeTop + 44pt)
    private var navBarBottom: CGFloat {
        let safeTop = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.top ?? 0
        return safeTop + 44
    }
    
    // 타이틀 텍스트 및 네비게이션 바 하단의 거리
    var titleNavOffset: CGFloat {
        titleGlobalMinY - navBarBottom
    }
    
    // 투명 오버레이 투명도
    var overlayOpacity: Double {
        let fadeWindow: CGFloat = 30
        if titleNavOffset > fadeWindow { return 1 }
        if titleNavOffset <= 0 { return 0 }
        return Double(titleNavOffset / fadeWindow)
    }
    
    // 앨범 메뉴 팝업 표시 헬퍼
    func showAlbumMenu() {
        withAnimation(.easeInOut(duration: Constants.menuAnimationDuration)) {
            isAlbumMenuVisible = true
        }
    }
    
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
                    .onGeometryChange(for: CGFloat.self) {
                        $0.frame(in: .global).minY
                    } action: { minY in
                        titleGlobalMinY = minY
                    }
                
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
            // 블러 네비게이션 바 전환 시: 앨범 정보 텍스트 페이드아웃 + 살짝 위로 밀리는 효과
            .opacity(overlayOpacity)
            .offset(y: -(1 - overlayOpacity) * 8)
        }
    }
    
    // 커버 이미지: URL 없으면 placeholder 표시
    @ViewBuilder
    var coverImage: some View {
        AsyncImage(url: displayModel.coverImageUrl) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            default:
                ZStack {
                    Rectangle()
                        .fill(Color.placeholderSymbol)

                    Image(systemName: "photo")
                        .font(.system(size: Constants.placeholderIconSize, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
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
                action: { isWritingLog = true }
            )
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.bottom, Constants.actionsBottomPadding)
    }
    
    // ViewModel 상태에 따라 빈 상태 / 로딩 / 로그 피드 표시
    @ViewBuilder
    var contentSection: some View {
        if !logViewModel.logs.isEmpty {
            AlbumDetailLogFeedSection(viewModel: logViewModel)
        } else if logViewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, Constants.emptyStateTopPadding)
        } else {
            AlbumDetailEmptyStateSection()
                .padding(.top, Constants.emptyStateTopPadding)
                .padding(.horizontal, Constants.horizontalPadding)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Constants.emptyStateMinHeight, alignment: .top)
        }
    }
    
    // MARK: - 최상단 이동 버튼
    
    func scrollToTopButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 0) {
                Image(systemName: "arrow.up")
                    .font(.system(size: Constants.scrollToTopIconSize, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(10)
            .frame(
                width: Constants.scrollToTopButtonSize,
                height: Constants.scrollToTopButtonSize,
                alignment: .center
            )
            .background(Color.appPrimary400)
            .cornerRadius(Constants.scrollToTopButtonSize / 2)
            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 0)
        }
        .padding(.trailing, Constants.scrollToTopTrailingPadding)
        .padding(.bottom, Constants.scrollToTopBottomPadding)
        .opacity(showScrollToTop ? 1 : 0)
        .animation(
            .easeInOut(duration: Constants.scrollToTopAnimationDuration),
            value: showScrollToTop
        )
        .allowsHitTesting(showScrollToTop)
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
                    logViewModel.requestDeleteAlbum()
                },
                onReport: {
                    isAlbumMenuVisible = false
                    isReportSheetPresented = true
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
        
        // 블러 네비게이션 바 trailing 아이콘 크기
        static let navIconSize: CGFloat = 20
        
        // 최상단 이동 버튼
        // 버튼 표시 scrollOffset 기준 값
        static let scrollToTopThreshold: CGFloat = -300
        static let scrollToTopButtonSize: CGFloat = 48
        static let scrollToTopIconSize: CGFloat = 18
        static let scrollToTopTrailingPadding: CGFloat = 20
        static let scrollToTopBottomPadding: CGFloat = 40
        static let scrollToTopAnimationDuration: Double = 0.2
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
            .foregroundStyle(Color.appPrimary400)
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, Constants.verticalPadding)
            .frame(maxWidth: .infinity, minHeight: Constants.height)
            .background(Color.appPrimary400.opacity(0.12))
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

// MARK: - LogMenuItemButtonStyle
// GestureState + simultaneousGesture 방식: 탭 상태 직접 추적

private struct LogMenuItemButtonStyle: ButtonStyle {
    
    private enum Constants {
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 8
        static let cornerRadius: CGFloat = 8
        static let highlightBackground = Color(red: 0.92, green: 0.92, blue: 0.98)
        static let animationDuration: Double = 0.1
    }
    
    func makeBody(configuration: Configuration) -> some View {
        InnerBody(configuration: configuration)
    }
    
    // GestureState를 사용하기 위해 별도 View로 분리
    private struct InnerBody: View {
        let configuration: ButtonStyleConfiguration
        @GestureState private var isPressed: Bool = false
        
        var body: some View {
            configuration.label
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.vertical, Constants.verticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isPressed ? Constants.highlightBackground : Color.clear)
                .cornerRadius(Constants.cornerRadius)
                .animation(
                    .easeInOut(duration: Constants.animationDuration),
                    value: isPressed
                )
                // 버튼 탭 액션을 유지하면서 press 상태만 별도 추적
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isPressed) { _, state, _ in state = true }
                )
        }
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

// MARK: - AlbumDetailLogMenuPopup

private struct AlbumDetailLogMenuPopup: View {
    
    private enum Constants {
        static let popupWidth: CGFloat = 140
        static let padding: CGFloat = 8
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 3
        static let shadowOpacity: CGFloat = 0.3
        static let itemFontSize: CGFloat = 14
    }
    
    let onEditLog: () -> Void
    let onDeleteLog: () -> Void
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Button(action: onEditLog) {
                Text("로그 수정")
                    .font(.setPretendard(weight: .medium, size: Constants.itemFontSize))
                    .foregroundStyle(Color.textPrimary)
            }
            .buttonStyle(LogMenuItemButtonStyle())
            
            Button(action: onDeleteLog) {
                Text("로그 삭제")
                    .font(.setPretendard(weight: .medium, size: Constants.itemFontSize))
                    .foregroundStyle(Color.textPrimary)
            }
            .buttonStyle(LogMenuItemButtonStyle())
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
}

// MARK: - AlbumDetailLogFeedSection

private struct AlbumDetailLogFeedSection: View {

    @ObservedObject var viewModel: AlbumDetailViewModel

    private enum Constants {
        static let horizontalPadding: CGFloat = 20
        static let topPadding: CGFloat = 8
        static let bottomPadding: CGFloat = 40
    }

    var body: some View {
        let groups = viewModel.groupedLogs
        let lastEntryId = viewModel.logs.last?.id

        VStack(alignment: .leading, spacing: 20) {
            ForEach(groups.indices, id: \.self) { groupIndex in
                AlbumDetailLogDateGroup(
                    label: groups[groupIndex].dateLabel,
                    entries: groups[groupIndex].logs,
                    lastEntryId: lastEntryId,
                    onLastAppear: {
                        guard let id = lastEntryId else { return }
                        await viewModel.loadMoreIfNeeded(lastId: id)
                    }
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
    let entries: [AlbumLogEntry]
    let lastEntryId: Int?
    let onLastAppear: (() async -> Void)?

    private enum Constants {
        /// 로그 카드 간 간격
        static let itemSpacing: CGFloat = 20
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.itemSpacing) {
            ForEach(entries) { entry in
                AlbumDetailLogItemCard(
                    entry: entry,
                    isLast: entry.id == lastEntryId,
                    onLastAppear: onLastAppear
                )
            }
        }
    }
}

// MARK: - AlbumDetailLogItemCard
// 개별 로그 아이템 카드

private struct AlbumDetailLogItemCard: View {
    let entry: AlbumLogEntry
    let isLast: Bool
    let onLastAppear: (() async -> Void)?

    /// 로그 옵션 팝업 표시 여부
    @State private var isMenuVisible: Bool = false

    private enum Constants {
        static let dateFontSize: CGFloat = 14
        static let menuIconSize: CGFloat = 16
        static let menuTouchTarget: CGFloat = 44
        static let contentSpacing: CGFloat = 8
        static let menuAnimationDuration: Double = 0.15
        static let menuTopOffset: CGFloat = 26
        static let menuTrailingPadding: CGFloat = 17
        static let labelColor = Color(red: 0.74, green: 0.75, blue: 0.76)
    }

    /// postedAt ISO8601 → "yyyy년 M월 d일" 포맷
    private var dateLabel: String {
        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "ko_KR")
        displayFormatter.dateFormat = "yyyy년 M월 d일"
        guard let date = AlbumDetailViewModel.parseISO8601Date(entry.postedAt) else {
            return entry.postedAt
        }
        return displayFormatter.string(from: date)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: Constants.contentSpacing) {
                // 날짜 + 로그 옵션 버튼
                HStack {
                    Text(dateLabel)
                        .font(.setPretendard(weight: .medium, size: Constants.dateFontSize))
                        .foregroundStyle(Constants.labelColor)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: Constants.menuAnimationDuration)) {
                            isMenuVisible.toggle()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: Constants.menuIconSize))
                            .foregroundStyle(Constants.labelColor)
                            .frame(
                                width: Constants.menuTouchTarget,
                                height: Constants.menuTouchTarget
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                // 이미지 슬라이더 (이미지 있을 때만)
                if !entry.images.isEmpty {
                    AlbumDetailLogImageSlider(images: entry.images)
                }

                // 텍스트 + 더보기/접기
                AlbumDetailLogTextSection(text: entry.description)
            }

            // 팝업 표시 시: 외부 탭 dismiss 영역 + 팝업
            if isMenuVisible {
                // 카드 범위 내 외부 탭 감지
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: Constants.menuAnimationDuration)) {
                            isMenuVisible = false
                        }
                    }

                // 수정 및 삭제 팝업
                AlbumDetailLogMenuPopup(
                    onEditLog: {
                        withAnimation(.easeInOut(duration: Constants.menuAnimationDuration)) {
                            isMenuVisible = false
                        }
                        // TODO: 로그 수정 화면으로 이동
                    },
                    onDeleteLog: {
                        withAnimation(.easeInOut(duration: Constants.menuAnimationDuration)) {
                            isMenuVisible = false
                        }
                        // TODO: 로그 삭제 API 호출 후 목록 갱신
                    }
                )
                .padding(.top, Constants.menuTopOffset)
                .padding(.trailing, Constants.menuTrailingPadding)
            }
        }
        .onAppear {
            guard isLast else { return }
            Task { await onLastAppear?() }
        }
    }
}

// MARK: - AlbumDetailLogImageSlider
// 이미지 슬라이더

private struct AlbumDetailLogImageSlider: View {
    let images: [AlbumLogImage]

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
                ForEach(images.indices, id: \.self) { index in
                    AsyncImage(url: images[index].imageUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            // 로드 중 / 실패 시 placeholder 표시
                            ZStack {
                                Color.secondary.opacity(0.12)
                                Image(systemName: "photo")
                                    .font(.system(size: Constants.placeholderIconSize))
                                    .foregroundStyle(Color.placeholderSymbol)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: Constants.sliderHeight)
                    .clipped()
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: Constants.sliderHeight)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))

            // 커스텀 페이지 인디케이터
            if images.count > 1 {
                HStack(spacing: Constants.dotSpacing) {
                    ForEach(images.indices, id: \.self) { index in
                        Circle()
                            .frame(width: Constants.dotSize, height: Constants.dotSize)
                            .foregroundStyle(
                                index == currentIndex ? Color.appPrimary400 : Color.white
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
        static let widthBuffer: CGFloat = 1
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

// MARK: - AlbumDetailDisplayModel
// 앨범 상세 화면 표시용

struct AlbumDetailDisplayModel {
    let albumId: Int
    let title: String
    let destination: String
    let dateText: String
    let coverImageUrl: URL?
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
            albumId: 1,
            title: "에펠탑 느낌나는 야경 도쿄타워",
            destination: "그레이트브리튼 북아일랜드 연합왕국 런던 마을",
            dateText: "2026년 11월 22일 - 2026년 11월 26일",
            coverImageUrl: nil,
            contentState: .empty,
            isMusicPlaying: false
        )
    )
}

#Preview("로그 있음") {
    AlbumDetailView(
        displayModel: AlbumDetailDisplayModel(
            albumId: 1,
            title: "에펠탑 느낌나는 야경 도쿄타워",
            destination: "그레이트브리튼 북아일랜드 연합왕국 런던 마을",
            dateText: "2026년 3월 20일 - 2026년 3월 24일",
            coverImageUrl: nil,
            contentState: .hasLogs,
            isMusicPlaying: true
        )
    )
}
