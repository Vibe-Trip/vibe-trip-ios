//
//  GlassBackground.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI
import UIKit

// MARK: - Liquid Glass Background (UIBlurEffect 기반)

struct LiquidGlassBackground: UIViewRepresentable {

    func makeUIView(context: Context) -> UIVisualEffectView {
        // 블러 강도 조절:
        // .systemUltraThinMaterial : 가장 얇음
        // .systemThinMaterial      : 보통
        // .systemMaterial          : 진함
        // .systemThickMaterial     : 가장 진함
        let blur         = UIBlurEffect(style: .systemUltraThinMaterial)
        let view         = UIVisualEffectView(effect: blur)

        // Vibrancy: 배경색 반영된 블러 효과
        let vibrancy     = UIVibrancyEffect(blurEffect: blur, style: .fill)
        let vibrancyView = UIVisualEffectView(effect: vibrancy)
        vibrancyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.contentView.addSubview(vibrancyView)

        // 밝기 오버레이
        let overlay              = UIView()
        overlay.backgroundColor  = UIColor.white.withAlphaComponent(0.02) ///alphaComponent : 값 높일 수록 밝아짐
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.contentView.addSubview(overlay)

        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
