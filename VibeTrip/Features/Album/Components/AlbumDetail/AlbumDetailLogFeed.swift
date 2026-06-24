//
//  AlbumDetailLogFeed.swift
//  VibeTrip
//
//  Created by CHOI on 6/24/26.
//

import SwiftUI

// 가림 판단용: 콘텐츠 좌표계 이름 + 카드 하단 위치 보관
let albumDetailScrollSpace = "albumDetailScroll"

// MARK: - AlbumDetailLogFeedSection

struct AlbumDetailLogFeedSection: View {

    @ObservedObject var viewModel: AlbumDetailViewModel
    let onEdit: (AlbumLogEntry) -> Void
    let onRevealCard: (Int, CGFloat) -> Void // (카드 id, 카드 하단 콘텐츠 y) — 가릴 때만 스크롤
    
    private enum Constants {
        static let horizontalPadding: CGFloat = 20
        static let topPadding: CGFloat = 4
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
                    },
                    onDeleteLog: { logId in
                        viewModel.requestDeleteLog(id: logId)
                    },
                    onEdit: onEdit,
                    awaitingImageLogIds: viewModel.awaitingImageLogIds,
                    onRevealCard: onRevealCard
                )
            }
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.top, Constants.topPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - AlbumDetailLogDateGroup
// 날짜별 로그 그룹 (헤더 + 카드 목록)

struct AlbumDetailLogDateGroup: View {
    let label: String
    let entries: [AlbumLogEntry]
    let lastEntryId: Int?
    let onLastAppear: (() async -> Void)?
    let onDeleteLog: (Int) -> Void
    let onEdit: (AlbumLogEntry) -> Void
    let awaitingImageLogIds: Set<Int>
    let onRevealCard: (Int, CGFloat) -> Void

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
                    onLastAppear: onLastAppear,
                    onDeleteLog: onDeleteLog,
                    onEdit: onEdit,
                    showSkeletonIfNoImages: awaitingImageLogIds.contains(entry.id),
                    onRevealCard: onRevealCard
                )
                .id(entry.id)   // 펼침 시 이 카드로 scrollTo 하기 위한 앵커
            }
        }
    }
}

