//
//  MakeAlbumLoadingView.swift
//  VibeTrip
//
//  Created by CHOI on 3/24/26.
//

import SwiftUI

//TODO: 디자인에 맞게 UI 변경

// MARK: - Color Constants
private extension Color {
    static let progressBlue = Color(red: 0.18, green: 0.18, blue: 0.75)
    static let progressTrack = Color(red: 0.82, green: 0.82, blue: 0.90)
}

// MARK: - Progress View
struct CircularProgressView: View {
    let progress: Double
    private let lineWidth: CGFloat = 18
    private let size: CGFloat = 150

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.progressTrack, lineWidth: lineWidth)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.progressBlue,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress) // 채워질 때 부드럽게

            Text("\(Int(progress * 100))%")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundColor(Color.progressBlue)
        }
    }
}

// MARK: - Loading View
struct MakeAlbumLoadingView: View {
    @State private var progress: Double = 0.0
    private let step: Double = 0.1
    private let interval: TimeInterval = 0.8 // 0.8초마다 10%씩 증가

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                CircularProgressView(progress: progress)

                Spacer().frame(height: 60)

                VStack(spacing: 14) {
                    
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .onAppear {
            startRepeatingAnimation()
        }
    }

    private func startRepeatingAnimation() {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            progress += step

            // 100% 도달하면 0으로 리셋 후 반복
            if progress >= 1.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    progress = 0.0
                }
            }
        }
    }
}

#Preview {
    MakeAlbumLoadingView()
}
