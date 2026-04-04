//
//  MainPageView.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI

// MARK: - MainPageView

struct MainPageView: View {
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel: MainPageViewModel
    @EnvironmentObject private var appState: AppState
    
    init(viewModel: MainPageViewModel = MainPageViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Carousel State (UI 전용)

    @State private var currentIndex: Int        = 0
    @State private var dragOffset: CGFloat      = 0
    @State private var isDragging: Bool         = false
    @State private var selectedAlbum: AlbumCard? = nil

    // 신고 완료 토스트
    @State private var showReportToast: Bool = false
    
    // MARK: - 캐러셀 Layout Constants
    
    private enum CarouselLayout {
        static let cardWidth: CGFloat              = AlbumCardView.Layout.cardWidth
        static let cardGap: CGFloat                = 17
        static let activeTopSpacing: CGFloat       = 68
        static let inactiveTopSpacing: CGFloat     = 84
        static let activeSideSpacing: CGFloat      = 40
        static let swipeThresholdRatio: CGFloat    = 0.35
        static let swipeVelocityThreshold: CGFloat = 200
        static let springResponse: Double          = 0.45
        static let springDamping: Double           = 0.82
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if viewModel.albums.isEmpty {
                emptyContent
            } else {
                carouselView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await viewModel.loadAlbums() }
        .fullScreenCover(item: $selectedAlbum) { album in
            AlbumDetailView(
                displayModel: album.toDisplayModel(),
                onBackTap: { selectedAlbum = nil },
                onDeleteAlbumTap: {
                    selectedAlbum = nil
                    currentIndex = 0
                    // 삭제 후 목록 재조회
                    Task { await viewModel.loadAlbums() }
                    // 삭제 완료 후 홈 탭으로 강제 이동
                    appState.pendingTabNavigation = .home
                },
                onReportTap: {
                    selectedAlbum = nil  // fullScreenCover 닫기 (메인 복귀)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showReportToast = true
                        }
                    }
                }
            )
        }
        .overlay(alignment: .bottom) {
            if showReportToast {
                AppToastView(message: "신고처리가 완료되었습니다.")
                    .padding(.bottom, 88)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showReportToast = false
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showReportToast)
    }
    
    // MARK: - 빈 상태 UI
    
    private var emptyContent: some View {
        VStack(spacing: 0) {
            Spacer()
            emptyStateView
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    
    // MARK: - 캐러셀
    
    private var carouselView: some View {
        GeometryReader { geo in
            let safeTop      = geo.safeAreaInsets.top
            let safeBottom   = geo.safeAreaInsets.bottom
            let screenW      = geo.size.width
            let screenH      = geo.size.height + safeTop + safeBottom
            
            let cardStep     = CarouselLayout.cardWidth + CarouselLayout.cardGap
            let activeTopY   = safeTop + CarouselLayout.activeTopSpacing
            let inactiveTopY = safeTop + CarouselLayout.inactiveTopSpacing
            let verticalDiff = inactiveTopY - activeTopY
            let progress     = min(abs(dragOffset) / CarouselLayout.cardWidth, 1.0)
            
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                ZStack {
                    ForEach((0..<viewModel.albums.count).reversed(), id: \.self) { index in
                        let rel        = index - currentIndex
                        let isActive   = rel == 0
                        let isNext     = rel == 1
                        let isEntering = (isNext && dragOffset < 0) || (rel == -1 && dragOffset > 0)
                        
                        if abs(rel) <= 1 {
                            let baseX: CGFloat = {
                                if isActive { return 0 }
                                if isNext   { return  cardStep }
                                return             -cardStep
                            }()
                            
                            let topY: CGFloat = {
                                if isActive   { return activeTopY   + verticalDiff * progress }
                                if isEntering { return inactiveTopY - verticalDiff * progress }
                                return inactiveTopY
                            }()
                            
                            AlbumCardView(album: viewModel.albums[index])
                                .onTapGesture {
                                    if isActive { selectedAlbum = viewModel.albums[index] }
                                }
                                .offset(
                                    x: CarouselLayout.activeSideSpacing + baseX + dragOffset,
                                    y: topY
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .zIndex(isActive ? 1 : 0)
                                .animation(
                                    isDragging
                                    ? nil
                                    : .spring(
                                        response: CarouselLayout.springResponse,
                                        dampingFraction: CarouselLayout.springDamping
                                    ),
                                    value: dragOffset
                                )
                                .animation(
                                    .spring(
                                        response: CarouselLayout.springResponse,
                                        dampingFraction: CarouselLayout.springDamping
                                    ),
                                    value: currentIndex
                                )
                        }
                    }
                }
                .frame(width: screenW, height: screenH, alignment: .topLeading)
                .clipped()
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            isDragging   = true
                            let t        = value.translation.width
                            let atStart  = currentIndex == 0 && t > 0
                            let atEnd    = currentIndex == viewModel.albums.count - 1 && t < 0
                            dragOffset   = (atStart || atEnd) ? t * 0.2 : t
                        }
                        .onEnded { value in
                            isDragging    = false
                            let threshold = CarouselLayout.cardWidth * CarouselLayout.swipeThresholdRatio
                            let velocity  = value.predictedEndTranslation.width
                            - value.translation.width
                            
                            if dragOffset < -threshold || velocity < -CarouselLayout.swipeVelocityThreshold {
                                if currentIndex < viewModel.albums.count - 1 { currentIndex += 1 }
                            } else if dragOffset > threshold || velocity > CarouselLayout.swipeVelocityThreshold {
                                if currentIndex > 0 { currentIndex -= 1 }
                            }
                            
                            withAnimation(.spring(
                                response: CarouselLayout.springResponse,
                                dampingFraction: CarouselLayout.springDamping
                            )) {
                                dragOffset = 0
                            }

                            Task { await viewModel.loadMoreIfNeeded(currentIndex: currentIndex) }
                        }
                )

                // MARK: - 네비게이션 바 (로고)
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
            title: title,
            destination: location,
            dateText: "\(formatDate(startDate)) - \(formatDate(endDate))",
            coverImageUrl: coverImageUrl,
            contentState: .empty,
            isMusicPlaying: false
        )
    }
}

// MARK: - Preview

#Preview("카드 있음") {
    MainPageView(viewModel: MainPageViewModel(albumService: MockAlbumService()))
}

#Preview("빈 상태") {
    let service = MockAlbumService()
    service.isEmpty = true
    return MainPageView(viewModel: MainPageViewModel(albumService: service))
}
