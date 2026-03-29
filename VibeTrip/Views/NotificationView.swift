//
//  NotificationView.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI

// MARK: - NotificationView

struct NotificationView: View {

    // MARK: - ViewModel

    @StateObject private var viewModel: NotificationViewModel

    init(viewModel: NotificationViewModel = NotificationViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Layout Constants

    private enum Layout {
        static let headerHeight: CGFloat        = 44
        static let horizontalPadding: CGFloat   = 20
        static let titleFontSize: CGFloat       = 24
        static let emptyTitleSize: CGFloat      = 22
        static let emptyBodySize: CGFloat       = 16
        static let emptyContentSpacing: CGFloat = 8
        static let emptySymbolSize: CGFloat     = 120
        static let emptyTextPadding: CGFloat    = 39
        static let toastBottomPadding: CGFloat  = 100
        static let tabBarHeight: CGFloat        = 64
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                headerBar
                contentArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .bottom)

            // 토스트 메시지 오버레이
            if let message = viewModel.toastMessage {
                AppToastView(message: message, systemImageName: "checkmark.circle")
                    .padding(.bottom, Layout.toastBottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.toastMessage)
            }
        }
        .task { await viewModel.loadNotifications() }
        .onAppear { viewModel.markAllAsRead() }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Text("알림")
                .font(Font.setPretendard(weight: .semiBold, size: Layout.titleFontSize))
                .foregroundStyle(Color.textPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: Layout.headerHeight)
        .padding(.horizontal, Layout.horizontalPadding)
        .background(Color.white)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isEmpty {
            emptyStateView
        } else {
            // TODO: 알림 리스트 구현 예정
            notificationListPlaceholder
        }
    }

    // MARK: - 빈 상태 UI

    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer()
            emptyContent
            Spacer()
        }
        .padding(.bottom, Layout.tabBarHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyContent: some View {
        VStack(alignment: .center, spacing: Layout.emptyContentSpacing) {

            // 빈 상태 심볼
            Image("EmptyAlarm")
                .resizable()
                .scaledToFit()
                .frame(width: Layout.emptySymbolSize, height: Layout.emptySymbolSize)

            // 메인 텍스트
            Text("새로운 소식이 없어요.")
                .font(Font.setPretendard(weight: .semiBold, size: Layout.emptyTitleSize))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, Layout.emptyTextPadding)
                .frame(maxWidth: .infinity, alignment: .center)

            // 서브 텍스트
            Text("소식이 생기면 알려드릴게요!")
                .font(Font.setPretendard(weight: .medium, size: Layout.emptyBodySize))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.placeholderText)
                .padding(.horizontal, Layout.emptyTextPadding)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 알림 리스트 Placeholder

    private var notificationListPlaceholder: some View {
        // TODO: 알림 리스트 구현
        EmptyView()
    }
}

// MARK: - Preview

#Preview("빈 상태") {
    NotificationView()
}

#Preview("알림 있음") {
    let vm = NotificationViewModel()
    return NotificationView(viewModel: vm)
}
