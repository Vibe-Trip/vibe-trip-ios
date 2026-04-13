//
//  SwipeBackEnabler.swift
//  VibeTrip
//
//  Created by CHOI on 4/13/26.
//

import SwiftUI
import UIKit

// NavigationStack에서 .toolbar(.hidden)으로 인해 비활성화된 interactivePopGestureRecognizer를 다시 활성화하는 헬퍼
// destination 뷰에 .background(SwipeBackEnabler(...))로 사용
struct SwipeBackEnabler: UIViewRepresentable {
    var isEnabled: Bool = true
    var onBlocked: (() -> Void)? = nil

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isEnabled: Bool = true
        var onBlocked: (() -> Void)?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled else {
                onBlocked?()
                return false
            }
            return true
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView { UIView() }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onBlocked = onBlocked

        DispatchQueue.main.async {
            // Responder chain을 타고 올라가 NavigationController를 찾아 스와이프 뒤로가기 활성화
            var responder: UIResponder? = uiView.next
            while let r = responder {
                if let nav = r as? UINavigationController {
                    nav.interactivePopGestureRecognizer?.isEnabled = true
                    nav.interactivePopGestureRecognizer?.delegate = context.coordinator
                    break
                }
                responder = r.next
            }
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        DispatchQueue.main.async {
            var responder: UIResponder? = uiView.next
            while let r = responder {
                if let nav = r as? UINavigationController {
                    if nav.interactivePopGestureRecognizer?.delegate === coordinator {
                        nav.interactivePopGestureRecognizer?.delegate = nil
                    }
                    break
                }
                responder = r.next
            }
        }
    }
}
