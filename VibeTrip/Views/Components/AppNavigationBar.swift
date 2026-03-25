//
//  AppNavigationBar.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI

// MARK: - AppNavigationBarConstants

private enum AppNavigationBarConstants {
    static let touchTargetSize: CGFloat = 44
    static let horizontalPadding: CGFloat = 20
    static let height: CGFloat = 44
    static let backIconSize: CGFloat = 20
}

// MARK: - AppNavigationBar
// 범용 네비게이션 바
// 좌측: 뒤로가기 고정
// 우측: trailing 선택 주입

struct AppNavigationBar<Trailing: View>: View {
    
    let title: String
    let onBackTap: () -> Void
    let trailing: Trailing
    
    // MARK: - Init
    
    init(
        title: String,
        onBackTap: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.onBackTap = onBackTap
        self.trailing = trailing()
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack {
            // 좌측: 뒤로가기 arrow
            Button(action: onBackTap) {
                Image(systemName: "chevron.left")
                    .font(.system(size: AppNavigationBarConstants.backIconSize, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .frame(
                        width: AppNavigationBarConstants.touchTargetSize,
                        height: AppNavigationBarConstants.touchTargetSize
                    )
            }
            
            Spacer()
            
            // 중앙: 타이틀
            Text(title)
                .font(.setPretendard(weight: .medium, size: 16))
                .foregroundStyle(Color.textPrimary)
            
            Spacer()
            
            // 우측: trailing overlay
            Color.clear
                .frame(
                    width: AppNavigationBarConstants.touchTargetSize,
                    height: AppNavigationBarConstants.touchTargetSize
                )
                .overlay { trailing }
        }
        .frame(maxWidth: .infinity)
        .frame(height: AppNavigationBarConstants.height)
        .padding(.horizontal, AppNavigationBarConstants.horizontalPadding)
        .background(Color.white)
    }
}

// MARK: - Convenience init (trailing X)

extension AppNavigationBar where Trailing == EmptyView {
    init(title: String, onBackTap: @escaping () -> Void) {
        self.title = title
        self.onBackTap = onBackTap
        self.trailing = EmptyView()
    }
}

// MARK: - Preview

#Preview("trailing 없음") {
    AppNavigationBar(title: "앨범 만들기", onBackTap: {})
}

#Preview("trailing 있음 (저장 버튼)") {
    AppNavigationBar(title: "로그 작성", onBackTap: {}) {
        Button("저장") {}
            .font(.setPretendard(weight: .semiBold, size: 16))
            .foregroundStyle(Color.appPrimary)
    }
}
