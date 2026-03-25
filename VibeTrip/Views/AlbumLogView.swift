//
//  AlbumLogView.swift
//  VibeTrip
//
//  Created by CHOI on 3/22/26.
//

import SwiftUI
import PhotosUI

// MARK: - AlbumLogView

struct AlbumLogView: View {

    @StateObject private var viewModel: AlbumLogViewModel
    @Environment(\.dismiss) private var dismiss

    // TextEditor 포커스 제어 (scrollDismissesKeyboard 연동)
    @FocusState private var isFocused: Bool

    // 사진 슬라이드
    @State private var currentPhotoIndex: Int = 0

    // PhotosPicker 표시 여부
    @State private var isPhotoPickerPresented: Bool = false
    @State private var photoPickerItems: [PhotosPickerItem] = []

    // 토스트 제어
    @State private var isToastVisible: Bool = false

    // 블러 배경 제어
    @State private var isDragging: Bool = false

    private enum Constants {
        static let photoAreaHeight: CGFloat = 272
        static let photoCornerRadius: CGFloat = 12
        
        static let contentHorizontalPadding: CGFloat = 20
        static let dateHeaderVerticalPadding: CGFloat = 16
        
        static let toolbarHeight: CGFloat = 50
        static let toolbarIconSize: CGFloat = 34
        static let toolbarIconSpacing: CGFloat = 14
        
        static let cameraIconWidth: CGFloat = 26
        static let cameraIconHeight: CGFloat = 20
        
        static let clockIconSize: CGFloat = 23
        
        static let toastBottomPadding: CGFloat = 20
        static let toastDuration: Double = 3.0
        
        static let textEditorMinHeight: CGFloat = 200
        static let textEditorTopPadding: CGFloat = 20
        static let textEditorInsetCorrection: CGFloat = 5
        
        // 페이지 컨트롤
        static let dotSize: CGFloat = 6
        static let dotSpacing: CGFloat = 6
        static let indicatorBottomPadding: CGFloat = 12
        static let indicatorPaddingH: CGFloat = 10
        static let indicatorPaddingV: CGFloat = 7
    }

    // MARK: - Init

    init(albumId: String, mode: AlbumLogViewModel.LogViewMode) {
        _viewModel = StateObject(
            wrappedValue: AlbumLogViewModel(
                albumId: albumId,
                mode: mode,
                service: MockAlbumService() // TODO: 서버 확정 후 AlbumService()로 교체
            )
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // 메인 콘텐츠 스크롤 영역
            ScrollView {
                VStack(spacing: 0) {
                    dateHeader

                    // 사진이 있을 때만 사진 슬라이드 영역 표시
                    if !viewModel.selectedPhotos.isEmpty {
                        photoArea
                    }

                    textEditorArea
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { isFocused = false }     // 빈 영역 탭 시 키보드 해제
            .safeAreaInset(edge: .top, spacing: 0) { // bottomToolbar 영역 확보 + 키보드 올라올 때 툴바도 함께 이동
                // AppNavigationBar: 상단 safe area에 고정
                // trailing에 저장 버튼 주입
                AppNavigationBar(title: navTitle, onBackTap: handleBackButton) {
                    Button {
                        Task { await viewModel.saveLog() }
                    } label: {
                        Text("저장")
                            .font(.setPretendard(weight: .semiBold, size: 16))
                            .foregroundStyle(
                                viewModel.isSaveEnabled
                                ? Color.appPrimary
                                : Color.buttonDisabledForeground
                            )
                    }
                    .disabled(!viewModel.isSaveEnabled)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // 하단 툴바
                bottomToolbar
            }

            // 종료 확인 팝업
            if viewModel.isExitAlertPresented {
                exitPopup
            }

            // 토스트 메시지
            if isToastVisible, let message = viewModel.toastMessage {
                AppToastView(message: message)
                    .padding(.bottom, Constants.toolbarHeight + Constants.toastBottomPadding)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)  // 시스템 네비게이션바 숨김
        .background(Color.white)
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $photoPickerItems,
            maxSelectionCount: max(1, 5 - viewModel.selectedPhotos.count),
            matching: .images
        )
        .onChange(of: photoPickerItems) { items in
            loadPhotos(from: items)
        }
        .onChange(of: viewModel.toastMessage) { message in
            guard message != nil else { return }
            showToast()
        }
    }
}

// MARK: - Subviews

private extension AlbumLogView {

    // 날짜 섹션
    var dateHeader: some View {
        VStack(spacing: 0) {
            Text(viewModel.createdDate, formatter: Self.dateFormatter)
                .font(.setPretendard(weight: .regular, size: 16))
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, Constants.contentHorizontalPadding)
                .padding(.vertical, Constants.dateHeaderVerticalPadding)

            // 섹션 구분선
            Rectangle()
                .fill(Color.fieldBorder)
                .frame(height: 1)
        }
    }

    // 사진 슬라이드 영역
    var photoArea: some View {
        TabView(selection: $currentPhotoIndex) {
            ForEach(viewModel.selectedPhotos.indices, id: \.self) { index in
                Image(uiImage: viewModel.selectedPhotos[index])
                    .resizable()
                    .scaledToFill()
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: Constants.photoAreaHeight)
        .overlay(alignment: .bottom) {
            // 사진 2장 이상일 때만 커스텀 인디케이터 표시
            if viewModel.selectedPhotos.count > 1 {
                pageIndicator
                    .padding(.bottom, Constants.indicatorBottomPadding)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Constants.photoCornerRadius))
        .padding(.horizontal, Constants.contentHorizontalPadding)
        .simultaneousGesture(
            // 드래그 상태 추적: 스와이프 중에만 블러 배경 표시
            DragGesture(minimumDistance: 10)
                .onChanged { _ in isDragging = true }
                .onEnded   { _ in isDragging = false }
        )
    }

    // 커스텀 페이지 인디케이터
    private var pageIndicator: some View {
        HStack(spacing: Constants.dotSpacing) {
            ForEach(viewModel.selectedPhotos.indices, id: \.self) { i in
                Circle()
                    .frame(width: Constants.dotSize, height: Constants.dotSize)
                    .foregroundStyle(i == currentPhotoIndex ? Color.appPrimary : Color.white)
            }
        }
        .padding(.horizontal, Constants.indicatorPaddingH)
        .padding(.vertical, Constants.indicatorPaddingV)
        .background {
            if isDragging {
                Capsule()
                    .fill(.regularMaterial)
            }
        }
    }

    // TextEditor 입력 필드
    var textEditorArea: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.logText.isEmpty {
                Text("여행지에서 느꼈던 추억을 기록해보세요.")
                    .font(.setPretendard(weight: .regular, size: 16))
                    .lineSpacing(8)
                    .foregroundStyle(Color.placeholderText)
                    .padding(.horizontal, Constants.contentHorizontalPadding)
                    .padding(.top, Constants.textEditorTopPadding)
            }

            TextEditor(text: $viewModel.logText)
                .font(.setPretendard(weight: .regular, size: 16))
                .lineSpacing(8)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, Constants.contentHorizontalPadding - Constants.textEditorInsetCorrection)
                .padding(.top, Constants.textEditorTopPadding - Constants.textEditorInsetCorrection)
                .frame(minHeight: Constants.textEditorMinHeight)
        }
    }

    // 하단 아이콘 툴바
    var bottomToolbar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.fieldBorder)
                .frame(height: 1)

            HStack(spacing: Constants.toolbarIconSpacing) {
                // 카메라 아이콘
                Button {
                    guard viewModel.selectedPhotos.count < 5 else {
                        viewModel.showToast("사진은 최대 5장까지 등록할 수 있어요")
                        return
                    }
                    isPhotoPickerPresented = true
                } label: {
                    Image(systemName: "camera")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: Constants.cameraIconWidth, height: Constants.cameraIconHeight)
                        .foregroundStyle(Color.placeholderText)
                        .frame(width: Constants.toolbarIconSize, height: Constants.toolbarIconSize)
                }

                // 타임스탬프 아이콘
                Button {
                    viewModel.insertCurrentTime()
                } label: {
                    Image(systemName: "clock")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: Constants.clockIconSize, height: Constants.clockIconSize)
                        .foregroundStyle(Color.placeholderText)
                        .frame(width: Constants.toolbarIconSize, height: Constants.toolbarIconSize)
                }

                Spacer()
            }
            .padding(.horizontal, Constants.contentHorizontalPadding)
            .frame(height: Constants.toolbarHeight - 1)
            .background(Color.white)
        }
    }

    // 종료 확인 팝업
    var exitPopup: some View {
        ExitPopupView(
            title: "저장하지 않고 나갈까요?",
            message: "페이지를 벗어나면 작성 중인 내용이\n저장되지 않고 사라지게 돼요.",
            onCancel: {
                viewModel.isExitAlertPresented = false
            },
            onConfirm: {
                dismiss()
            }
        )
    }

}

// MARK: - Helpers

private extension AlbumLogView {

    // 날짜 헤더 포맷
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter
    }()

    // 네비게이션 타이틀 분기
    var navTitle: String {
        switch viewModel.mode {
        case .create: return "로그 작성"
        case .edit:   return "로그 수정"
        }
    }

    // 뒤로가기 처리
    func handleBackButton() {
        if viewModel.hasUnsavedChanges {
            viewModel.isExitAlertPresented = true
        } else {
            dismiss()
        }
    }
    
    func loadPhotos(from items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            viewModel.addPhotos(images)
            // 재선택 가능하도록 items 초기화
            photoPickerItems = []
        }
    }

    func showToast() {
        withAnimation { isToastVisible = true }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(Constants.toastDuration * 1_000_000_000))
            withAnimation { isToastVisible = false }
            viewModel.consumeToast()
        }
    }
}

// MARK: - Preview

#Preview("로그 작성 모드") {
    NavigationStack {
        AlbumLogView(albumId: "1", mode: .create)
    }
}

#Preview("로그 수정 모드") {
    NavigationStack {
        AlbumLogView(albumId: "1", mode: .edit(AlbumLog.mock))
    }
}
