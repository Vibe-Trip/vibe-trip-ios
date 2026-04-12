//
//  MainPageView.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI
import Foundation

// MARK: - MainPageView

struct MainPageView: View {

    // MARK: - ViewModel

    @StateObject private var viewModel: MainPageViewModel
    @EnvironmentObject private var appState: AppState

    init(viewModel: MainPageViewModel = MainPageViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Carousel State (UI 전용)

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var selectedAlbum: AlbumCard? = nil

    // 타이틀 생성 중 앨범 탭 시 표시하는 차단 토스트
    @State private var showGeneratingToast: Bool = false

    // MARK: - 캐러셀 Layout Constants

    private enum CarouselLayout {
        static let cardWidth: CGFloat = AlbumCardView.Layout.cardWidth
        static let cardGap: CGFloat = 17
        // 현재 카드 기준 앞/뒤로 미리 준비할 커버 이미지 범위
        static let preloadRange: Int = 2
        static let activeTopSpacing: CGFloat = 68
        static let inactiveTopSpacing: CGFloat = 84
        static let activeSideSpacing: CGFloat = 40
        // 좌우 40 기준으로 카드 스케일 계산
        static let horizontalPadding: CGFloat = 40
        static let swipeThresholdRatio: CGFloat = 0.35
        static let swipeVelocityThreshold: CGFloat = 200
        static let springResponse: Double = 0.45
        static let springDamping: Double = 0.90
    }

    // 초기 로딩 시에도 AlbumCardView 프레임을 동일하게 유지하기 위한 placeholder 데이터
    private var loadingPlaceholderAlbum: AlbumCard {
        AlbumCard(
            id: -1,
            title: nil,
            location: "",
            startDate: "",
            endDate: "",
            coverImageUrl: nil,
            logImageCount: 0,
            previewLogImages: []
        )
    }

    // MARK: - Body

    // body 내 반복 접근 시 filter 재계산을 줄이기 위한 캐시
    private var visibleAlbums: [AlbumCard] { viewModel.visibleAlbums }
    // 현재 위치 기준으로 미리 준비할 커버 이미지 키
    private var preloadKey: String {
        preloadCoverImageURLs(from: visibleAlbums).map(\.absoluteString).joined(separator: "|")
    }

    var body: some View {
        contentView
            .onChange(of: selectedAlbum?.id) { _, albumId in
                // 앨범 상세 열림 여부를 AppState에 동기화: 딥링크 수신 시 기존 열림 여부 판단에 사용
                appState.isAlbumDetailPresented = albumId != nil
            }
            .onChange(of: appState.needsDismissAlbumDetail) { _, needsDismiss in
                // 딥링크 수신 시 현재 열린 앨범 상세 닫기
                guard needsDismiss else { return }
                selectedAlbum = nil
            }
            .fullScreenCover(item: $selectedAlbum, onDismiss: {
                // 딥링크로 인한 dismiss인 경우: AppState 시그널로 MainTabBarView에 알림
                guard let albumId = appState.pendingDeeplinkAlbumId else { return }
                appState.pendingDeeplinkAlbumId = nil
                appState.needsDismissAlbumDetail = false
                appState.deeplinkAlbumReadyToPresent = albumId
            }) { album in
                AlbumDetailView(
                    displayModel: album.toDisplayModel(),
                    onBackTap: { selectedAlbum = nil },
                    onEditSaved: { outcome in
                        // 재생성 저장일 때만 메인 복귀 + 스켈레톤/폴링 흐름으로 전환
                        guard case .regenerated = outcome else { return }   // 재생성 안 함: 상세페이지 유지

                        viewModel.markAlbumNotReady(albumId: album.id)
                        selectedAlbum = nil
                        appState.pendingTabNavigation = .home
                        Task { await viewModel.reloadAlbums() }
                    },
                    onDeleteAlbumTap: {
                        selectedAlbum = nil
                        currentIndex = 0
                        // 삭제 후 목록 재조회
                        Task { await viewModel.reloadAlbums() }
                        // 삭제 완료 후 홈 탭으로 강제 이동
                        appState.pendingTabNavigation = .home
                    }
                )
                // albumId 기준으로 view 재생성 강제 -> @State/@StateObject 확실히 초기화
                .id(album.id)
            }
            .overlay(alignment: .bottom) {
                if showGeneratingToast {
                    // 타이틀 생성 중 앨범 진입 시도 시 차단 안내
                    AppToastView(
                        message: "앨범을 제작하고 있어요. 잠시만 기다려 주세요!",
                        systemImageName: "exclamationmark.circle"
                    )
                    .padding(.bottom, 88)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showGeneratingToast)
    }

    // 타입 체커 부하 분산을 위해 콘텐츠 및 기본 동작 modifier를 별도 분리
    private var contentView: some View {
        Group {
            if viewModel.isInitialLoading {
                initialLoadingContent
            } else if visibleAlbums.isEmpty {
                emptyContent
            } else {
                carouselView(visibleAlbums: visibleAlbums)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await viewModel.loadAlbums() }
        // 첫 진입 시 현재 카드 주변 이미지 캐시 적재
        // 홈 탭 진입 시점에 대기 중인 카드 위치 이동 처리 -> onChange가 놓친 경우 보완
        .onAppear {
            preloadCoverImages(urls: preloadCoverImageURLs(from: visibleAlbums))
            if let albumId = appState.pendingCarouselAlbumId,
               let idx = visibleAlbums.firstIndex(where: { $0.id == albumId }) {
                appState.pendingCarouselAlbumId = nil
                currentIndex = idx
                dragOffset = 0
            }
        }
        .onDisappear { viewModel.cancelAllPolling() }
        // 스와이프 후 현재 카드가 바뀌면 주변 이미지 다시 준비
        .onChange(of: currentIndex) { _, _ in
            preloadCoverImages(urls: preloadCoverImageURLs(from: visibleAlbums))
        }
        // 페이지네이션 등으로 주변 카드 구성이 바뀌면 캐시 갱신
        .onChange(of: preloadKey) { _, _ in
            preloadCoverImages(urls: preloadCoverImageURLs(from: visibleAlbums))
        }
        .onChange(of: appState.needsAlbumRefresh) { _, needsReload in
            guard needsReload else { return }
            // 중복 트리거 방지를 위해 플래그 먼저 초기화 후 새로고침
            appState.needsAlbumRefresh = false
            currentIndex = 0
            dragOffset = 0
            Task { await viewModel.reloadAlbums() }
        }
        // 딥링크 상세 뒤로가기 후 해당 앨범 카드로 캐러셀 위치 이동
        .onChange(of: appState.pendingCarouselAlbumId) { _, albumId in
            guard let albumId else { return }
            appState.pendingCarouselAlbumId = nil
            guard let idx = visibleAlbums.firstIndex(where: { $0.id == albumId }) else { return }
            currentIndex = idx
            dragOffset = 0
        }
    }

    // MARK: - 빈 상태 UI

    private var initialLoadingContent: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let cardScale = cardScale(for: geo.size.width)
            let topY = safeTop + CarouselLayout.activeTopSpacing

            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()

                AlbumCardView(album: loadingPlaceholderAlbum, isReady: false, isActive: true)
                    .scaleEffect(cardScale, anchor: .topLeading)
                    .offset(x: CarouselLayout.activeSideSpacing, y: topY)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                AppNavigationBar(style: .transparent) {
                    Image("AppLogo_Home")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 30)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .ignoresSafeArea()
        }
    }

    private var emptyContent: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                emptyStateView
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AppNavigationBar(style: .transparent) {
                Image("AppLogo_Home")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
    }

    private var emptyStateView: some View {
        VStack(alignment: .center, spacing: 8) {
            // 빈 상태 아이콘
            Image("CreateAlbum")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 150)
                .offset(x: -8)
                .foregroundStyle(Color.placeholderSymbol)

            Text("첫 번째 여행 앨범을 만들어보세요.")
                .font(Font.setPretendard(weight: .semiBold, size: 22))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("GrayScale/500"))
                .padding(.horizontal, 39)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("지금 바로 아래 '앨범 만들기'를 눌러 시작 해보세요!")
                .font(Font.setPretendard(weight: .medium, size: 16))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.placeholderText)
                .padding(.horizontal, 39)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 캐러셀

    private func carouselView(visibleAlbums: [AlbumCard]) -> some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let safeBottom = geo.safeAreaInsets.bottom
            let screenW = geo.size.width
            let screenH = geo.size.height + safeTop + safeBottom
            let scaledCardWidth = cardWidth(for: screenW)
            let cardScale = cardScale(for: screenW)
            let dragBaseWidth = max(scaledCardWidth, 1)

            let cardStep = scaledCardWidth + CarouselLayout.cardGap
            let activeTopY = safeTop + CarouselLayout.activeTopSpacing
            let inactiveTopY = safeTop + CarouselLayout.inactiveTopSpacing
            let verticalDiff = inactiveTopY - activeTopY
            let progress = min(abs(dragOffset) / dragBaseWidth, 1.0)

            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()

                ZStack {
                    ForEach(Array(visibleAlbums.enumerated()), id: \.element.id) { item in
                        let index = item.offset
                        let album = item.element
                        let rel = index - currentIndex
                        let isActive = rel == 0
                        let isNext = rel == 1
                        let isEntering = (isNext && dragOffset < 0) || (rel == -1 && dragOffset > 0)

                        if abs(rel) <= 1 {
                            let baseX: CGFloat = {
                                if isActive { return 0 }
                                if isNext { return cardStep }
                                return -cardStep
                            }()

                            let topY: CGFloat = {
                                if isActive { return activeTopY + verticalDiff * progress }
                                if isEntering { return inactiveTopY - verticalDiff * progress }
                                return inactiveTopY
                            }()

                            AlbumCardView(
                                album: album,
                                isReady: viewModel.isReady(for: album.id),
                                isActive: isActive
                            )
                            .scaleEffect(cardScale, anchor: .topLeading)
                            .onTapGesture {
                                guard isActive else { return }
                                if !viewModel.isReady(for: album.id) {
                                    guard !showGeneratingToast else { return }
                                    withAnimation { showGeneratingToast = true }
                                    Task {
                                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                                        withAnimation { showGeneratingToast = false }
                                    }
                                } else {
                                    selectedAlbum = album
                                }
                            }
                            .offset(
                                x: CarouselLayout.activeSideSpacing + baseX + dragOffset,
                                y: topY
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .zIndex(isActive ? 1 : 0)
                        }
                    }
                }
                .frame(width: screenW, height: screenH, alignment: .topLeading)
                .clipped()
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            let t = value.translation.width
                            let atStart = currentIndex == 0 && t > 0
                            let atEnd = currentIndex == visibleAlbums.count - 1 && t < 0
                            dragOffset = (atStart || atEnd) ? t * 0.2 : t
                        }
                        .onEnded { value in
                            handleDragEnded(
                                value: value,
                                albumCount: visibleAlbums.count,
                                dragBaseWidth: dragBaseWidth
                            )
                        }
                )

                AppNavigationBar(style: .transparent) {
                    Image("AppLogo_Home")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 30)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .ignoresSafeArea()
        }
    }

    private func cardWidth(for screenWidth: CGFloat) -> CGFloat {
        max(0, screenWidth - CarouselLayout.horizontalPadding * 2)
    }

    private func cardScale(for screenWidth: CGFloat) -> CGFloat {
        cardWidth(for: screenWidth) / AlbumCardView.Layout.cardWidth
    }

    // 스와이프 종료 시 정착 인덱스 계산 + 위치 복귀 처리
    private func handleDragEnded(
        value: DragGesture.Value,
        albumCount: Int,
        dragBaseWidth: CGFloat
    ) {
        let threshold = dragBaseWidth * CarouselLayout.swipeThresholdRatio
        let velocity = value.predictedEndTranslation.width - value.translation.width

        let nextIndex = MainPageCarouselLogic.nextIndex(
            currentIndex: currentIndex,
            albumCount: albumCount,
            dragOffset: dragOffset,
            velocity: velocity,
            threshold: threshold,
            swipeVelocityThreshold: CarouselLayout.swipeVelocityThreshold
        )

        withAnimation(.spring(
            response: CarouselLayout.springResponse,
            dampingFraction: CarouselLayout.springDamping
        )) {
            currentIndex = nextIndex
            dragOffset = 0
        }

        Task { await viewModel.loadMoreIfNeeded(currentIndex: currentIndex) }
    }

    private func preloadCoverImageURLs(from visibleAlbums: [AlbumCard]) -> [URL] {
        MainPageCarouselLogic.preloadCoverImageURLs(
            albums: visibleAlbums,
            currentIndex: currentIndex,
            preloadRange: CarouselLayout.preloadRange
        )
    }

    // 현재 카드 주변 커버 이미지를 캐시에 미리 적재
    private func preloadCoverImages(urls: [URL]) {
        for url in urls {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            URLSession.shared.dataTask(with: request).resume()
        }
    }
}

// MARK: - MainPageCarouselLogic

enum MainPageCarouselLogic {

    // 현재 카드 주변에서 커버 이미지를 미리 준비할 URL 목록
    static func preloadCoverImageURLs(
        albums: [AlbumCard],
        currentIndex: Int,
        preloadRange: Int
    ) -> [URL] {
        guard !albums.isEmpty else { return [] }

        let lowerBound = max(0, currentIndex - preloadRange)
        let upperBound = min(albums.count - 1, currentIndex + preloadRange)

        let range = lowerBound...upperBound
        var seenURLs: Set<URL> = []
        return range.compactMap { index in
            guard let url = albums[index].coverImageUrl else { return nil }
            guard seenURLs.insert(url).inserted else { return nil }
            return url
        }
    }

    // dragOffset/속도 기준으로 다음에 정착할 카드 인덱스 계산
    static func nextIndex(
        currentIndex: Int,
        albumCount: Int,
        dragOffset: CGFloat,
        velocity: CGFloat,
        threshold: CGFloat,
        swipeVelocityThreshold: CGFloat
    ) -> Int {
        guard albumCount > 0 else { return 0 }

        if dragOffset < -threshold || velocity < -swipeVelocityThreshold {
            return min(currentIndex + 1, albumCount - 1)
        } else if dragOffset > threshold || velocity > swipeVelocityThreshold {
            return max(currentIndex - 1, 0)
        } else {
            return currentIndex
        }
    }
}

// MARK: - AlbumCard -> AlbumDetailDisplayModel 변환

private extension AlbumCard {

    // "yyyy-MM-dd" -> "yyyy년 M월 d일" 포맷팅
    private func formatDate(_ raw: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        let output = DateFormatter()
        output.locale = Locale(identifier: "ko_KR")
        output.dateFormat = "yyyy년 M월 d일"
        guard let date = input.date(from: raw) else { return raw }
        return output.string(from: date)
    }

    func toDisplayModel() -> AlbumDetailDisplayModel {
        AlbumDetailDisplayModel(
            albumId: id,
            title: title ?? "",
            destination: location,
            dateText: "\(formatDate(startDate)) - \(formatDate(endDate))",
            coverImageUrl: coverImageUrl,
            contentState: .empty,
            musicUrl: nil
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("카드 있음") {
    MainPageView(viewModel: MainPageViewModel(albumService: MockAlbumService()))
        .environmentObject(AppState())
}

#Preview("빈 상태") {
    let service = MockAlbumService()
    service.isEmpty = true
    return MainPageView(viewModel: MainPageViewModel(albumService: service))
        .environmentObject(AppState())
}

#Preview("생성 중 앨범") {
    let service = MockAlbumService()
    service.hasGeneratingAlbum = true
    service.musicReadyAfterAttempts = 2
    return MainPageView(viewModel: MainPageViewModel(albumService: service))
        .environmentObject(AppState())
}
#endif
