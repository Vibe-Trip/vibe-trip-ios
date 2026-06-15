//
//  ScreenViewModifier.swift
//  VibeTrip
//
//  Created by CHOI on 5/18/26.
//

// SwiftUI 화면 진입 -> GA4 screen_view 이벤트로 수동 로깅
// SwiftUI: screen_view 추적이 부정확하므로 ViewModifier로 명시적 발사

import SwiftUI

// MARK: - Environment 주입

// Analytics 서비스를 View 트리 전체에서 공유하기 위한 EnvironmentKey
private struct AnalyticsServiceKey: EnvironmentKey {
    static let defaultValue: AnalyticsServiceProtocol = FirebaseAnalyticsService()
}

extension EnvironmentValues {
    var analytics: AnalyticsServiceProtocol {
        get { self[AnalyticsServiceKey.self] }
        set { self[AnalyticsServiceKey.self] = newValue }
    }
}

// MARK: - Modifier

private struct ScreenViewModifier: ViewModifier {
    let screenName: String
    @Environment(\.analytics) private var analytics
    @State private var hasLogged = false

    func body(content: Content) -> some View {
        content.onAppear {
            guard !hasLogged else { return }
            hasLogged = true
            analytics.log(.screenView, parameters: [.screenName: screenName])
        }
    }
}

extension View {
    // 호출부: .trackScreen("Home") 형태로 통일
    func trackScreen(_ name: String) -> some View {
        modifier(ScreenViewModifier(screenName: name))
    }
}

// MARK: - Preview

#Preview {
    Text("Screen View Tracking Preview")
        .trackScreen("PreviewScreen")
}
