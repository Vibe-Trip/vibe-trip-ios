//
//  AlbumGenre+Description.swift
//  VibeTrip
//
//  Created by CHOI on 3/26/26.
//

import Foundation

// 앨범 장르 모달 표시용 설명 텍스트
// 사용: MakeAlbumView, EditAlbumView
extension AlbumGenre {

    var descriptionText: String {
        switch self {
        case .pop:          return "밝고 트렌디한 대중 음악"
        case .kPop:         return "에너지 넘치고 화려한 아이돌 감성"
        case .jPop:         return "청량하고 맑은 일본 감성의 음악"
        case .rnb:          return "부드럽고 세련된 감성의 그루브 음악"
        case .rock:         return "시원하고 자유로운 밴드 사운드"
        case .acoustic:     return "따뜻하고 편안한 통기타 감성"
        case .indie:        return "나만의 취향을 담은 감성적인 음악"
        case .ballad:       return "추억과 감성을 담은 잔잔한 음악"
        case .jazz:         return "재즈바 같은 낭만적인 분위기"
        case .loFi:         return "휴식에 어울리는 잔잔한 비트"
        case .ambient:      return "몽환적이고 신비로운 분위기의 음악"
        case .cinematic:    return "영화 같은 웅장한 분위기의 음악"
        case .newAge:       return "잔잔한 피아노 중심의 편안한 음악"
        case .chillout:     return "노을과 휴식에 어울리는 부드러운 감성 음악"
        case .bossaNova:    return "햇살 가득한 카페 같은 감성"
        case .tropicalHouse: return "바다와 여행이 떠오르는 시원한 리듬"
        case .deepHouse:    return "리듬감 있게 몰입되는 세련된 전자 음악"
        }
    }

    // Jazz: 가사 유무에 따른 다른 설명
    func descriptionText(for lyricsOption: LyricsOption) -> String {
        if self == .jazz && lyricsOption == .exclude {
            return "재즈바 같은 여유롭고 낭만적인 연주"
        }
        return descriptionText
    }
}
