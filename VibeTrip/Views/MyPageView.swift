//
//  MyPageView.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI
import SafariServices

// MARK: - Safari 시트 아이템 래퍼

private struct SafariItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - MyPageView

struct MyPageView: View {
    
    @StateObject private var viewModel = MyPageViewModel()
    @EnvironmentObject private var appState: AppState
    
    // 고객지원 링크: Safari 시트
    @State private var safariItem: SafariItem?
    
    private enum Constants {
        static let avatarSize: CGFloat = 120
        static let avatarBackgroundColor = Color(red: 0.92, green: 0.92, blue: 0.98)
        static let avatarSymbolColor = Color(red: 0.67, green: 0.68, blue: 0.93)
        static let rowHeight: CGFloat = 52
        static let toastBottomPadding: CGFloat = 40
        static let toastAnimationDuration: Double = 3.0
        static let statCardCornerRadius: CGFloat = 12
        static let statCardSpacing: CGFloat = 10
        static let statCardShadowOpacity: Double = 0.06
        static let statCardShadowRadius: CGFloat = 3
        static let statCardShadowY: CGFloat = 1
        static let settingsGroupSpacing: CGFloat = 16
        static let settingsTopPadding: CGFloat = 40
        static let sectionHeaderBottomPadding: CGFloat = 4
        static let contentBottomPadding: CGFloat = 112
        static let secondaryLabelColor = Color(red: 0.6, green: 0.62, blue: 0.64)
        // TODO: 실제 URL로 교체 필요
        static let termsURL = URL(string: "https://example.com/terms")!
        static let privacyURL = URL(string: "https://example.com/privacy")!
        static let openSourceURL = URL(string: "https://example.com/licenses")!
        static let supportEmail = "Retrip@gmail.com"
        static let mailSubject = "[VibeTrip 문의]"
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        profileSection
                        statsSection
                        VStack(spacing: Constants.settingsGroupSpacing) {
                            settingsSection
                            supportSection
                            accountSection
                        }
                        .padding(.top, Constants.settingsTopPadding)
                        .padding(.bottom, Constants.contentBottomPadding)
                    }
                }
                .background(Color.white)
                
                // 화면 하단 피드백 토스트
                if let message = viewModel.toastMessage {
                    AppToastView(message: message)
                        .padding(.bottom, Constants.toastBottomPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.toastAnimationDuration) {
                                withAnimation { viewModel.consumeToast() }
                            }
                        }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.toastMessage)
            .navigationTitle("마이페이지")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task { await viewModel.loadProfile() }
            }
            .overlay {
                // 로그아웃 확인 팝업
                if viewModel.isLogoutAlertPresented {
                    ExitPopupView(
                        title: "로그아웃할까요?",
                        message: "로그아웃하면 다음 접속 시 다시 로그인해야 합니다.",
                        onCancel: {
                            viewModel.isLogoutAlertPresented = false
                        },
                        onConfirm: {
                            viewModel.isLogoutAlertPresented = false
                            viewModel.logout(appState: appState)
                        },
                        confirmTitle: "로그아웃"
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.isLogoutAlertPresented)
            .overlay {
                // 회원탈퇴 확인 팝업
                if viewModel.isWithdrawalAlertPresented {
                    ExitPopupView(
                        title: "정말 탈퇴할까요?",
                        message: "탈퇴 후 7일 이내 재로그인 시 데이터가 복구됩니다.\n7일 이후에는 모든 정보가 영구 삭제됩니다.",
                        onCancel: {
                            viewModel.isWithdrawalAlertPresented = false
                        },
                        onConfirm: {
                            viewModel.isWithdrawalAlertPresented = false
                            viewModel.withdraw(appState: appState)
                        },
                        confirmTitle: "탈퇴"
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.isWithdrawalAlertPresented)
            .sheet(isPresented: $viewModel.isMailPresented) {
                MailComposeView(
                    toRecipients: [Constants.supportEmail],
                    subject: Constants.mailSubject,
                    onDismiss: { viewModel.isMailPresented = false }
                )
                .ignoresSafeArea()
            }
            .sheet(item: $safariItem) { item in
                SafariView(url: item.url)
                    .ignoresSafeArea()
            }
        }
    }
    
    // MARK: - 프로필 섹션
    
    private var profileSection: some View {
        VStack(spacing: 12) {
            avatarView
            VStack(spacing: 4) {
                Text(viewModel.userProfile?.nickname ?? "-")
                    .font(Font.setPretendard(weight: .semiBold, size: 18))
                    .foregroundStyle(Color.textPrimary)
                if let email = viewModel.userProfile?.email {
                    Text(email)
                        .font(Font.setPretendard(weight: .regular, size: 14))
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
    }
    
    private var avatarView: some View {
        Group {
            if let urlString = viewModel.userProfile?.profileImageUrl,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    defaultAvatarImage
                }
            } else {
                defaultAvatarImage
            }
        }
        .frame(width: Constants.avatarSize, height: Constants.avatarSize)
        .clipShape(Circle())
    }
    
    // 기본 프로필 이미지 Placeholder
    private var defaultAvatarImage: some View {
        Circle()
            .fill(Constants.avatarBackgroundColor)
            .overlay {
                Image(systemName: "camera")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 20)
                    .foregroundStyle(Constants.avatarSymbolColor)
            }
    }
    
    // MARK: - 통계 섹션
    
    private var statsSection: some View {
        HStack(spacing: Constants.statCardSpacing) {
            statCard(count: viewModel.albumCount, label: "내가 만든 앨범 수")
            statCard(count: viewModel.logCount, label: "내가 기록한 로그 수")
        }
        .padding(.horizontal, 20)
    }
    
    // 통계 카드 공통 UI
    private func statCard(count: Int, label: String) -> some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(Font.setPretendard(weight: .bold, size: 20))
                .foregroundStyle(Color.appPrimary)
            Text(label)
                .font(Font.setPretendard(weight: .regular, size: 11))
                .foregroundStyle(Constants.secondaryLabelColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Constants.statCardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.statCardCornerRadius)
                .stroke(Color.fieldBorder, lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(Constants.statCardShadowOpacity),
            radius: Constants.statCardShadowRadius,
            x: 0,
            y: Constants.statCardShadowY
        )
    }
    
    // MARK: - 앱 설정 섹션
    
    private var settingsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("앱 설정")
            // 알림 설정 Toggle
            HStack {
                Text("알림 설정")
                    .font(Font.setPretendard(weight: .medium, size: 16))
                    .foregroundStyle(Color.black)
                Spacer()
                Toggle("", isOn: $viewModel.isNotificationEnabled)
                    .tint(Color.appPrimary)
                    .labelsHidden()
            }
            .frame(height: Constants.rowHeight)
            .padding(.horizontal, 20)
            
            // 앱 버전
            HStack {
                Text("앱 버전")
                    .font(Font.setPretendard(weight: .semiBold, size: 16))
                    .foregroundStyle(Color.black)
                Spacer()
                Text(viewModel.appVersion)
                    .font(Font.setPretendard(weight: .semiBold, size: 16))
                    .foregroundStyle(Color.black)
            }
            .frame(height: Constants.rowHeight)
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - 고객지원 섹션
    
    private var supportSection: some View {
        VStack(spacing: 0) {
            sectionHeader("고객지원")
            menuRow(title: "이용약관") {
                safariItem = SafariItem(url: Constants.termsURL)
            }
            menuRow(title: "개인정보 처리방침") {
                safariItem = SafariItem(url: Constants.privacyURL)
            }
            menuRow(title: "오픈소스 라이센스") {
                safariItem = SafariItem(url: Constants.openSourceURL)
            }
            menuRow(title: "문의하기") {
                //TODO: MFMailComposeViewController 적용
                viewModel.showMailSheet()
            }
            .frame(height: Constants.rowHeight)
        }
    }
    
    // MARK: - 계정관리 섹션
    
    private var accountSection: some View {
        VStack(spacing: 0) {
            sectionHeader("계정관리")
            Button {
                viewModel.isLogoutAlertPresented = true
            } label: {
                HStack {
                    Text("로그아웃")
                        .font(Font.setPretendard(weight: .semiBold, size: 16))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                }
                .frame(height: Constants.rowHeight)
                .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)
            
            Button {
                viewModel.isWithdrawalAlertPresented = true
            } label: {
                HStack {
                    Text("회원탈퇴")
                        .font(Font.setPretendard(weight: .semiBold, size: 16))
                    // TODO: Assets에 withdrawalRed 색상 추가 후 Color.withdrawalRed로 교체
                        .foregroundStyle(Color(.systemRed))
                    Spacer()
                }
                .frame(height: Constants.rowHeight)
                .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - 공통 컴포넌트
    
    // 섹션 타이틀 공통 스타일
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(Font.setPretendard(weight: .semiBold, size: 13))
                .foregroundStyle(Constants.secondaryLabelColor)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, Constants.sectionHeaderBottomPadding)
    }
    
    // 고객지원 메뉴 공통 행
    private func menuRow(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(Font.setPretendard(weight: .semiBold, size: 16))
                    .foregroundStyle(Color.black)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.placeholderSymbol)
            }
            .frame(height: Constants.rowHeight)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SafariView

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    MyPageView()
        .environmentObject({
            let state = AppState()
            state.isLoggedIn = true
            return state
        }())
}
