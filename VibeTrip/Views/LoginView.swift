//
//  LoginView.swift
//  VibeTrip
//
//  Created by CHOI on 2/28/26.
//

import SwiftUI
import AuthenticationServices
import SafariServices

private struct SafariItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct LoginView: View {

    @StateObject private var viewModel = LoginViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var safariItem: SafariItem?

    private enum Constants {
        static let toastBottomPadding: CGFloat = 10
        static let toastAnimationDuration: Double = 3.0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header: Logo + Subtitle
            headerArea
                .padding(.top, 12)
            
            Spacer()
            
            // Buttons
            buttonArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // MARK: - Background
            backgroundView
                .ignoresSafeArea()
        }
        // 로딩 오버레이
        .overlay {
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        // 토스트 오버레이
        .overlay(alignment: .bottom) {
            if let toastPayload = appState.toastPayload {
                AppToastView(message: toastPayload.message, systemImageName: toastPayload.systemImageName)
                    .padding(.bottom, Constants.toastBottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.toastAnimationDuration) {
                            withAnimation {
                                appState.consumeToast()
                            }
                        }
                    }
            } else if case .toast(let message) = viewModel.errorState {
                AppToastView(message: message)
                    .padding(.bottom, Constants.toastBottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.errorState)
        .animation(.easeInOut(duration: 0.3), value: appState.toastPayload)
        // 타임아웃 팝업
        .alert("로그인 실패", isPresented: Binding(
            get: { if case .retryPopup = viewModel.errorState { return true }; return false },
            set: { if !$0 { viewModel.errorState = nil } }
        )) {
            Button("다시 시도") {
                viewModel.errorState = nil
                viewModel.retryLogin()
            }
            Button("닫기", role: .cancel) { viewModel.errorState = nil }
        } message: {
            if case .retryPopup(let message) = viewModel.errorState {
                Text(message)
            }
        }
        // 확인 팝업
        .alert("이용 제한", isPresented: Binding(
            get: { if case .alertPopup = viewModel.errorState { return true }; return false },
            set: { if !$0 { viewModel.errorState = nil } }
        )) {
            Button("확인") { viewModel.errorState = nil }
        } message: {
            if case .alertPopup(let message) = viewModel.errorState {
                Text(message)
            }
        }
        // 로그인 성공 -> 메인화면(fullScreenCover)
        .fullScreenCover(isPresented: $viewModel.isLoggedIn) {
            MainTabBarView()
                .environmentObject(appState)
        }
        // 로그인 성공 시 appState 동기화 -> 재로그아웃 정상화 목적
        .onChange(of: viewModel.isLoggedIn) { _, newVal in
            if newVal {
                appState.isLoggedIn = true
            }
        }
        // 로그아웃/탈퇴 시 fullScreenCover 닫기
        .onChange(of: appState.isLoggedIn) { _, newVal in
            if newVal == .some(false) {
                viewModel.isLoggedIn = false
            }
        }
        .sheet(item: $safariItem) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.5)
        }
    }
    
    // MARK: - Background
    private var backgroundView: some View {
        Group {
            if let image = UIImage(named: "LoginViewBG") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {    // LoginViewBG 호출 실패 시
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.18, blue: 0.35),
                        Color(red: 0.25, green: 0.22, blue: 0.40),
                        Color(red: 0.55, green: 0.35, blue: 0.20),
                        Color(red: 0.85, green: 0.50, blue: 0.15)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
    
    // MARK: - Header(로고 + 텍스트)
    private var headerArea: some View {
        VStack(spacing: 20) {
            logoPlaceholder
            subtitleText
        }
    }
    
    // MARK: - Logo Placeholder
    private var logoPlaceholder: some View {
        Image("AppLogo_Login")
            .resizable()
            .scaledToFit()
            .frame(width: 138, height: 30)
    }
    
    // MARK: - Subtitle
    private var subtitleText: some View {
        Text("여행 사진 한 장으로 시작하는\n이 세상에 하나뿐인 사운드트랙")
            .font(.setPretendard(weight: .semiBold, size: 16))
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .lineSpacing(4)
    }
    
    // MARK: - Button Area
    private var buttonArea: some View {
        VStack(spacing: 12) {
            // Kakao Login Button
            Button { viewModel.loginWithKakao() } label: {
                HStack(spacing: 5) {
                    Image("KaKaoLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .offset(x: -3)
                        
                    Text("카카오로 계속하기")
                        .font(.setPretendard(weight: .medium, size: 20))
                        .offset(x: -1)
                }
                .foregroundColor(.black.opacity(0.85))
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color(red: 254/255, green: 229/255, blue: 0))
                .cornerRadius(8)
            }
            
            // Apple Login Button
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                viewModel.handleAppleResult(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .cornerRadius(8)

            // 약관 캡션
            captionView
        }
        .padding(.horizontal, 20)
        .disabled(viewModel.isLoading)  // 로딩 중 전체 버튼 비활성화
    }

    // MARK: - Terms Caption

    private let termsURL = URL(string: "https://www.notion.so/RETRIP-3366aa129c8e8046a8f0e90d7b1d78cb?source=copy_link")!
    private let privacyURL = URL(string: "https://www.notion.so/RETRIP-3366aa129c8e8014bf10c55c890f67ad?source=copy_link")!

    private var captionAttributedText: AttributedString {
        var prefix  = AttributedString("회원가입 시 RETRIP 서비스 필수 동의 항목인 \n")
        var terms   = AttributedString("서비스 이용약관")
        var and     = AttributedString("과 ")
        var privacy = AttributedString("개인정보처리방침")
        var suffix  = AttributedString("이 함께 적용됩니다.")
        terms.link = termsURL
        terms.underlineStyle = .single
        privacy.link = privacyURL
        privacy.underlineStyle = .single
        return prefix + terms + and + privacy + suffix
    }

    private var captionView: some View {
        Text(captionAttributedText)
            .font(.setPretendard(weight: .regular, size: 12))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineSpacing(3.6)
            .tint(.white)
            .environment(\.openURL, OpenURLAction { url in
                safariItem = SafariItem(url: url)
                return .handled
            })
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    let appState = AppState()
    appState.toastPayload = AppToastPayload(message: "로그아웃이 완료되었습니다", systemImageName: nil)

    return LoginView()
        .environmentObject(appState)
}
