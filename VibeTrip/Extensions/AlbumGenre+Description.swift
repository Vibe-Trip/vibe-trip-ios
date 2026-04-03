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
        case .pop:          return "세련된 글로벌 트렌디 사운드의 정석"
        case .kPop:         return "화려하고 에너제틱한 주인공의 기분"
        case .jPop:         return "도심 산책에 어울리는 청량하고 맑은 무드"
        case .latin:        return "휴양지의 열정을 더하는 이국적인 리듬"
        case .rnb:          return "도시의 밤을 적시는 감각적인 그루브"
        case .rock:         return "자유로운 에너지가 폭발하는 드라이브 감성"
        case .country:      return "자연 속을 달리는 편안한 로드트립의 여유"
        case .acoustic:     return "통기타 선율이 전하는 따뜻하고 진솔한 위로"
        case .indie:        return "나만의 취향을 담은 독특하고 힙한 무드"
        case .ballad:       return "잊지 못할 여행의 추억을 담은 애틋한 선율"
        case .classical:    return "대자연의 웅장함을 담은 고품격 대서사시"
        case .jazz:         return "루프탑 야경에 어울리는 여유롭고 낭만적인 밤"
        case .loFi:         return "나른한 오후의 여유를 담은 편안하고 낮은 비트"
        case .ambient:      return "공간을 가득 채우는 몽환적이고 신비로운 울림"
        case .cinematic:    return "영화 속 주인공이 된 듯한 웅장하고 드라마틱한 감동"
        case .newAge:       return "맑은 피아노 선율이 전하는 평온하고 순수한 휴식"
        case .chillout:     return "복잡한 생각을 비워주는 세련된 휴양지의 무드"
        case .bossaNova:    return "햇살 가득한 해변을 걷는 듯 가볍고 경쾌한 리듬"
        case .tropicalHouse: return "파도 소리가 들리는 듯 시원하고 청량한 여름의 설렘"
        case .postRock:     return "서서히 차오르는 서정적인 감정의 깊은 파동"
        case .classicSolo:  return "우아한 악기 선율로 완성하는 품격 있는 기록"
        case .acousticFolk: return "소박한 기타 연주에 담긴 따뜻하고 다정한 자연의 향기"
        case .deepHouse:    return "세련된 도시의 밤거리를 닮은 절제된 감각의 비트"
        }
    }

    // Jazz: 가사 유무에 따른 다른 설명
    func descriptionText(for lyricsOption: LyricsOption) -> String {
        if self == .jazz && lyricsOption == .exclude {
            return "세련되고 낭만적인 밤의 여유를 담은 즉흥 선율"
        }
        return descriptionText
    }
}
