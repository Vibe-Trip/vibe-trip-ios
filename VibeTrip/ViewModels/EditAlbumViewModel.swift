//
//  EditAlbumViewModel.swift
//  VibeTrip
//
//  Created by CHOI on 4/5/26.
//

import UIKit
import Combine

// MARK: - EditAlbumViewModel

@MainActor
final class EditAlbumViewModel: ObservableObject {

    // MARK: - Published (편집 필드)

    @Published var selectedImage: UIImage? = nil    // nil: 이미지 미변경 (기존 URL 유지)
    @Published var albumTitle: String = ""          // UI 표시용 (서버 미전송, 백엔드 title 필드 추가 후 연동 예정)
    @Published var destination: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date()
    @Published var hasDateSelected: Bool = false    // 날짜 선택 완료 여부
    @Published var lyricsOption: LyricsOption = .exclude
    @Published var vocalGender: VocalGender? = nil
    @Published var selectedGenre: AlbumGenre? = nil
    @Published var commentary: String = ""

    // MARK: - Published (UI 상태)

    @Published private(set) var isLoading: Bool = false
    @Published var toastMessage: String? = nil

    // MARK: - 원본 스냅샷 (hasChanges 비교용)

    private var originalDestination: String = ""
    private var originalStartDate: Date = Date()
    private var originalEndDate: Date = Date()
    private var originalLyricsOption: LyricsOption = .exclude
    private var originalVocalGender: VocalGender? = nil
    private var originalGenre: AlbumGenre? = nil
    private var originalCommentary: String = ""

    // 이미지 미변경 시 기존 URL에서 재다운로드
    private(set) var coverImageUrl: URL? = nil

    // MARK: - Dependencies

    private let albumId: Int
    private let albumService: AlbumServiceProtocol
    let onSaved: () -> Void

    // MARK: - Computed

    // 서버 전송 대상 필드 기준 (title 제외)
    var hasChanges: Bool {
        selectedImage != nil
        || destination != originalDestination
        || startDate != originalStartDate
        || endDate != originalEndDate
        || lyricsOption != originalLyricsOption
        || vocalGender != originalVocalGender
        || selectedGenre != originalGenre
        || commentary != originalCommentary
    }

    var isValid: Bool {
        let hasPhoto = selectedImage != nil || coverImageUrl != nil
        let hasDestination = !destination.trimmingCharacters(in: .whitespaces).isEmpty
        let hasVocalIfNeeded = lyricsOption == .exclude || vocalGender != nil
        return hasPhoto && hasDestination && hasDateSelected && hasVocalIfNeeded
    }

    // MARK: - Init

    nonisolated init(
        albumId: Int,
        albumService: AlbumServiceProtocol = AlbumService(),
        onSaved: @escaping () -> Void
    ) {
        self.albumId = albumId
        self.albumService = albumService
        self.onSaved = onSaved
    }

    // MARK: - Load (Pre-fill)

    func load() async {
        guard let detail = try? await albumService.fetchAlbum(albumId: albumId) else { return }

        coverImageUrl = detail.coverImageUrl

        // "yyyy-MM-dd" 파싱
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let start = formatter.date(from: detail.travelStartDate) ?? Date()
        let end = formatter.date(from: detail.travelEndDate) ?? Date()

        let lyricsOpt: LyricsOption = detail.withLyrics ? .include : .exclude

        // 편집 상태 초기화
        albumTitle = detail.title ?? ""
        destination = detail.region
        startDate = start
        endDate = end
        hasDateSelected = true
        lyricsOption = lyricsOpt
        vocalGender = detail.vocalGender
        selectedGenre = detail.genre
        commentary = detail.comment ?? ""

        // 원본 스냅샷 저장
        originalDestination = destination
        originalStartDate = startDate
        originalEndDate = endDate
        originalLyricsOption = lyricsOption
        originalVocalGender = vocalGender
        originalGenre = selectedGenre
        originalCommentary = commentary
    }

    // MARK: - Submit

    func submitEdit() async {
        guard isValid else {
            toastMessage = "필수 입력 항목을 모두 입력해 주세요."
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            // 이미지: 새로 선택 → UIImage → Data, 미선택 → 기존 URL에서 재다운로드
            let imageData: Data
            if let image = selectedImage, let data = image.jpegData(compressionQuality: 0.8) {
                imageData = data
            } else if let url = coverImageUrl {
                let (data, _) = try await URLSession.shared.data(from: url)
                imageData = data
            } else {
                toastMessage = "사진을 선택해 주세요."
                return
            }

            let request = AlbumUpdateRequest(
                photoData: imageData,
                location: destination,
                startDate: startDate,
                endDate: endDate,
                lyricsOption: lyricsOption,
                vocalGender: vocalGender,
                genre: selectedGenre ?? (lyricsOption == .include ? .pop : .loFi),
                comment: commentary
            )
            try await albumService.updateAlbum(albumId: String(albumId), request: request)
            onSaved()
        } catch {
            toastMessage = "수정에 실패했어요. 다시 시도해 주세요."
        }
    }
}
