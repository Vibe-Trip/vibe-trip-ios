//
//  MyPageViewModel.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import Foundation
import MessageUI
import Combine

@MainActor final class MyPageViewModel: ObservableObject {
    
    // MARK: - Published
    
    @Published private(set) var userProfile: UserProfile?
    @Published private(set) var albumCount: Int = 0
    @Published private(set) var logCount: Int = 0
    // 알림 설정 변경 시 UserDefaults에 즉시 저장
    @Published var isNotificationEnabled: Bool {
        didSet { UserDefaults.standard.set(isNotificationEnabled, forKey: Constants.notificationKey) }
    }
    @Published var isWithdrawalAlertPresented: Bool = false
    @Published var isMailPresented: Bool = false
    @Published private(set) var toastMessage: String?
    @Published private(set) var isLoading: Bool = false
    
    // MARK: - Properties
    
    let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    
    // MARK: - Private
    
    private let userService: UserServiceProtocol
    private let keychainService: KeychainServiceProtocol
    
    private enum Constants {
        static let notificationKey = "isNotificationEnabled"
    }
    
    // MARK: - Init
    
    init(
        userService: UserServiceProtocol = UserService(),
        keychainService: KeychainServiceProtocol = KeychainService()
    ) {
        self.userService = userService
        self.keychainService = keychainService
        self.isNotificationEnabled = UserDefaults.standard.object(forKey: "isNotificationEnabled") as? Bool ?? true
    }
    
    // MARK: - Methods
    
    func loadProfile() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // 현재 사용자 프로필 조회
            userProfile = try await userService.fetchProfile()
        } catch {
            showToast("프로필을 불러오지 못했어요.")
        }
    }
    
    func logout(appState: AppState) {
        // 로컬 인증 정보 제거 후 로그인 화면으로 복귀
        try? keychainService.clear()
        appState.isLoggedIn = false
    }
    
    func withdraw(appState: AppState) {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                // 서버 탈퇴 후 로컬 인증 정보 정리
                try await userService.deleteAccount()
                try? keychainService.clear()
                appState.isLoggedIn = false
            } catch {
                showToast("탈퇴 처리 중 오류가 발생했어요.")
            }
        }
    }
    
    func showMailSheet() {
        // 메일 앱 설정 여부 확인 후 문의하기 시트 표시
        guard MFMailComposeViewController.canSendMail() else {
            showToast("메일 앱이 설정되어 있지 않아요.")
            return
        }
        isMailPresented = true
    }
    
    func showToast(_ message: String) {
        toastMessage = message
    }
    
    func consumeToast() {
        toastMessage = nil
    }
}
