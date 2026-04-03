//
//  ScrollOffsetObserver.swift
//  VibeTrip
//
//  Created by CHOI on 4/3/26.
//

import SwiftUI

// UIScrollView contentOffset.y -> KVO로 직접 관찰해 바인딩에 실시간 반영
/// KVO: Key-Value Observing
struct ScrollOffsetObserver: UIViewRepresentable {

    @Binding var contentOffset: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // 이미 관찰 중이면 재등록 방지
        guard context.coordinator.scrollView == nil else { return }
        // 레이아웃 완료 후 뷰 계층 탐색
        DispatchQueue.main.async {
            guard context.coordinator.scrollView == nil,
                  let scrollView = uiView.parentScrollView() else { return }
            context.coordinator.startObserving(scrollView, binding: $contentOffset)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        private(set) var scrollView: UIScrollView?
        private var observation: NSKeyValueObservation?

        func startObserving(_ scrollView: UIScrollView, binding: Binding<CGFloat>) {
            self.scrollView = scrollView
            // contentOffset KVO: UIKit 스크롤과 동일, 메인 스레드에서 동기 콜백
            observation = scrollView.observe(\.contentOffset, options: [.new]) { sv, _ in
                binding.wrappedValue = sv.contentOffset.y
            }
        }

        deinit { observation?.invalidate() }
    }
}

// MARK: - UIView Extension

private extension UIView {
    // 뷰 계층을 올라가며 가장 가까운 UIScrollView 탐색
    func parentScrollView() -> UIScrollView? {
        var current: UIView? = superview
        while let view = current {
            if let scrollView = view as? UIScrollView { return scrollView }
            current = view.superview
        }
        return nil
    }
}
