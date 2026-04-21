//
//  ShimmerModifier.swift
//  VibeTrip
//
//  Created by CHOI on 4/21/26.
//

import SwiftUI

// MARK: - ShimmerModifier

struct ShimmerModifier<ClipShape: Shape>: ViewModifier {
    // 빛 영역을 잘라낼 모양
    let shape: ClipShape

    // gradient 위상: -1(왼쪽 바깥) -> 1(오른쪽 바깥)로 이동
    @State private var phase: CGFloat = -1

    // 빛이 한 번 좌->우로 흐르는 데 걸리는 시간(초)
    private let duration: Double = 2.5

    // 흐르는 빛의 색과 강도
    private let bandColor = Color.white.opacity(1.0)

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    // 0.3 / 0.5 / 0.7 stop -> 넓고 부드러운 페이드 밴드 구성
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.3),
                        .init(color: bandColor, location: 0.5),
                        .init(color: .clear, location: 0.7)
                    ]),
                    // 좌->우 수평 이동, phase에 따라 gradient 영역이 화면 밖에서 안으로 흘러감
                    startPoint: UnitPoint(x: phase, y: 0.5),
                    endPoint: UnitPoint(x: phase + 2, y: 0.5)
                )
                // overlay를 스켈레톤 모양에 맞춰 잘라냄 (content alpha 영향 없이 빛만 표시)
                .clipShape(shape)
            )
            .onAppear {
                // 선형 애니메이션을 끊김 없이 반복하여 빛이 연속해서 흐르도록 처리
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    // 호출: .shimmering(shape: Capsule()) -> 스켈레톤 모양 지정
    func shimmering<S: Shape>(shape: S) -> some View {
        modifier(ShimmerModifier(shape: shape))
    }
}
