//
//  BackgroundMusicService.swift
//  VibeTrip
//
//  Created by CHOI on 4/5/26.
//

import AVFoundation
import Combine

// 배경음악 재생 유지 서비스
// fullScreenCover 진입 시 AlbumDetailView에 EnvironmentObject로 주입-> onDisappear되어도 음악이 끊기지 않음
@MainActor
final class BackgroundMusicService: ObservableObject {

    // 현재 재생 여부
    @Published private(set) var isPlaying: Bool = false

    // 현재 재생 중인 음악 URL
    @Published private(set) var currentMusicUrl: URL? = nil

    private var player: AVPlayer? = nil

    // musicUrl 세팅 + 자동 재생
    func play(url: URL) {
        if currentMusicUrl == url {
            player?.play()
        } else {
            currentMusicUrl = url
            player = AVPlayer(url: url)
            player?.play()
        }
        isPlaying = true
    }

    // 일시정지
    func pause() {
        player?.pause()
        isPlaying = false
    }

    // 재생/일시정지 토글
    func toggle() {
        isPlaying ? pause() : resume()
    }

    // 이어서 재생
    func resume() {
        player?.play()
        isPlaying = true
    }

    // 정지 + 초기화 —> 앨범 상세 페이지 닫힐 때 호출
    func stop() {
        player?.pause()
        player = nil
        currentMusicUrl = nil
        isPlaying = false
    }
}
