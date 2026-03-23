//
//  AlbumCardView.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI

// MARK: - AlbumCardView

struct AlbumCardView: View {
    
    // TODO: 실제 데이터 연결 시 album.photos.count - 1 (커버 이미지 제외한 추가 사진 수)로 교체
    private let extraPhotoCount: Int
    
    // 테스트용 사진 개수
    init(extraPhotoCount: Int = 5) {
        self.extraPhotoCount = extraPhotoCount
    }
    
    // MARK: - Layout Constants
    
    private enum Layout {
        static let cardWidth: CGFloat          = 322
        static let cardHeight: CGFloat         = 600
        static let coverImageHeight: CGFloat   = 460
        static let infoAreaHeight: CGFloat     = 140
        static let cardCornerRadius: CGFloat   = 16
        
        static let thumbnailSize: CGFloat      = 36
        static let thumbnailOverlap: CGFloat   = 12
        static let thumbnailTopPadding: CGFloat      = 16
        static let thumbnailTrailingPadding: CGFloat = 16
        
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
    }
    
    // MARK: - 대표 이미지
    
    private var coverImage: some View {
        // TODO: AsyncImage(url: album.coverImageUrl)
        Rectangle()
            .foregroundColor(.clear)
            .frame(width: Layout.cardWidth, height: Layout.coverImageHeight)
            .background(
                Color.placeholderSymbol
            )
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
                    Text("오사카 도톤보리") // TODO: album.title
                        .font(Font.setPretendard(weight: .semiBold, size: 20))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    
                    Text("일본 오사카") // TODO: album.location
                        .font(Font.setPretendard(weight: .medium, size: 12))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                    
                    Text("2026.01.12 ~ 2026.01.15") // TODO: "\(album.startDate) ~ \(album.endDate)"
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
        let remainingCount = extraPhotoCount - 3  // TODO: 실제 데이터 연결 시 album.photos.count - 4
        
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

// MARK: - Preview

#Preview {
    AlbumCardView()
}
