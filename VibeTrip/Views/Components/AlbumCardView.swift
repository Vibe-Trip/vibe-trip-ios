//
//  AlbumCardView.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI

// MARK: - AlbumCardView

struct AlbumCardView: View {

    private let album: AlbumCard
    // false: 음악 생성 중 -> skeleton 표시 + 상세 진입 차단
    private let isReady: Bool
    // TODO: 서버 연동: 미리보기 이미지 받아오기
    private let extraPhotoCount: Int

    init(album: AlbumCard, isReady: Bool, extraPhotoCount: Int = 5) {
        self.album = album
        self.isReady = isReady
        self.extraPhotoCount = extraPhotoCount
    }
    
    // MARK: - Layout Constants
    
    enum Layout {
        static let cardWidth: CGFloat          = 322
        static let cardHeight: CGFloat         = 600
        static let coverImageHeight: CGFloat   = 460
        static let infoAreaHeight: CGFloat     = 140
        static let cardCornerRadius: CGFloat   = 18
        
        static let thumbnailSize: CGFloat      = 36
        static let thumbnailOverlap: CGFloat   = 12
        static let thumbnailTopPadding: CGFloat      = 16
        static let thumbnailTrailingPadding: CGFloat = 16
        
        static let cardShadowOpacity: CGFloat    = 0.06
        static let cardShadowRadius: CGFloat    = 1.5
        
        static let textTopPadding: CGFloat      = 58
        static let textLeadingPadding: CGFloat  = 16
        static let textSpacing: CGFloat         = 4
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .top) {
            coverImage
            infoOverlay
        }
        .frame(width: Layout.cardWidth, height: Layout.cardHeight)
        .background(Color.white)
        .cornerRadius(Layout.cardCornerRadius)
        .shadow(color: .black.opacity(Layout.cardShadowOpacity), radius: Layout.cardShadowRadius, x: 0, y: 1)
    }
    
    // MARK: - 대표 이미지
    
    private var coverImage: some View {
        // 이미지 로드 중 or 실패 시 placeholder 표시
        AsyncImage(url: album.coverImageUrl) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()    /// 비율 유지 채택 시  ->  .scaledToFill()
            default:
                Color.placeholderSymbol
            }
        }
        .frame(width: Layout.cardWidth, height: Layout.coverImageHeight)
        .clipped()
        .cornerRadius(Layout.cardCornerRadius)
        .shadow(color: .black.opacity(0.1), radius: 7.5, x: 0, y: 5)
    }
    
    // MARK: - Info Overlay
    
    private var infoOverlay: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: Layout.coverImageHeight)
            
            ZStack(alignment: .topLeading) {
                // 썸네일 row (우측 상단 고정, 추가 사진 없으면 숨김)
                HStack {
                    Spacer()
                    thumbnailRow
                }
                .padding(.top, Layout.thumbnailTopPadding)
                .padding(.trailing, Layout.thumbnailTrailingPadding)
                .opacity(extraPhotoCount > 0 ? 1 : 0)
                
                // 텍스트 그룹 (커버 이미지 하단 기준 고정 위치)
                VStack(alignment: .leading, spacing: Layout.textSpacing) {
                    // isReady: false -> 음악 생성 중, skeleton 표시
                    if isReady {
                        Text(album.title ?? "")
                            .font(Font.setPretendard(weight: .semiBold, size: 20))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                    } else {
                        SkeletonTitleView()
                    }

                    Text(album.location)
                        .font(Font.setPretendard(weight: .medium, size: 12))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                    
                    Text("\(album.startDate) ~ \(album.endDate)")
                        .font(Font.setPretendard(weight: .medium, size: 12))
                        .kerning(0.2)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
                .padding(.top, Layout.textTopPadding)
                .padding(.leading, Layout.textLeadingPadding)
            }
            .frame(width: Layout.cardWidth, height: Layout.infoAreaHeight, alignment: .top)
        }
    }
    
    // MARK: - Thumbnail Row
    
    private var thumbnailRow: some View {
        // extraPhotoCount 개수 별 표시
        /// 사진 1장 : 원형 1개 / 2장 : 원형 2개 / 3장 : 원형 3개 / 4장 이상 : 원형 3개 + +N 배지
        let photoCircleCount = min(extraPhotoCount, 3)
        let remainingCount = extraPhotoCount - 3
        
        return HStack(spacing: -Layout.thumbnailOverlap) {
            ForEach(0..<photoCircleCount, id: \.self) { _ in
                Circle()
                    .fill(Color.placeholderSymbol)
                    .frame(width: Layout.thumbnailSize, height: Layout.thumbnailSize)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    .shadow(color: .black.opacity(0.13), radius: 2.5, x: 0, y: 3)
            }
            
            // +N 배지
            if extraPhotoCount >= 4 {
                ZStack {
                    Circle()
                        .fill(Color.appPrimary)
                    Text("+\(remainingCount)")
                        .font(Font.setPretendard(weight: .semiBold, size: 12))
                        .foregroundStyle(Color.white)
                }
                .frame(width: Layout.thumbnailSize, height: Layout.thumbnailSize)
                .overlay(Circle().stroke(Color.white, lineWidth: 1))
            }
        }
    }
}

// MARK: - SkeletonTitleView

// 타이틀 생성 중 표시용 skeleton 뷰 
private struct SkeletonTitleView: View {
    var body: some View {
        ZStack {}
            .frame(width: 220, height: 26)
            .background(.black.opacity(0.08))
            .cornerRadius(999)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("생성 완료") {
    AlbumCardView(album: AlbumCard.mockItems[0], isReady: true)
}

#Preview("음악 생성 중") {
    // mockItems[3]: title nil -> skeleton 상태 확인용
    AlbumCardView(album: AlbumCard.mockItems[3], isReady: false)
}
#endif
