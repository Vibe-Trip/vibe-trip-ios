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
    
    init(viewModel: MainPageViewModel = MainPageViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Carousel State (UI 전용)
    
    @State private var currentIndex: Int   = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool    = false
    
    // MARK: - 캐러셀 Layout Constants
    
    private enum CarouselLayout {
        static let cardWidth: CGFloat              = AlbumCardView.Layout.cardWidth
        static let cardGap: CGFloat                = 17
        static let activeTopSpacing: CGFloat       = 68
        static let inactiveTopSpacing: CGFloat     = 84   // active와 16pt 차이
        static let activeSideSpacing: CGFloat      = 40
        static let swipeThresholdRatio: CGFloat    = 0.35
        static let swipeVelocityThreshold: CGFloat = 200
        static let springResponse: Double          = 0.45
        static let springDamping: Double           = 0.82
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if viewModel.albumCount == 0 {
                emptyContent
            } else {
                carouselView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await viewModel.loadAlbums() }
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
                    ForEach((0..<viewModel.albumCount).reversed(), id: \.self) { index in
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
                            
                            AlbumCardView()
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
                            let atEnd    = currentIndex == viewModel.albumCount - 1 && t < 0
                            dragOffset   = (atStart || atEnd) ? t * 0.2 : t
                        }
                        .onEnded { value in
                            isDragging    = false
                            let threshold = CarouselLayout.cardWidth * CarouselLayout.swipeThresholdRatio
                            let velocity  = value.predictedEndTranslation.width
                            - value.translation.width
                            
                            if dragOffset < -threshold || velocity < -CarouselLayout.swipeVelocityThreshold {
                                if currentIndex < viewModel.albumCount - 1 { currentIndex += 1 }
                            } else if dragOffset > threshold || velocity > CarouselLayout.swipeVelocityThreshold {
                                if currentIndex > 0 { currentIndex -= 1 }
                            }
                            
                            withAnimation(.spring(
                                response: CarouselLayout.springResponse,
                                dampingFraction: CarouselLayout.springDamping
                            )) {
                                dragOffset = 0
                            }
                        }
                )
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Preview

#Preview("카드 있음") {
    MainPageView(viewModel: MainPageViewModel(albumCount: 4))
}

#Preview("빈 상태") {
    MainPageView()
}
