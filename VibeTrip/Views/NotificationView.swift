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
    // 탭바 레드 닷 제거 및 알림 탭 네비게이션
    @EnvironmentObject private var appState: AppState

    init(viewModel: NotificationViewModel = NotificationViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Layout Constants

    private enum Layout {
        static let headerHeight: CGFloat        = 44
        static let emptyTitleSize: CGFloat      = 22
        static let emptyBodySize: CGFloat       = 16
        static let emptyContentSpacing: CGFloat = 8
        static let emptySymbolSize: CGFloat     = 120
        static let emptyTextPadding: CGFloat    = 39
        static let tabBarHeight: CGFloat        = 64
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
                contentArea
                AppNavigationBar(largeTitle: "알림", style: .blurAlways)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: [.top, .bottom])

            // 토스트 메시지 오버레이
            // TODO: 표시 유무 정하기
//            if let message = viewModel.toastMessage {
//                AppToastView(message: message, systemImageName: "checkmark.circle")
//                    .padding(.bottom, Layout.toastBottomPadding)
//                    .transition(.move(edge: .bottom).combined(with: .opacity))
//                    .animation(.easeInOut(duration: 0.3), value: viewModel.toastMessage)
//            }
        }
        // 알림 목록 로드
        .task {
            await viewModel.loadNotifications()
        }
        .onAppear {
            // 탭 진입 시 레드 닷 제거
            appState.hasUnreadNotifications = false
            // 탭 진입 시 고착된 갱신 신호 초기화: 이후 추가 푸시 수신 시 onChange 정상 발동 보장
            appState.needsNotificationRefresh = false
        }
        .onChange(of: appState.needsNotificationRefresh) { _, needsRefresh in
            guard needsRefresh else { return }
            appState.needsNotificationRefresh = false
            Task {
                await viewModel.loadNotifications()
                // 알림 탭에 있는 상태에서는 레드닷이 다시 켜지지 않도록 유지
                appState.hasUnreadNotifications = false
            }
        }
    }

    // MARK: - Content Area

    // 알림 유무로 분기
    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isEmpty {
            emptyStateView
        } else {
            notificationListView
        }
    }

    // 헤더 여백 확보
    private var headerSpacer: some View {
        Color.clear.frame(height: safeTop + Layout.headerHeight)
    }

    // UIApplication 기반 safeArea top 조회
    private var safeTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.top ?? 0
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
        .safeAreaInset(edge: .top) { headerSpacer }
    }

    private var emptyContent: some View {
        VStack(alignment: .center, spacing: Layout.emptyContentSpacing) {

            // 빈 상태 심볼
            Image("Alarm_Placeholder")
                .resizable()
                .scaledToFit()
                .frame(width: Layout.emptySymbolSize, height: Layout.emptySymbolSize)

            // 메인 텍스트
            Text("새로운 소식이 없어요.")
                .font(Font.setPretendard(weight: .semiBold, size: Layout.emptyTitleSize))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("GrayScale/500"))
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

    // MARK: - 알림 리스트

    private var notificationListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.notifications) { item in
                    NotificationRow(
                        item: item,
                        onDelete: {
                            // 휴지통 버튼 탭 시, 해당 알림 삭제
                            Task { await viewModel.deleteNotification(id: item.id) }
                        },
                        onTap: {
                            // 알림 탭 시, 해당 뷰로 이동
                            handleNotificationTap(item)
                        }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .safeAreaInset(edge: .top) { headerSpacer }
    }

    // MARK: - 알림 탭 네비게이션

    // 알림 종류에 따라 이동할 화면을 AppState에 전달
    // MainTabBarView: 감지 및 화면 전환 처리
    private func handleNotificationTap(_ item: NotificationItem) {
        // 알림 탭 시,읽음 처리: 배경색 제거
        viewModel.markAsRead(id: item.id)

        switch item.type {
        case .generating:
            // TODO: 서버 연동 시, 해당 앨범의 로딩 페이지 이동
            // 현재는 새 MakeAlbumView를 열며, 이전 로딩 상태는 복원되지 않음
            // MakeAlbumViewModel: AppState or 상위 레벨에서 보존 필요
            appState.pendingNotificationAction = .openAlbumCreationLoading

        case .completed(let albumId):
            appState.pendingNotificationAction = .openAlbumDetail(albumId: albumId)

        case .failed:
            // 앨범 생성 페이지로 이동
            appState.pendingNotificationAction = .openMakeAlbum
        }
    }
}

// MARK: - NotificationRow

private struct NotificationRow: View {

    let item: NotificationItem
    let onDelete: () -> Void
    let onTap: () -> Void

    private enum Layout {
        static let horizontalPadding: CGFloat = 20
        static let verticalPadding: CGFloat   = 16
        static let innerSpacing: CGFloat      = 10
        static let contentSpacing: CGFloat    = 4
        static let bodyLineSpacing: CGFloat   = 4
        static let titleSize: CGFloat         = 16
        static let bodySize: CGFloat          = 14
    }

    var body: some View {
        HStack(alignment: .top, spacing: Layout.innerSpacing) {

            // 알림 텍스트 영역
            VStack(alignment: .leading, spacing: Layout.contentSpacing) {
                /// 제목
                Text(item.title)
                    .font(Font.setPretendard(weight: .semiBold, size: Layout.titleSize))
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                /// 본문
                Text(item.body)
                    .font(Font.setPretendard(weight: .regular, size: Layout.bodySize))
                    .foregroundStyle(Color("GrayScale/500"))
                    .lineSpacing(Layout.bodyLineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true) // 본문 줄바꿈 허용

                /// 경과 시간
                Text(timeAgo(item.createdAt))
                    .font(Font.setPretendard(weight: .regular, size: Layout.bodySize))
                    .foregroundStyle(Color("GrayScale/500"))
            }

            // 알림 삭제 버튼
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12.4, height: 14.2)
                    .foregroundStyle(Color("GrayScale/300"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .frame(maxWidth: .infinity)
        // 읽음: 흰 배경, 안읽음: appPrimary100
        .background(item.isRead ? Color.white : Color("appPrimary100"))
        // 알림 항목 구분선
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color("GrayScale/100"))
                .frame(height: 1)
        }
        .contentShape(Rectangle()) // 탭 인식 범위 확대
        .onTapGesture { onTap() }
    }

    // createdAt -> 시간 변환 포맷
    private func timeAgo(_ date: Date) -> String {
        let elapsed = max(0, Int(Date().timeIntervalSince(date)))
        if elapsed < 60 { return "지금" }
        if elapsed < 3600 {
            let minutes = elapsed / 60
            return "\(minutes)분 전"
        }
        if elapsed < 86_400 {
            let hours = elapsed / 3600
            return "\(hours)시간 전"
        }
        if elapsed < 604_800 {
            let days = elapsed / 86_400
            return "\(days)일 전"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("빈 상태") {
    NotificationView()
        .environmentObject(AppState())
}

#if DEBUG
#Preview("알림 있음") {
    let vm = NotificationViewModel(previewNotifications: [
        NotificationItem(
            id: "1",
            type: .generating,
            title: "앨범을 생성하는 중입니다.",
            body: "나만의 음악이 곧 탄생합니다. 완료되면 바로 알려드릴게요.",
            createdAt: Date(timeIntervalSinceNow: -120),
            isRead: false
        ),
        NotificationItem(
            id: "2",
            type: .completed(albumId: "album-123"),
            title: "앨범 생성 완료!",
            body: "세상에 하나뿐인 '리트립 여행'이 완성되었습니다. 지금 바로 완성된 음악을 감상해 보세요.",
            createdAt: Date(timeIntervalSinceNow: -3600),
            isRead: true
        ),
        NotificationItem(
            id: "3",
            type: .failed,
            title: "앨범 생성에 실패했습니다.",
            body: "[오류 원인]으로 생성에 실패했습니다. 앨범 만들기를 다시 시도해 주세요",
            createdAt: Date(timeIntervalSinceNow: -7200),
            isRead: true
        )
    ])
    NotificationView(viewModel: vm)
        .environmentObject(AppState())
}
#endif
