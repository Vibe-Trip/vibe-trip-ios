//
//  AlbumDetailLogImageSlider.swift
//  VibeTrip
//
//  Created by CHOI on 6/24/26.
//

import SwiftUI
import UIKit

// MARK: - AlbumDetailLogImageSlider
// 이미지 슬라이더

struct AlbumDetailLogImageSlider: View {
    let images: [AlbumLogImage]
    
    @State private var currentIndex: Int = 0
    
    private enum Constants {
        static let cornerRadius: CGFloat = 16
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
                                .resizable()    /// 비율 유지 채택 시  ->  .scaledToFill()
                        default:
                            // 로드 중 / 실패 시 placeholder 표시
                            ZStack {
                                Color.secondary.opacity(0.12)
                                Image(systemName: "photo")
                                    .font(.system(size: Constants.placeholderIconSize))
                                    .foregroundStyle(Color("GrayScale/200"))
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
                                index == currentIndex ? Color("appPrimary/400") : Color.white
                            )
                        // 페이지컨트롤dot -> pageControl shadow
                            .appShadow(.pageControl)
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

// MARK: - AlbumDetailLogImageSkeleton
// 이미지 응답 대기 중인 로그 카드의 슬라이더 자리에 표시하는 shimmer placeholder
// 슬라이더와 동일 치수로 그려 카드 레이아웃이 흔들리지 않게 함

struct AlbumDetailLogImageSkeleton: View {
    private enum Constants {
        static let cornerRadius: CGFloat = 16
        static var sliderHeight: CGFloat {
            (UIScreen.main.bounds.width - 40) * 3 / 4
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: Constants.cornerRadius)
            .fill(Color.secondary.opacity(0.12))
            .frame(maxWidth: .infinity)
            .frame(height: Constants.sliderHeight)
            .shimmering(shape: RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }
}

