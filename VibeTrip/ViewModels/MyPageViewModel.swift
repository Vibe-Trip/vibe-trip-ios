//
//  MyPageViewModel.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import Foundation
import MessageUI
import Combine
import UIKit
import UserNotifications

@MainActor final class MyPageViewModel: ObservableObject {
    
    // MARK: - Published
    
    @Published private(set) var userProfile: UserProfile?
    @Published private(set) var albumCount: Int = 0
    @Published private(set) var logCount: Int = 0
    @Published private(set) var isNotificationEnabled: Bool
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

    func setNotificationEnabled(_ isEnabled: Bool) {
        Task {
            if isEnabled {
                // 토글 on: 권한 상태 확인
                await enableNotifications()
            } else {
                // 토글 off: 원격 알림 등록 해제
                disableNotifications()
            }
        }
    }
    
    func logout(appState: AppState) {
        // 로컬 인증 정보 제거 후 로그인 화면으로 복귀
        try? keychainService.clear()
        appState.showToast(message: "로그아웃이 완료되었습니다", systemImageName: nil)
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

    private func enableNotifications() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            // 이미 권한 O: APNs 등록만 다시 보장
            UIApplication.shared.registerForRemoteNotifications()
            persistNotificationEnabled(true)

        case .notDetermined:
            // 최초 1회: 시스템 권한 팝업 띄움
            let granted = await requestNotificationAuthorization()
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
                persistNotificationEnabled(true)
            } else {
                persistNotificationEnabled(false)
                showToast("알림 권한이 허용되지 않았어요.")
            }

        case .denied:
            persistNotificationEnabled(false)
            showToast("설정 앱에서 알림 권한을 허용해 주세요.")

        @unknown default:
            persistNotificationEnabled(false)
            showToast("알림 설정을 변경하지 못했어요.")
        }
    }

    private func disableNotifications() {
        // 원격 알림 등록 해제
        UIApplication.shared.unregisterForRemoteNotifications()
        persistNotificationEnabled(false)
    }

    private func persistNotificationEnabled(_ isEnabled: Bool) {
        isNotificationEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Constants.notificationKey)
    }

    private func requestNotificationAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
}
