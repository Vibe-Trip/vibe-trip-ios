//
//  LoginView.swift
//  VibeTrip
//
//  Created by CHOI on 2/28/26.
//

import SwiftUI

struct LoginView: View {
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
            ) {}
            // Apple Login Button
            loginButton(
                icon: "apple.logo",
                title: "Apple로 시작하기",
                foreground: .white,
                background: .black
            ) {}
            
            // 약관 Text
            Text("로그인하면 서비스 이용약관 및\n개인정보 처리방침에 동의하시는 것으로 이해할게요.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundColor(Color.white.opacity(0.7))
                .lineSpacing(3)
                .padding(.top, 8)
        }
        .padding(.horizontal, 20)
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

