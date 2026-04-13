//
//  SwipeBackEnabler.swift
//  VibeTrip
//
//  Created by CHOI on 4/13/26.
//

import SwiftUI
import UIKit

// NavigationStack에서 .toolbar(.hidden)으로 인해 비활성화된 interactivePopGestureRecognizer를 다시 활성화하는 헬퍼
// destination 뷰에 .background(SwipeBackEnabler())로 사용
struct SwipeBackEnabler: UIViewRepresentable {

    func makeUIView(context: Context) -> UIView { UIView() }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            // Responder chain을 타고 올라가 NavigationController를 찾아 스와이프 뒤로가기 활성화
            var responder: UIResponder? = uiView.next
            while let r = responder {
                if let nav = r as? UINavigationController {
                    nav.interactivePopGestureRecognizer?.isEnabled = true
                    // delegate를 nil로 설정해 iOS 기본 동작(뷰가 1개일 때 제스처 자동 무시) 복원
                    nav.interactivePopGestureRecognizer?.delegate = nil
                    break
                }
                responder = r.next
            }
        }
    }
}
