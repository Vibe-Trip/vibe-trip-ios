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
        case edit(AlbumLog) /// 수정
    }
    
    // MARK: - Published
    
    // 텍스트 입력 내용
    @Published var logText: String = ""
    // 선택된 사진 목록
    @Published var selectedPhotos: [UIImage] = []
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
    // 날짜 헤더 표시용 -> 생성: 작성 날짜, 수정: 생성 날짜
    let createdDate: Date
    
    // 저장 버튼 활성화 조건: 텍스트 1자 이상
    var isSaveEnabled: Bool {
        !logText.isEmpty
    }
    
    // 변경 감지: 이탈 팝업 노출 판단
    var hasUnsavedChanges: Bool {
        logText != initialText || selectedPhotos.count != initialPhotoCount
    }
    
    // MARK: - Private
    
    private let service: AlbumServiceProtocol
    private let initialText: String
    private let initialPhotoCount: Int
    
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
            initialPhotoCount = 0
            
        case .edit(let log):
            // 수정 모드: 기존 로그 데이터 pre-fill
            createdDate = log.startDate
            let prefilled = log.logText ?? ""
            logText = prefilled
            initialText = prefilled
            // TODO: logPhotoUrls -> UIImage 변환 (서버 연동 후 구현)
            initialPhotoCount = log.logPhotoUrls.count
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
    
    // TODO: 특정 인덱스 사진 삭제
    func removePhoto(at index: Int) {
        guard selectedPhotos.indices.contains(index) else { return }
        selectedPhotos.remove(at: index)
    }
    
    // 로그 저장
    func saveLog() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let photoDataList = selectedPhotos.compactMap {
                $0.jpegData(compressionQuality: 0.8)
            }
            let request = AlbumLogRequest(
                albumId: albumId,
                logText: logText,
                photoDataList: photoDataList
            )
            try await service.saveLog(request: request)
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
}
