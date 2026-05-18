//
//  AnalyticsEvent.swift
//  VibeTrip
//
//  Created by CHOI on 5/18/26.
//

// 구글 애널리틱스 커스텀 이벤트 및 파라미터 키 정의

import Foundation

// MARK: - 이벤트

enum AnalyticsEvent: String {
    // 화면 추적: GA4 예약 이벤트명
    case screenView = "screen_view"

    // 앨범 생성
    case albumCreateStart = "album_create_start"
    case albumCreateComplete = "album_create_complete"
    case albumCreateFail = "album_create_fail"

    // 앨범 상세 및 음악 재생
    case albumOpen = "album_open"
    case musicPlay = "music_play"

    // 앨범 수정
    case albumEditComplete = "album_edit_complete"

    // 로그 저장
    case logSave = "log_save"
}

// MARK: - 파라미터 키

enum AnalyticsParam: String {
    // screen_view
    case screenName = "screen_name"

    // album_create_complete
    case genre
    case hasLyrics = "has_lyrics"
    case vocalGender = "vocal_gender"
    case hasCommentary = "has_commentary"
    case durationSec = "duration_sec"

    // album_create_fail
    case errorType = "error_type"
    case step

    // album_open
    case source

    // album_edit_complete
    case musicRegenerated = "music_regenerated"

    // log_save
    case charCount = "char_count"
    case hasPhoto = "has_photo"
}

// MARK: - 파라미터 값 

enum AnalyticsStep: String {
    case photoUpload = "photo_upload"
    case albumRequest = "album_request"
    case musicGeneration = "music_generation"
}

enum AnalyticsSource: String {
    case mainList = "main_list"
    case afterCreate = "after_create"
    case notification
}
