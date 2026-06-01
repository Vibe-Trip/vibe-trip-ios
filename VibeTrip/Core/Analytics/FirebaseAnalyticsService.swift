//
//  FirebaseAnalyticsService.swift
//  VibeTrip
//
//  Created by CHOI on 5/18/26.
//

// AnalyticsServiceProtocol의 Firebase 구현체

import Foundation
import FirebaseAnalytics

final class FirebaseAnalyticsService: AnalyticsServiceProtocol {

    func log(_ event: AnalyticsEvent, parameters: [AnalyticsParam: Any]?) {
        let mapped: [String: Any]? = parameters?.reduce(into: [:]) { result, pair in
            result[pair.key.rawValue] = pair.value
        }
        Analytics.logEvent(event.rawValue, parameters: mapped)
    }

    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }
}
