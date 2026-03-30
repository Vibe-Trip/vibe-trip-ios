//
//  LoopingVideoView.swift
//  VibeTrip
//
//  Created by CHOI on 3/30/26.
//

import SwiftUI
import AVFoundation

// MARK: - LoopingVideoView
// MOV 재생용 UIViewRepresentable 컴포넌트

struct LoopingVideoView: UIViewRepresentable {

    // MOV 파일명
    let name: String

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.load(name: name)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {}
}

// MARK: - PlayerContainerView
// AVPlayerLayer 크기를 뷰 bounds에 맞게 자동 조정

final class PlayerContainerView: UIView {

    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    func load(name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mov") else { return }

        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer()
        let playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        // 소리 X
        queuePlayer.isMuted = true

        let layer = AVPlayerLayer(player: queuePlayer)
        layer.videoGravity = .resize
        layer.frame = bounds
        self.layer.addSublayer(layer)

        self.player = queuePlayer
        self.looper = playerLooper
        self.playerLayer = layer

        queuePlayer.play()
    }
}

// MARK: - Preview

#Preview {
    LoopingVideoView(name: "AlbumGenerate")
        .frame(width: 260, height: 195)
}
