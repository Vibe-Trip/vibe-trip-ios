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

    init(album: AlbumCard, isReady: Bool) {
        self.album = album
        self.isReady = isReady
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
                Image("AlbumCard_Placeholder")
                    .resizable()
                    .scaledToFill()
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
                // 썸네일 row (우측 상단 고정, 미리보기 이미지 없으면 숨김)
                HStack {
                    Spacer()
                    thumbnailRow
                }
                .padding(.top, Layout.thumbnailTopPadding)
                .padding(.trailing, Layout.thumbnailTrailingPadding)
                .opacity(album.previewLogImages.isEmpty ? 0 : 1)

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
        let displayImages = Array(album.previewLogImages.prefix(3))

        return HStack(spacing: -Layout.thumbnailOverlap) {
            ForEach(Array(displayImages.enumerated()), id: \.offset) { _, preview in
                AsyncImage(url: preview.imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        Circle().fill(Color.placeholderSymbol)
                    @unknown default:
                        Circle().fill(Color.placeholderSymbol)
                    }
                }
                .frame(width: Layout.thumbnailSize, height: Layout.thumbnailSize)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                .shadow(color: .black.opacity(0.13), radius: 2.5, x: 0, y: 3)
            }

            // +N 배지: 전체 이미지 수가 4개 이상일 때 항상 표시 (이미지 3개 제외한 나머지)
            if album.logImageCount >= 4 {
                ZStack {
                    Circle().fill(Color.appPrimary)
                    Text("+\(album.logImageCount - 3)")
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
    // mockItems[0]: previewLogImages 2개, logImageCount 5 -> 원형 2개 + "+3" 배지
    AlbumCardView(album: AlbumCard.mockItems[0], isReady: true)
}

#Preview("생성 완료 (배지 없음)") {
    // mockItems[1]: previewLogImages 3개, logImageCount 3 -> 원형 3개, 배지 없음
    AlbumCardView(album: AlbumCard.mockItems[1], isReady: true)
}

#Preview("음악 생성 중") {
    // mockItems[3]: title nil → skeleton 상태 확인용
    AlbumCardView(album: AlbumCard.mockItems[3], isReady: false)
}
#endif
