//
//  AlbumLogViewModel.swift
//  VibeTrip
//
//  Created by CHOI on 3/22/26.
//

import Foundation
import Combine
import UIKit

// MARK: - Photo State Types

// 서버에서 받아온 기존 사진
// image -> 비동기 로딩 중/실패 시 nil 유지
struct ExistingPhoto: Identifiable {
    let id: Int64        // 서버 image id
    let url: URL
    var image: UIImage?
}

// 사용자가 이번 편집 세션에서 새로 추가한 사진
struct NewPhoto: Identifiable {
    let id: UUID = UUID()
    let image: UIImage
}

// View 가 단일 리스트로 다루기 위한 표시 모델 (기존 + 신규 결합)
struct PhotoSlot: Identifiable {
    enum Kind {
        case existing(id: Int64)
        case new(id: UUID)
    }
    let id: String       // "existing-\(id)" / "new-\(uuid)" — ForEach 안정성
    let kind: Kind
    let image: UIImage?
}

@MainActor final class AlbumLogViewModel: ObservableObject {

    // MARK: - LogViewMode

    // 작성 및 수정 모드 분기
    enum LogViewMode {
        case create /// 작성
        case edit(AlbumLogEntry) /// 수정
    }

    // MARK: - Published

    // 텍스트 입력 내용
    @Published var logText: String = ""
    // 기존 사진 (서버 id 보존, 이미지 로딩은 비동기)
    @Published private(set) var existingPhotos: [ExistingPhoto] = []
    // 사용자가 이번 세션에서 새로 추가한 사진
    @Published private(set) var newPhotos: [NewPhoto] = []
    // 하단 토스트 메시지
    @Published private(set) var toastMessage: String?
    // 종료 확인 팝업 표시 여부
    @Published var isExitAlertPresented: Bool = false
    // 저장 요청 진행 중 여부
    @Published private(set) var isSaving: Bool = false
    // 저장 성공 여부 (화면 전환 트리거)
    @Published private(set) var isSaved: Bool = false

    // MARK: - Properties

    let albumId: String
    let mode: LogViewMode
    // 날짜 헤더 표시용 -> 생성: 작성 날짜, 수정: 로그 작성 날짜
    let createdDate: Date

    // 저장 버튼 활성화 조건: 텍스트 1자 이상
    var isSaveEnabled: Bool {
        !logText.isEmpty
    }

    // 기존 + 신규 사진을 단일 리스트로 표현 (View -> ForEach 용)
    var photoSlots: [PhotoSlot] {
        let existing = existingPhotos.map { photo in
            PhotoSlot(
                id: "existing-\(photo.id)",
                kind: .existing(id: photo.id),
                image: photo.image
            )
        }
        let new = newPhotos.map { photo in
            PhotoSlot(
                id: "new-\(photo.id.uuidString)",
                kind: .new(id: photo.id),
                image: photo.image
            )
        }
        return existing + new
    }

    // 총 사진 개수 (5장 제한 계산용)
    var totalPhotoCount: Int {
        existingPhotos.count + newPhotos.count
    }

    // 사진 보유 여부
    var hasPhotos: Bool {
        totalPhotoCount > 0
    }

    // 변경 감지: 이탈 팝업 노출 판단
    var hasUnsavedChanges: Bool {
        if logText != initialText { return true }
        switch mode {
        case .create:
            return !newPhotos.isEmpty
        case .edit:
            return !newPhotos.isEmpty || !removedImageIds.isEmpty
        }
    }

    // MARK: - Private

    private let service: AlbumServiceProtocol
    private let initialText: String
    private var albumLogId: Int?
    // 삭제된 기존 이미지 ID 목록 (PUT 요청 시 removeImageIds로 전달)
    private var removedImageIds: [Int64] = []

    private enum Constants {
        static let maxPhotoCount = 5
        static let maximumPhotoBytes = 10 * 1024 * 1024
        static let photoLimitMessage = "사진은 최대 5장까지 고를 수 있어요."
        static let photoSizeLimitMessage = "10MB보다 작은 사진을 골라주세요."
        static let saveValidationMessage = "이야기를 작성해야 저장할 수 있어요."
        static let saveErrorMessage = "저장 중 오류가 발생했어요."
        static let timeFormat = "a h:mm"
    }

    // MARK: - Init

    private let analytics: AnalyticsServiceProtocol

    init(
        albumId: String,
        mode: LogViewMode,
        service: AlbumServiceProtocol = AlbumService(),
        analytics: AnalyticsServiceProtocol
    ) {
        self.albumId = albumId
        self.mode = mode
        self.service = service
        self.analytics = analytics

        switch mode {
        case .create:
            // 작성 모드
            createdDate = Date()
            initialText = ""

        case .edit(let entry):
            // 수정 모드: 기존 로그 데이터 pre-fill
            albumLogId = entry.id
            let prefilled = entry.description
            logText = prefilled
            initialText = prefilled
            createdDate = ISO8601DateFormatter().date(from: entry.postedAt) ?? Date()
            // 서버 이미지 전체를 image: nil 슬롯으로 즉시 보유 (로딩은 비동기)
            existingPhotos = entry.images.map {
                ExistingPhoto(id: $0.id, url: $0.imageUrl, image: nil)
            }
            Task { await loadExistingPhotoImages() }
        }
    }

    // MARK: - Methods

    func insertCurrentTime() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = Constants.timeFormat
        logText += "\(formatter.string(from: Date())) "
    }

    // 사진 추가 -> 기존 + 신규 합산 5장 초과 시 토스트 표시
    func addPhotos(_ images: [UIImage]) {
        let validImages = images.filter { image in
            guard let data = image.jpegData(compressionQuality: 1.0) else { return false }
            return data.count <= Constants.maximumPhotoBytes
        }
        if validImages.count < images.count {
            showToast(Constants.photoSizeLimitMessage)
        }

        let available = Constants.maxPhotoCount - totalPhotoCount
        guard available > 0 else {
            showToast(Constants.photoLimitMessage)
            return
        }
        let appended = Array(validImages.prefix(available))
        newPhotos.append(contentsOf: appended.map { NewPhoto(image: $0) })
        if validImages.count > available {
            showToast(Constants.photoLimitMessage)
        }
    }

    // 슬롯 기반 사진 삭제: 서버 id / UUID 로 정확히 매칭해 잘못된 항목 삭제를 방지
    func removePhoto(slot: PhotoSlot) {
        switch slot.kind {
        case .existing(let id):
            existingPhotos.removeAll { $0.id == id }
            if !removedImageIds.contains(id) {
                removedImageIds.append(id)
            }

        case .new(let uuid):
            newPhotos.removeAll { $0.id == uuid }
        }
    }

    // 로그 저장 (작성: POST, 수정: PUT)
    func saveLog() async {
        let trimmedLogText = logText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLogText.isEmpty else {
            showToast(Constants.saveValidationMessage)
            return
        }

        isSaving = true
        defer { isSaving = false }
        do {
            switch mode {
            case .create:
                let photoDataList = newPhotos.compactMap {
                    $0.image.jpegData(compressionQuality: 0.8)
                }
                let request = AlbumLogRequest(
                    albumId: albumId,
                    logText: trimmedLogText,
                    photoDataList: photoDataList
                )
                try await service.saveLog(request: request)
                // 로그 작성 추적
                analytics.log(.logSave, parameters: [
                    .charCount: trimmedLogText.count,
                    .hasPhoto: hasPhotos
                ])

            case .edit:
                guard let albumLogId else { return }
                let newPhotoDataList = newPhotos.compactMap {
                    $0.image.jpegData(compressionQuality: 0.8)
                }
                let request = AlbumLogUpdateRequest(
                    albumId: albumId,
                    albumLogId: albumLogId,
                    logText: trimmedLogText,
                    newPhotoDataList: newPhotoDataList,
                    removeImageIds: removedImageIds
                )
                try await service.updateLog(request: request)
            }
            isSaved = true
        } catch {
            print("[AlbumLogViewModel] saveLog 실패 -> albumId: \(albumId), error: \(error)")
            showToast(Constants.saveErrorMessage)
        }
    }

    // 토스트 메시지 표시
    func showToast(_ message: String) {
        toastMessage = message
    }

    func consumeToast() {
        toastMessage = nil
    }

    // MARK: - Private Methods

    // 수정 모드: existingPhotos 각 슬롯의 이미지를 비동기로 채움
    // 도중 삭제 안전성 위해 url 로 슬롯을 재탐색
    private func loadExistingPhotoImages() async {
        let urls = existingPhotos.map(\.url)
        for url in urls {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else {
                continue
            }
            if let idx = existingPhotos.firstIndex(where: { $0.url == url }) {
                existingPhotos[idx].image = image
            }
        }
    }
}
