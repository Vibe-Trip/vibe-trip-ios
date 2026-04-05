//
//  AlbumLogViewModel.swift
//  VibeTrip
//
//  Created by CHOI on 3/22/26.
//

import Foundation
import Combine
import UIKit

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
    // 선택된 사진 목록 (수정 모드: 앞쪽 existingPhotosCount개가 기존 사진, 뒤쪽이 새 사진)
    @Published var selectedPhotos: [UIImage] = []
    // 기존 사진 수 (수정 모드에서 URL 로딩 완료 후 확정) —> 뷰에서 컨텍스트 메뉴 조건 판단에 사용
    @Published private(set) var existingPhotosCount: Int = 0
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

    // 변경 감지: 이탈 팝업 노출 판단
    var hasUnsavedChanges: Bool {
        if logText != initialText { return true }
        switch mode {
        case .create: return !selectedPhotos.isEmpty
        case .edit:   return selectedPhotos.count > existingPhotosCount
        }
    }

    // MARK: - Private

    private let service: AlbumServiceProtocol
    private let initialText: String
    private var albumLogId: Int?
    // 현재 남아있는 기존 이미지 ID 목록
    private var existingImageIds: [Int64] = []
    // 삭제된 기존 이미지 ID 목록 (PUT 요청 시 removeImageIds로 전달)
    private var removedImageIds: [Int64] = []

    private enum Constants {
        static let maxPhotoCount = 5
        static let photoLimitMessage = "사진은 최대 5장까지 등록할 수 있어요"
        static let saveErrorMessage = "저장 중 오류가 발생했어요."
        static let timeFormat = "a h:mm"
    }

    // MARK: - Init

    init(
        albumId: String,
        mode: LogViewMode,
        service: AlbumServiceProtocol = AlbumService()
    ) {
        self.albumId = albumId
        self.mode = mode
        self.service = service

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
            existingPhotosCount = entry.images.count
            existingImageIds = entry.images.map(\.id)
            Task { await loadExistingPhotos(from: entry.images.map(\.imageUrl)) }
        }
    }

    // MARK: - Methods

    func insertCurrentTime() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = Constants.timeFormat
        logText += "\(formatter.string(from: Date())) "
    }

    // 사진 추가 -> 5장 초과 시 토스트 표시
    func addPhotos(_ images: [UIImage]) {
        let available = Constants.maxPhotoCount - selectedPhotos.count
        guard available > 0 else {
            showToast(Constants.photoLimitMessage)
            return
        }
        selectedPhotos.append(contentsOf: images.prefix(available))
        if images.count > available {
            showToast(Constants.photoLimitMessage)
        }
    }

    // 특정 인덱스 사진 삭제
    func removePhoto(at index: Int) {
        guard selectedPhotos.indices.contains(index) else { return }
        selectedPhotos.remove(at: index)
        if index < existingPhotosCount {
            // 기존 사진 삭제: ID를 removedImageIds에 기록 후 existingImageIds에서 제거
            removedImageIds.append(existingImageIds[index])
            existingImageIds.remove(at: index)
            existingPhotosCount -= 1
        }
    }

    // 로그 저장 (작성: POST, 수정: PUT)
    func saveLog() async {
        isSaving = true
        defer { isSaving = false }
        do {
            switch mode {
            case .create:
                let photoDataList = selectedPhotos.compactMap {
                    $0.jpegData(compressionQuality: 0.8)
                }
                let request = AlbumLogRequest(
                    albumId: albumId,
                    logText: logText,
                    photoDataList: photoDataList
                )
                try await service.saveLog(request: request)

            case .edit:
                guard let albumLogId else { return }
                // 기존 사진 이후 인덱스만 새 사진으로 전송
                let newPhotos = Array(selectedPhotos.dropFirst(existingPhotosCount))
                let newPhotoDataList = newPhotos.compactMap {
                    $0.jpegData(compressionQuality: 0.8)
                }
                let request = AlbumLogUpdateRequest(
                    albumId: albumId,
                    albumLogId: albumLogId,
                    logText: logText,
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

    // 수정 모드: 기존 이미지 URL -> UIImage 로딩 (selectedPhotos 앞쪽에 삽입)
    private func loadExistingPhotos(from urls: [URL]) async {
        var loaded: [UIImage] = []
        for url in urls {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                loaded.append(image)
            }
        }
        selectedPhotos.insert(contentsOf: loaded, at: 0)
        existingPhotosCount = loaded.count  // 실제 로딩 성공한 수로 보정
    }
}
