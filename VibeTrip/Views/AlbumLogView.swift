//
//  AlbumLogView.swift
//  VibeTrip
//
//  Created by CHOI on 3/22/26.
//

import SwiftUI

// MARK: - AlbumLogView

struct AlbumLogView: View {

    @StateObject private var viewModel: AlbumLogViewModel
    @Environment(\.dismiss) private var dismiss

    // 저장 완료 시 호출 (목록 재조회 여부 판단에 사용)
    private let onSaved: (() -> Void)?

    // TextEditor 포커스 제어 (scrollDismissesKeyboard 연동)
    @FocusState private var isFocused: Bool

    // 키보드 높이 추적 (커서 추적 스크롤에 사용)
    @State private var keyboardHeight: CGFloat = 0

    // 보고 있는 사진 위치 관리
    @State private var currentPhotoIndex: Int = 0
    
    // PhotoPicker 표시 여부
    @State private var isPhotoPickerPresented: Bool = false

    // 토스트 제어
    @State private var isToastVisible: Bool = false

    private enum Constants {
        static let photoAreaHeight: CGFloat = 272
        static let photoCornerRadius: CGFloat = 12
        static let photoTopSpacing: CGFloat = 26
        
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
        // 페이지 인디케이터
        static let dotSize: CGFloat = 6                
        static let dotSpacing: CGFloat = 6
        static let indicatorBottomPadding: CGFloat = 12
        static let indicatorPaddingH: CGFloat = 10
        static let indicatorPaddingV: CGFloat = 7
    }

    // MARK: - Init

    @MainActor
    init(albumId: String, mode: AlbumLogViewModel.LogViewMode, onSaved: (() -> Void)? = nil) {
        self.onSaved = onSaved
        _viewModel = StateObject(
            wrappedValue: AlbumLogViewModel(
                albumId: albumId,
                mode: mode,
                service: AlbumService()
            )
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // 메인 콘텐츠 스크롤 영역
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        dateHeader

                        // 사진이 있을 때만 사진 슬라이드 영역 표시
                        if !viewModel.selectedPhotos.isEmpty {
                            photoArea
                        }

                        textEditorArea
                            .id("textEditor")   // 커서 추적 스크롤 앵커
                    }
                    // 빈 영역 탭으로 키보드 비활성화
                    .contentShape(Rectangle())
                    // 키보드 높이만큼 여백 추가 -> 커서가 키보드 뒤로 숨지 않게 설정
                    .padding(.bottom, keyboardHeight)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture { isFocused = false }     // 화면 탭 시 키보드 해제
                .safeAreaInset(edge: .top, spacing: 0) { // bottomToolbar 영역 확보 + 키보드 올라올 때 툴바도 함께 이동
                    // AppNavigationBar: 상단 safe area에 고정
                    // trailing에 저장 버튼 주입
                    AppNavigationBar(title: navTitle, style: .solidWhite, onBackTap: handleBackButton) {
                        Button {
                            Task { await viewModel.saveLog() }
                        } label: {
                            if viewModel.isSaving {
                                ProgressView()
                                    .tint(Color.appPrimary)
                                    .frame(width: 44, height: 44)
                            } else {
                                Text("저장")
                                    .font(.setPretendard(weight: .semiBold, size: 16))
                                    .foregroundStyle(
                                        viewModel.isSaveEnabled
                                        ? Color.appPrimary
                                        : Color.buttonDisabledForeground
                                    )
                            }
                        }
                        .disabled(!viewModel.isSaveEnabled || viewModel.isSaving)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    // 하단 툴바
                    bottomToolbar
                }
                // 포커스 진입 시: 키보드 올라오는 시간(350ms)을 기다렸다가 스크롤
                .onChange(of: isFocused) { _, focused in
                    guard focused else { return }
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("textEditor", anchor: .bottom)
                        }
                    }
                }
                // 타이핑/줄바꿈 감지: 키보드가 올라와 있을 때만 즉시 커서 위치로 스크롤
                .onChange(of: viewModel.logText) { _, _ in
                    guard isFocused, keyboardHeight > 0 else { return }
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("textEditor", anchor: .bottom)
                    }
                }
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
        // 키보드 높이 추적: 최초 등장 및 자동완성 바 높이 변화까지 모두 커버
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            // frame.height 대신 minY 기준 계산 → 플로팅 키보드 등 엣지 케이스 대응
            keyboardHeight = max(0, UIScreen.main.bounds.height - frame.minY)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .sheet(isPresented: $isPhotoPickerPresented) {  // TODO: 사진 업로드 시 뷰 탈출 이슈 발생할 경우 .sheet -> .fullScreenCover 교체
            // OrderedPhotoPicker: 선택 순서 -> 번호로 보여주고 UIImage 배열 반환
            OrderedPhotoPicker(
                isPresented: $isPhotoPickerPresented,
                maxSelectionCount: max(1, 5 - viewModel.selectedPhotos.count)
            ) { images in
                viewModel.addPhotos(images)
            }
            .ignoresSafeArea()
        }
        .onChange(of: viewModel.isSaved) { _, saved in
            guard saved else { return }
            onSaved?()
            dismiss()
        }
        .onChange(of: viewModel.toastMessage) { _, message in
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
                .foregroundStyle(Color("GrayScale/300"))
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
                GeometryReader { geometry in
                    Image(uiImage: viewModel.selectedPhotos[index])
                        .resizable()
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        // 이미지 영역 전체에서 컨텍스트 메뉴가 열리도록 터치 범위를 지정
                        .contentShape(Rectangle())
                        // 길게 누르면 프리뷰와 삭제 메뉴를 표시
                        .contextMenu {
                            Button(role: .destructive) {
                                removePhoto(at: index)
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        } preview: {
                            photoPreview(for: index)
                        }
                }
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
        .padding(.top, Constants.photoTopSpacing)
        .padding(.horizontal, Constants.contentHorizontalPadding)
        // 사진 영역을 탭했을 때도 키보드를 내림
        .simultaneousGesture(
            TapGesture().onEnded {
                isFocused = false
            }
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
                .disabled(viewModel.isSaving)

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
                .disabled(viewModel.isSaving)

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
        guard !viewModel.isSaving else { return }
        if viewModel.hasUnsavedChanges {
            viewModel.isExitAlertPresented = true
        } else {
            dismiss()
        }
    }
    
    // 토스트를 잠시 보여준 뒤 자동으로 숨김 처리
    func showToast() {
        withAnimation { isToastVisible = true }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(Constants.toastDuration * 1_000_000_000))
            withAnimation { isToastVisible = false }
            viewModel.consumeToast()
        }
    }

    // 컨텍스트 메뉴 -> 프리뷰
    @ViewBuilder
    func photoPreview(for index: Int) -> some View {
        if viewModel.selectedPhotos.indices.contains(index) {
            Image(uiImage: viewModel.selectedPhotos[index])
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
    }

    // 선택한 사진을 즉시 제거하고 현재 페이지 인덱스를 보정
    func removePhoto(at index: Int) {
        viewModel.removePhoto(at: index)

        if viewModel.selectedPhotos.isEmpty {
            currentPhotoIndex = 0
        } else {
            currentPhotoIndex = min(currentPhotoIndex, viewModel.selectedPhotos.count - 1)
        }
    }
}

// MARK: - Preview

#Preview("로그 작성 모드") {
    NavigationStack {
        AlbumLogView(albumId: "1", mode: .create)
    }
}

#if DEBUG
#Preview("로그 수정 모드") {
    NavigationStack {
        AlbumLogView(albumId: "1", mode: .edit(AlbumLogEntry.mock))
    }
}
#endif
