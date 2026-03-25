//
//  MakeAlbumViewModel.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import Foundation
import SwiftUI
import UIKit
import Combine

// 앨범 생성 플로우의 입력 상태, 검증, 단계 전환을 담당하는 ViewModel
@MainActor
final class MakeAlbumViewModel: ObservableObject {
    
    // 사용자가 입력한 앨범 생성 데이터
    @Published var album = MakeAlbumModel()
    
    // 선택한 이미지: 최종 업로드 상태로 유지
    @Published var selectedPhotoData: Data?
    @Published var selectedPhotoImage: UIImage?
    
    // 현재 플로우 단계
    @Published var currentStep: AlbumCreationStep = .requiredInput
    
    // 공통 UI 상태
    @Published var toastMessage: String?
    @Published var isExitAlertPresented = false
    @Published var isDatePickerPresented = false
    @Published var isGenreDescriptionPresented = false
    
    // 날짜 선택 시트에서 임시 편집 중인 값
    @Published var stagedStartDate = Date()
    @Published var stagedEndDate: Date?
    
    private let maximumDestinationCount = 25
    private let maximumCommentaryCount = 500
    private let maximumPhotoBytes = 10 * 1024 * 1024
    
    // 필수 입력 화면 사진 박스에 표시할 썸네일
    var displayedPhotoImage: UIImage? {
        selectedPhotoImage
    }
    
    // 필수 입력 뷰에 입력된 데이터 여부 확인 -> 이탈 팝업 노출 여부 판단
    var hasStartedRequiredInput: Bool {
        selectedPhotoData != nil ||
        !album.travelDestination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        album.startDate != nil ||
        album.endDate != nil ||
        album.vocalGender != nil
    }
    
    // 다음으로 버튼 활성화 조건
    var isRequiredInputValid: Bool {
        guard selectedPhotoData != nil else {
            return false
        }
        
        guard !album.travelDestination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        guard album.startDate != nil, album.endDate != nil else {
            return false
        }
        
        if album.lyricsOption == .include {
            return album.vocalGender != nil
        }
        
        return true
    }
    
    // 가사 포함 여부에 따라 장르 목록 분기
    var displayedGenres: [AlbumGenre] {
        album.lyricsOption == .include ? AlbumGenre.vocalGenres : AlbumGenre.instrumentalGenres
    }
    
    // 장르 미선택 상태 안내 문구
    var genreHelperText: String {
        switch album.lyricsOption {
        case .include:
            return "미선택 시 장르는 Pop으로 선택됩니다"
        case .exclude:
            return "미선택 시 장르는 Classical로 선택됩니다"
        }
    }
    
    // 생성 시 미선택 장르에 적용할 내부 기본값
    var resolvedGenre: AlbumGenre {
        album.selectedGenre ?? defaultGenre
    }
    
    var defaultGenre: AlbumGenre {
        album.lyricsOption == .include ? .pop : .classical
    }
    
    // 장르 설명 모달 데이터
    var genreDescriptions: [GenreDescriptionModel] {
        let descriptions: [AlbumGenre: String] = [
            .pop: "누구나 즐길 수 있는 대중적이고 산뜻한 리듬",
            .kPop: "전 세계를 사로잡은 화려하고 트렌디한 사운드",
            .ballad: "감미로운 선율에 담긴 깊은 서사와 애절한 울림",
            .hipHop: "강렬한 비트 위에 펼쳐지는 자유로운 리듬의 향연",
            .rnb: "부드럽고 그루비한 보컬이 매력적인 소울풀한 감성",
            .rock: "심장을 울리는 강렬한 밴드 사운드와 뜨거운 에너지",
            .cityPop: "세련된 도시의 밤이 느껴지는 레트로한 도심 무드",
            .edm: "심박수를 높이는 짜릿한 전자음과 페스티벌 분위기",
            .latinPop: "정렬적이고 태양처럼 뜨거운 댄서블한 라틴 리듬",
            .country: "따뜻하고 정겨운 어쿠스틱 악기가 주는 향수",
            .indie: "나만 알고 싶은 담백하고 독창적인 감성과 개성",
            .gospel: "풍성한 화음이 전하는 평온함과 영성 어린 위로",
            .classical: "웅장하고 품격있는 정통 오케스트라의 깊은 선율",
            .loFi: "나른한 오후, 일상의 소음이 섞인 편안하고 빈티지한 비트",
            .jazz: "세련된 선율, 자유로운 리듬이 만드는 여유로운 카페 분위기",
            .ambient: "공간을 가득 채우는 몽환적이고 고요한 명상 같은 사운드",
            .cinematic: "영화 속 한 장면처럼 서사적이고 웅장한 감동의 연주",
            .newAge: "지친 마음을 부드럽게 어루만지는 맑고 평온한 힐링 사운드",
            .acoustic: "악기 본연의 울림이 전하는 따뜻하고 순수한 날 것의 감성",
            .electronic: "감각적인 합성음이 선사하는 세련되고 현대적인 도시 무드",
            .bossaNova: "나른한 햇살 아래 여유로운 해변의 정취가 느껴지는 선율",
            .chillHop: "부드러운 그루브와 편안한 리듬이 공존하는 여유로운 휴식",
            .tropicalHouse: "시원한 바닷바람처럼 청량하고 밝은 에너지 가득한 사운드",
            .techno: "반복적인 비트가 선사하는 강렬한 몰입감과 기계적인 미학"
        ]
        
        return displayedGenres.compactMap { genre in
            guard let description = descriptions[genre] else {
                return nil
            }
            
            return GenreDescriptionModel(genre: genre, description: description)
        }
    }
    
    // 선택한 사진의 용량 및 디코딩 가능 여부 검증
    func handleSelectedPhotoData(_ data: Data?) {
        guard let data else {
            return
        }
        
        guard data.count <= maximumPhotoBytes else {
            clearPhotoSelection()
            showToast("10MB 이하의 사진만 올릴 수 있어요")
            return
        }
        
        guard let image = UIImage(data: data) else {
            clearPhotoSelection()
            showToast("사진을 불러오지 못했어요. 다시 시도해 주세요.")
            return
        }
        
        selectedPhotoData = data
        selectedPhotoImage = image
    }
    
    // 여행지: 25자 제한
    func updateTravelDestination(_ text: String) {
        let limitedText = String(text.prefix(maximumDestinationCount))
        
        if text != limitedText {
            showToast("25자 이상 입력 불가해요.")
        }
        
        album.travelDestination = limitedText
    }
    
    // 코멘터리: 500자 제한
    func updateAlbumCommentary(_ text: String) {
        let limited = String(text.prefix(maximumCommentaryCount))
        if text != limited {
            showToast("500자 이상 입력 불가해요.")
        }
        album.albumCommentary = limited
    }
    
    // 가사 포함 여부 변경 대응
    func updateLyricsOption(_ option: LyricsOption) {
        let previousGenres = displayedGenres
        album.lyricsOption = option
        
        if option == .exclude {
            album.vocalGender = nil
        }
        
        let newGenres = displayedGenres
        if let selectedGenre = album.selectedGenre,
           !newGenres.contains(selectedGenre),
           previousGenres != newGenres {
            album.selectedGenre = nil
        }
    }
    
    // 같은 장르 다시 누르면 선택 해제
    func toggleGenre(_ genre: AlbumGenre) {
        album.selectedGenre = album.selectedGenre == genre ? nil : genre
    }
    
    // 날짜 선택 시트 오픈 전 입력된 값 staging 상태로 복사
    func presentDatePicker() {
        stagedStartDate = album.startDate ?? Date()
        stagedEndDate = album.endDate ?? album.startDate ?? Date()
        isDatePickerPresented = true
    }
    
    // 시트에서 선택한 날짜 범위 실제 입력 상태 반영
    func applyDateSelection() {
        album.startDate = stagedStartDate
        album.endDate = stagedEndDate ?? stagedStartDate
        isDatePickerPresented = false
    }
    
    // 종료일이 시작일 전일 경우 조정
    func updateStagedStartDate(_ date: Date) {
        stagedStartDate = date
        
        if let stagedEndDate, stagedEndDate < date {
            self.stagedEndDate = date
        }
    }
    
    // 종료일이 시작일 전일 경우: 종료일이 시작일
    func updateStagedEndDate(_ date: Date) {
        if date < stagedStartDate {
            stagedStartDate = date
            stagedEndDate = date
            return
        }
        
        stagedEndDate = date
    }
    
    // 필수 입력 필드 감지
    func proceedToOptionalStep() {
        guard isRequiredInputValid else {
            showToast("필수 입력 항목을 모두 입력해 주세요.")
            return
        }
        
        currentStep = .optionalInput
    }
    
    func proceedToLoadingStep() {
        currentStep = .loading
    }
    
    func returnToRequiredStep() {
        currentStep = .requiredInput
    }
    
    func showToast(_ message: String) {
        toastMessage = message
    }
    
    func consumeToast() {
        toastMessage = nil
    }
    
    // 사진 검증 실패 시
    private func clearPhotoSelection() {
        selectedPhotoData = nil
        selectedPhotoImage = nil
    }
}
