//
//  ScrollOffsetKey.swift
//  VibeTrip
//
//  Created by CHOI on 3/28/26.
//

import SwiftUI

/// 스크롤 offset 감지용 PreferenceKey
/// 예시:
///
/// ScrollView {
///     VStack {
///         GeometryReader { geo in
///             Color.clear
///                 .preference(
///                     key: ScrollOffsetKey.self,
///                     value: geo.frame(in: .global).minY
///                 )
///         }
///         .frame(height: 0)
///
///         // 콘텐츠
///     }
/// }
/// .ignoresSafeArea()
/// .onPreferenceChange(ScrollOffsetKey.self) { offset = $0 }

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
