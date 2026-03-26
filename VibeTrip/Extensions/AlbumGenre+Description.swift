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
        case .pop:          return "누구나 즐길 수 있는 대중적이고 산뜻한 리듬"
        case .kPop:         return "전 세계를 사로잡은 화려하고 트렌디한 사운드"
        case .ballad:       return "감미로운 선율에 담긴 깊은 서사와 애절한 울림"
        case .hipHop:       return "강렬한 비트 위에 펼쳐지는 자유로운 리듬의 향연"
        case .rnb:          return "부드럽고 그루비한 보컬이 매력적인 소울풀한 감성"
        case .rock:         return "심장을 울리는 강렬한 밴드 사운드와 뜨거운 에너지"
        case .cityPop:      return "세련된 도시의 밤이 느껴지는 레트로한 도심 무드"
        case .edm:          return "심박수를 높이는 짜릿한 전자음과 페스티벌 분위기"
        case .latinPop:     return "정렬적이고 태양처럼 뜨거운 댄서블한 라틴 리듬"
        case .country:      return "따뜻하고 정겨운 어쿠스틱 악기가 주는 향수"
        case .indie:        return "나만 알고 싶은 담백하고 독창적인 감성과 개성"
        case .gospel:       return "풍성한 화음이 전하는 평온함과 영성 어린 위로"
        case .classical:    return "웅장하고 품격있는 정통 오케스트라의 깊은 선율"
        case .loFi:         return "나른한 오후, 일상의 소음이 섞인 편안하고 빈티지한 비트"
        case .jazz:         return "세련된 선율, 자유로운 리듬이 만드는 여유로운 카페 분위기"
        case .ambient:      return "공간을 가득 채우는 몽환적이고 고요한 명상 같은 사운드"
        case .cinematic:    return "영화 속 한 장면처럼 서사적이고 웅장한 감동의 연주"
        case .newAge:       return "지친 마음을 부드럽게 어루만지는 맑고 평온한 힐링 사운드"
        case .acoustic:     return "악기 본연의 울림이 전하는 따뜻하고 순수한 날 것의 감성"
        case .electronic:   return "감각적인 합성음이 선사하는 세련되고 현대적인 도시 무드"
        case .bossaNova:    return "나른한 햇살 아래 여유로운 해변의 정취가 느껴지는 선율"
        case .chillHop:     return "부드러운 그루브와 편안한 리듬이 공존하는 여유로운 휴식"
        case .tropicalHouse: return "시원한 바닷바람처럼 청량하고 밝은 에너지 가득한 사운드"
        case .techno:       return "반복적인 비트가 선사하는 강렬한 몰입감과 기계적인 미학"
        }
    }
}
