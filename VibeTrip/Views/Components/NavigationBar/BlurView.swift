//
//  BlurView.swift
//  VibeTrip
//
//  Created by CHOI on 3/28/26.
//

import SwiftUI
import UIKit

// 커스텀 블러 뷰(UIKit 기반)

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    var intensity: CGFloat = 0.2    /// 블러 강도 0.0(투명) ~ 1.0(최대)

    func makeUIView(context: Context) -> UIVisualEffectView {
        let blurView = UIVisualEffectView()
        blurView.backgroundColor = .clear

        let animator = UIViewPropertyAnimator(duration: 1, curve: .linear)
        animator.addAnimations {
            blurView.effect = UIBlurEffect(style: style)
        }
        animator.fractionComplete = intensity
        animator.pausesOnCompletion = true
        context.coordinator.animator = animator

        return blurView
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        context.coordinator.animator?.fractionComplete = intensity
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var animator: UIViewPropertyAnimator?
        deinit {
            animator?.stopAnimation(true)
            animator?.finishAnimation(at: .current)
        }
    }
}
