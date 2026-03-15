//
//  LoginView.swift
//  VibeTrip
//
//  Created by CHOI on 2/28/26.
//

import SwiftUI

struct LoginView: View {
    
    @StateObject private var viewModel = LoginViewModel()
    
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
            if case .toast(let message) = viewModel.errorState {
                toastView(message: message)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.errorState)
        // 토스트 메시지(3초)
        .onChange(of: viewModel.errorState) { newValue in
            if case .toast = newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if case .toast = viewModel.errorState {
                        viewModel.errorState = nil
                    }
                }
            }
        }
        // 재시도 팝업(timeout)
        .alert("로그인 실패", isPresented: Binding(
            get: { if case .retryPopup = viewModel.errorState { return true }; return false },
            set: { if !$0 { viewModel.errorState = nil } }
        )) {
            Button("다시 시도") { viewModel.errorState = nil }
            Button("취소", role: .cancel) { viewModel.errorState = nil }
        } message: {
            if case .retryPopup(let message) = viewModel.errorState {
                Text(message)
            }
        }
        // 계정 제한 팝업(accountBlocked)
        .alert("이용 제한", isPresented: Binding(
            get: { if case .alertPopup = viewModel.errorState { return true }; return false },
            set: { if !$0 { viewModel.errorState = nil } }
        )) {
            Button("확인", role: .cancel) { viewModel.errorState = nil }
        } message: {
            if case .alertPopup(let message) = viewModel.errorState {
                Text(message)
            }
        }
        // 로그인 성공 -> 메인화면(fullScreenCover)
        // TODO: MainView()로 교체
        .fullScreenCover(isPresented: $viewModel.isLoggedIn) {
            Text("메인 화면")
                .font(.title)
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
    
    // MARK: - Toast
    
    private func toastView(message: String) -> some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.75))
            .cornerRadius(8)
            .padding(.horizontal, 24)
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
        Image(systemName: "airplane")
            .font(.system(size: 40, weight: .semibold))
            .foregroundColor(.white)
    }
    
    // MARK: - Subtitle
    private var subtitleText: some View {
        Text("여행 사진 한 장으로 시작하는\n세상에 하나뿐인 사운드트랙")
            .font(.system(size: 16, weight: .regular))
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .lineSpacing(4)
    }
    
    // MARK: - Button Area
    private var buttonArea: some View {
        VStack(spacing: 12) {
            // Kakao Login Button
            loginButton(
                icon: "message.fill",
                title: "카카오로 시작하기",
                foreground: .black,
                background: Color(red: 1.0, green: 0.898, blue: 0.0)
            ) { viewModel.loginWithKakao() }
            
            // Apple Login Button
            loginButton(
                icon: "apple.logo",
                title: "Apple로 시작하기",
                foreground: .white,
                background: .black
            ) { viewModel.loginWithApple() }
        }
        .padding(.horizontal, 20)
        .disabled(viewModel.isLoading)  // 로딩 중 전체 버튼 비활성화
    }
    
    // MARK: - Login Button Helper
    private func loginButton(
        icon: String,
        title: String,
        foreground: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(background)
            .cornerRadius(8)
        }
    }
}

#Preview {
    LoginView()
}

