//
//  AnalyticsServiceProtocol.swift
//  VibeTrip
//
//  Created by CHOI on 5/18/26.
//

// 애널리틱스 추상화 인터페이스

import Foundation

protocol AnalyticsServiceProtocol {
    // 이벤트 발사 (파라미터 선택)
    func log(_ event: AnalyticsEvent, parameters: [AnalyticsParam: Any]?)

    // 사용자 속성 설정
    func setUserProperty(_ value: String?, forName name: String)
}

extension AnalyticsServiceProtocol {
    // 파라미터 없는 이벤트 호출 편의 메서드
    func log(_ event: AnalyticsEvent) {
        log(event, parameters: nil)
    }
}

#if DEBUG
// Mock 서비스 (Preview / 테스트용)
final class MockAnalyticsService: AnalyticsServiceProtocol {

    // 호출 기록 (테스트에서 검증)
    private(set) var loggedEvents: [(event: AnalyticsEvent, parameters: [AnalyticsParam: Any]?)] = []
    private(set) var setUserProperties: [(value: String?, name: String)] = []

    func log(_ event: AnalyticsEvent, parameters: [AnalyticsParam: Any]?) {
        loggedEvents.append((event, parameters))
    }

    func setUserProperty(_ value: String?, forName name: String) {
        setUserProperties.append((value, name))
    }

    func reset() {
        loggedEvents.removeAll()
        setUserProperties.removeAll()
    }
}
#endif
