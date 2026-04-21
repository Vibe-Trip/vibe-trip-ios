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

    // MARK: - 로딩 화면 에러 상태

    // networkError: 재시도 팝업 / fatalError: 확인 단일 버튼 팝업
    enum AlbumCreationLoadingError {
        case networkError
        case fatalError
    }

    // MARK: - Input State

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
    
    private let albumService: AlbumServiceProtocol

    // 네트워크 오류 시 생성 데이터 보관 -> 재시도에 사용
    private var pendingRequest: AlbumCreateRequest?

    init(albumService: AlbumServiceProtocol = AlbumService()) {
        self.albumService = albumService
    }

    // MARK: - Constants

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
            return "미선택 시 장르는 Lofi로 선택됩니다"
        }
    }
    
    // 생성 시 미선택 장르에 적용할 내부 기본값
    var resolvedGenre: AlbumGenre {
        album.selectedGenre ?? defaultGenre
    }
    
    var defaultGenre: AlbumGenre {
        album.lyricsOption == .include ? .pop : .loFi
    }
    
    // 장르 설명 모달 데이터
    var genreDescriptions: [GenreDescriptionModel] {
        displayedGenres.map { GenreDescriptionModel(genre: $0, description: $0.descriptionText(for: album.lyricsOption)) }
    }
    
    // 선택한 사진의 용량 및 디코딩 가능 여부 검증
    func handleSelectedPhotoData(_ data: Data?) {
        guard let data else {
            return
        }
        
        guard data.count <= maximumPhotoBytes else {
            clearPhotoSelection()
            showToast("10MB보다 작은 사진을 골라주세요.")
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
            showToast("여행지 이름은 25자까지만 쓸 수 있어요.")
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
    
    // MARK: - Step Navigation

    // 필수 입력 완료 시 선택 입력 단계로 이동
    func proceedToOptionalStep() {
        guard isRequiredInputValid else {
            showToast("필수 입력 항목을 모두 입력해 주세요.")
            return
        }
        currentStep = .optionalInput
    }

    func returnToRequiredStep() {
        currentStep = .requiredInput
    }

    // MARK: - Album Creation

    // 앨범 생성 요청 진입점: 로딩 단계로 전환 후 API 호출
    // onStarted: LoadingView 노출 트리거
    // onSuccess: 생성 완료(albumId 전달)
    // onNetworkError: 네트워크 오류 시 재시도 클로저 전달
    // onFatalError: 재시도 불가 오류 시 확인 팝업 트리거
    func submitAlbum(
        onStarted: @escaping () -> Void,
        onSuccess: @escaping (Int) -> Void,
        onNetworkError: @escaping (@escaping () -> Void) -> Void,
        onFatalError: @escaping () -> Void
    ) {
        guard let photoData = selectedPhotoData,
              let startDate = album.startDate,
              let endDate = album.endDate else { return }

        let request = AlbumCreateRequest(
            photoData: photoData,
            location: album.travelDestination,
            startDate: startDate,
            endDate: endDate,
            lyricsOption: album.lyricsOption,
            vocalGender: album.vocalGender,
            genre: resolvedGenre,
            comment: album.albumCommentary
        )
        pendingRequest = request
        currentStep = .loading
        onStarted()

        Task {
            await performRequest(
                request,
                isRetry: false,
                onSuccess: onSuccess,
                onNetworkError: onNetworkError,
                onFatalError: onFatalError
            )
        }
    }

    // 공통 API 실행: 첫 시도/재시도 모두 이 메서드 거침
    private func performRequest(
        _ request: AlbumCreateRequest,
        isRetry: Bool,
        onSuccess: @escaping (Int) -> Void,
        onNetworkError: @escaping (@escaping () -> Void) -> Void,
        onFatalError: @escaping () -> Void
    ) async {
        do {
            let response = try await albumService.createAlbum(request: request)
            onSuccess(response.albumId)
        } catch APIClientError.networkError(let urlError) where !isRetry {
            #if DEBUG
            print("[AlbumCreate][Flow] networkError firstAttempt=\(urlError.code.rawValue)")
            #endif
            // 최초 1회 네트워크 오류만 재시도 허용
            let retryAction: () -> Void = { [weak self] in
                guard let self, let req = self.pendingRequest else { return }
                Task {
                    await self.performRequest(
                        req,
                        isRetry: true,
                        onSuccess: onSuccess,
                        onNetworkError: onNetworkError,
                        onFatalError: onFatalError
                    )
                }
            }
            onNetworkError(retryAction)
        } catch {
            #if DEBUG
            print("[AlbumCreate][Flow] fatalError isRetry=\(isRetry) error=\(error)")
            #endif
            // networkError 재시도 실패 or serverError or decodingFailed or unknown
            onFatalError()
        }
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
