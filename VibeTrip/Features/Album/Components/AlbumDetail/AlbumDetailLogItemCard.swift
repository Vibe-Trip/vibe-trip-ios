//
//  AlbumDetailLogItemCard.swift
//  VibeTrip
//
//  Created by CHOI on 6/24/26.
//

import SwiftUI

private final class CardBottomTracker {
    var contentMaxY: CGFloat = 0   // 카드 하단의 콘텐츠 좌표계 기준 y
}

// MARK: - AlbumDetailLogItemCard
// 개별 로그 아이템 카드

struct AlbumDetailLogItemCard: View {
    let entry: AlbumLogEntry
    let isLast: Bool
    let onLastAppear: (() async -> Void)?
    let onDeleteLog: (Int) -> Void
    let onEdit: (AlbumLogEntry) -> Void
    // 방금 저장한 로그처럼 이미지 응답이 비어 있을 때 슬라이더 자리에 스켈레톤을 그릴지 여부
    let showSkeletonIfNoImages: Bool
    let onRevealCard: (Int, CGFloat) -> Void

    // 로그 옵션 팝업 표시 여부
    @State private var isMenuVisible: Bool = false
    // 카드 하단의 콘텐츠 좌표계 기준 y (가림 판단용)
    @State private var bottomTracker = CardBottomTracker()

    private enum Constants {
        static let dateFontSize: CGFloat = 14
        static let menuIconSize: CGFloat = 16
        static let menuTouchTarget: CGFloat = 44
        static let dateToImageSpacing: CGFloat = 8
        static let contentSpacing: CGFloat = 12
        static let menuAnimationDuration: Double = 0.15
        static let menuTopOffset: CGFloat = 26
        static let menuTrailingPadding: CGFloat = 17
        static let labelColor = Color(red: 0.74, green: 0.75, blue: 0.76)
        // 펼침 애니메이션이 끝나 카드 높이가 확정된 뒤 스크롤하도록 약간 지연
        static let expandScrollDelay: Double = 0.3
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
            VStack(alignment: .leading, spacing: 0) {
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
                    .padding(.trailing, -4)
                }
                
                // 이미지 슬라이더: 이미지 있을 때 본 슬라이더, 응답 대기 중인 로그는 스켈레톤
                if !entry.images.isEmpty {
                    AlbumDetailLogImageSlider(images: entry.images)
                        .padding(.top, Constants.dateToImageSpacing)
                } else if showSkeletonIfNoImages {
                    AlbumDetailLogImageSkeleton()
                        .padding(.top, Constants.dateToImageSpacing)
                }
                
                // 텍스트 + 더보기/접기
                AlbumDetailLogTextSection(text: entry.description, onExpand: {
                    // 펼침 레이아웃이 잡힌 뒤, 카드 하단 위치와 함께 자동 스크롤 요청
                    DispatchQueue.main.asyncAfter(deadline: .now() + Constants.expandScrollDelay) {
                        onRevealCard(entry.id, bottomTracker.contentMaxY)
                    }
                })
                .padding(.top, Constants.contentSpacing)
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
                        isMenuVisible = false
                        onEdit(entry)
                    },
                    onDeleteLog: {
                        withAnimation(.easeInOut(duration: Constants.menuAnimationDuration)) {
                            isMenuVisible = false
                        }
                        onDeleteLog(entry.id)
                    }
                )
                .padding(.top, Constants.menuTopOffset)
                .padding(.trailing, Constants.menuTrailingPadding)
            }
        }
        // 카드 하단의 콘텐츠 기준 y 추적 (가림 판단용)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .named(albumDetailScrollSpace)).maxY
        } action: { newValue in
            bottomTracker.contentMaxY = newValue
        }
        .onAppear {
            guard isLast else { return }
            Task { await onLastAppear?() }
        }
    }
}

