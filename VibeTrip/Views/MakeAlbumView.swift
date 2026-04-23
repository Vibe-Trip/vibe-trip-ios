//
//  MakeAlbumView.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI
import UIKit

// MARK: - MakeAlbumView

@MainActor
struct MakeAlbumView: View {
    
    private enum Constants {
        static let entryPopupDismissKey = "shouldShowMakeAlbumEntryPopup"
        static let entryPopupTitle = "AI 음악을 만들까요?"
        static let entryPopupMessage = "사진을 분석해 어울리는 노래를 만듭니다.\n데이터는 보안이 강화된 AI 엔진을 통해 분석되며\n음악 생성에만 활용됩니다."
        static let headerHeight: CGFloat = 44
    }
    
    // 앨범 생성 데이터 및 UI 상태 관리
    @StateObject private var viewModel: MakeAlbumViewModel
    
    // 토스트 메시지의 하단 여백: 키보드 높이에 따라 동적으로 계산
    @State private var keyboardHeight: CGFloat = 0
    
    // 사진 선택 시트 표시 여부
    @State private var isPhotoPickerPresented = false
    
    // 앨범 생성 전 안내 팝업
    @AppStorage(Constants.entryPopupDismissKey) private var shouldShowEntryPopup = true
    @State private var isEntryPopupPresented = false
    @State private var doNotShowEntryPopupAgain = false
    
    // 필수 -> 선택 입력 단계 전환을 위한 NavigationStack 경로
    @State private var navigationPath: [MakeAlbumNavigationRoute] = []
    
    // 앨범 생성 플로우를 벗어날 때 호출되는 콜백
    private let onExit: () -> Void
    
    // 앨범 생성 시작: LoadingView 노출 트리거
    private let onCreationStarted: () -> Void
    
    // 앨범 생성 성공: albumId 전달
    private let onCreationSuccess: (Int) -> Void
    
    // 네트워크 오류: 재시도 클로저 -> MainTabBarView로 전달
    private let onNetworkError: (@escaping () -> Void) -> Void
    
    // 재시도 불가 오류: 확인 팝업 트리거
    private let onFatalError: () -> Void
    
    init(
        onExit: @escaping () -> Void = {},
        onCreationStarted: @escaping () -> Void = {},
        onCreationSuccess: @escaping (Int) -> Void = { _ in },
        onNetworkError: @escaping (@escaping () -> Void) -> Void = { _ in },
        onFatalError: @escaping () -> Void = {}
    ) {
        self.onExit = onExit
        self.onCreationStarted = onCreationStarted
        self.onCreationSuccess = onCreationSuccess
        self.onNetworkError = onNetworkError
        self.onFatalError = onFatalError
        _viewModel = StateObject(wrappedValue: MakeAlbumViewModel())
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white
                .ignoresSafeArea()
            
            ZStack(alignment: .top) {
                NavigationStack(path: $navigationPath) {
                    // 필수 입력이 루트 뷰
                    MakeAlbumRequiredInputContent(
                        viewModel: viewModel,
                        keyboardHeight: keyboardHeight,
                        onPhotoTap: {
                            isPhotoPickerPresented = true
                        },
                        onNextTap: handleProceedToOptionalStep
                    )
                    // safeAreaInset: NavigationStack이 아닌 각 뷰에 직접 적용
                    .safeAreaInset(edge: .top) { headerSpacer }
                    .navigationDestination(for: MakeAlbumNavigationRoute.self) { route in
                        switch route {
                        case .optionalInput:
                            // 선택 입력 뷰: 우측에서 push 전환
                            MakeAlbumOptionalInputContent(
                                viewModel: viewModel,
                                keyboardHeight: keyboardHeight,
                                onCreateTap: handleCreateTap
                            )
                            .safeAreaInset(edge: .top) { headerSpacer }
                            .toolbar(.hidden, for: .navigationBar)
                            // toolbar hidden 시 비활성화되는 스와이프 뒤로가기 복원
                            .background(SwipeBackEnabler())
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
                
                AppNavigationBar(title: "앨범 만들기", style: .blurAlways, onBackTap: handleBackTap)
            }
            
            // 장르 설명 모달
            if viewModel.isGenreDescriptionPresented {
                GenreDescriptionModalView(
                    descriptions: viewModel.genreDescriptions,
                    onClose: {
                        viewModel.isGenreDescriptionPresented = false
                    }
                )
            }
        }
        // 토스트 메시지
        .overlay(alignment: .bottom) {
            if let toastMessage = viewModel.toastMessage {
                AppToastView(message: toastMessage)
                    .padding(.bottom, keyboardAwareToastPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // 사진 선택 시트
        .sheet(isPresented: $isPhotoPickerPresented) {
            MakeAlbumPhotoPickerView { data in
                viewModel.handleSelectedPhotoData(data)
            }
        }
        // 여행 기간 선택 시트
        .sheet(isPresented: $viewModel.isDatePickerPresented) {
            DateRangePickerSheetView(
                startDate: Binding(
                    get: { viewModel.stagedStartDate },
                    set: { viewModel.updateStagedStartDate($0) }
                ),
                endDate: Binding(
                    get: { viewModel.stagedEndDate ?? viewModel.stagedStartDate },
                    set: { viewModel.updateStagedEndDate($0) }
                ),
                onConfirm: viewModel.applyDateSelection
            )
        }
        // 화면 이탈 팝업
        .overlay {
            if viewModel.isExitAlertPresented {
                ExitPopupView(
                    title: "작성을 멈출까요?",
                    message: "지금 나가면 작성 중인 소중한 기록들이 사라져요.",
                    onCancel: {
                        viewModel.isExitAlertPresented = false
                    },
                    onConfirm: {
                        viewModel.isExitAlertPresented = false
                        onExit()
                    },
                    confirmTitle: "나가기",
                    cancelTitle: "계속 작성하기"
                )
            }
        }
        // 앨범 생성 전 안내 팝업
        .overlay {
            if isEntryPopupPresented {
                ExitPopupView(
                    title: Constants.entryPopupTitle,
                    message: Constants.entryPopupMessage,
                    onCancel: {
                        isEntryPopupPresented = false
                        doNotShowEntryPopupAgain = false
                    },
                    onConfirm: {
                        if doNotShowEntryPopupAgain {
                            shouldShowEntryPopup = false
                        }
                        isEntryPopupPresented = false
                        doNotShowEntryPopupAgain = false
                        viewModel.submitAlbum(
                            onStarted: onCreationStarted,
                            onSuccess: onCreationSuccess,
                            onNetworkError: onNetworkError,
                            onFatalError: onFatalError
                        )
                    },
                    confirmTitle: "시작하기",
                    doNotShowAgain: $doNotShowEntryPopupAgain
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEntryPopupPresented)
        // 토스트 애니메이션
        .animation(.easeInOut(duration: 0.2), value: viewModel.toastMessage)
        .onChange(of: viewModel.toastMessage) { _, newValue in
            guard newValue != nil else {
                return
            }
            
            Task {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else {
                    return
                }
                
                viewModel.consumeToast()
            }
        }
        // 키보드가 올라올 때 높이를 추적하여 토스트 위치 계산에 사용
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                return
            }
            
            keyboardHeight = frame.height
        }
        // 키보드가 내려가면 높이를 초기화
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        // 스와이프 뒤로가기로 pop됐을 때 ViewModel 단계 동기화
        .onChange(of: navigationPath) { _, path in
            if path.isEmpty, viewModel.currentStep == .optionalInput {
                viewModel.returnToRequiredStep()
            }
        }
    }
    
    // 키보드가 올라와 있으면 키보드 바로 위에, 그렇지 않으면 하단에서 고정 여백으로 표시
    private var keyboardAwareToastPadding: CGFloat {
        keyboardHeight > 0 ? keyboardHeight + 32 : 96
    }
    
    private var headerSpacer: some View {
        Color.clear.frame(height: Constants.headerHeight)
    }
    
    // 뒤로 가기 탭 처리: 단계에 따라 동작이 다름
    private func handleBackTap() {
        switch viewModel.currentStep {
        case .requiredInput:
            // 필수 입력을 이미 시작했으면 종료 확인 팝업, 아무것도 입력하지 않았으면 바로 종료
            if viewModel.hasStartedRequiredInput {
                viewModel.isExitAlertPresented = true
            } else {
                onExit()
            }
        case .optionalInput:
            // 선택 입력 단계에서는 NavigationStack pop으로 필수 입력으로 복귀
            popToRequiredStep()
        case .loading:
            // 로딩 중에는 뒤로 가면 플로우 전체 종료
            onExit()
        }
    }
    
    // 필수 입력 검증 통과 시 선택 입력 화면으로 push
    private func handleProceedToOptionalStep() {
        viewModel.proceedToOptionalStep()
        guard viewModel.currentStep == .optionalInput else { return }
        if navigationPath.last != .optionalInput {
            navigationPath.append(.optionalInput)
        }
    }
    
    // 선택 입력에서 필수 입력으로 pop
    private func popToRequiredStep() {
        navigationPath.removeAll()
        if viewModel.currentStep == .optionalInput {
            viewModel.returnToRequiredStep()
        }
    }
    
    // 앨범 생성 버튼 탭 처리
    private func handleCreateTap() {
        if shouldShowEntryPopup {
            doNotShowEntryPopupAgain = false
            withAnimation(.easeInOut(duration: 0.2)) {
                isEntryPopupPresented = true
            }
        } else {
            viewModel.submitAlbum(
                onStarted: onCreationStarted,
                onSuccess: onCreationSuccess,
                onNetworkError: onNetworkError,
                onFatalError: onFatalError
            )
        }
    }
}

private extension MakeAlbumView {
    // 필수 -> 선택 입력 전환 경로
    enum MakeAlbumNavigationRoute: Hashable {
        case optionalInput
    }
}


// MARK: - 필수 입력 뷰

private struct MakeAlbumRequiredInputContent: View {
    
    @ObservedObject var viewModel: MakeAlbumViewModel
    
    let keyboardHeight: CGFloat
    let onPhotoTap: () -> Void
    let onNextTap: () -> Void
    
    @State private var destinationInput = ""
    
    private enum Layout {
        static let vocalSectionSlotHeight: CGFloat = 84
    }
    
    var body: some View {
        let displayedPhotoImage = viewModel.displayedPhotoImage
        
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                // 섹션 간격
                VStack(alignment: .leading, spacing: 20) {
                    
                    // MARK: - 사진 + 여행지
                    VStack(alignment: .leading, spacing: 8) {
                        
                        // 사진 섹션
                        albumSectionHeader(
                            title: "사진",
                            subtitle: "필수 선택",
                            showsIndicator: true,
                            subtitleWeight: .semiBold
                        )
                        
                        // 사진 선택 유무 분기
                        Button(action: onPhotoTap) {
                            MakeAlbumPhotoBox(image: displayedPhotoImage)
                        }
                        .buttonStyle(.plain)
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                        
                        // 여행지 섹션
                        albumSectionHeader(
                            title: "여행지",
                            subtitle: "필수 입력 (최대 25자)",
                            showsIndicator: true
                        )
                        
                        TextField("여행지의 이름을 입력해주세요.", text: $destinationInput)
                            .font(Font.setPretendard(weight: .regular, size: 14))
                            .foregroundColor(Color.textPrimary)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48, alignment: .leading)
                            .background(Color.fieldBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .submitLabel(.done)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.fieldBorder, lineWidth: 1)
                            )
                            .appShadow(.buttonTextField)
                            .onAppear {
                                destinationInput = viewModel.album.travelDestination
                            }
                        // 25자 초과 예외처리
                            .onChange(of: destinationInput) { _, newValue in
                                let limited = String(newValue.prefix(25))
                                if newValue != limited {
                                    destinationInput = limited
                                    viewModel.showToast("여행지 이름은 25자까지만 쓸 수 있어요.")
                                }
                                viewModel.album.travelDestination = limited
                            }
                    }
                    
                    // MARK: - 여행기간
                    
                    VStack(alignment: .leading, spacing: 8) {
                        albumSectionHeader(
                            title: "여행기간",
                            subtitle: "필수 입력",
                            showsIndicator: true
                        )
                        
                        Button(action: viewModel.presentDatePicker) {
                            HStack {
                                Text(
                                    viewModel.album.formattedTravelDateRange.isEmpty
                                    ? "여행 기간을 입력해주세요."
                                    : viewModel.album.formattedTravelDateRange
                                )
                                .font(Font.setPretendard(weight: .regular, size: 14))
                                .foregroundStyle(
                                    viewModel.album.formattedTravelDateRange.isEmpty
                                    ? Color("GrayScale/300")
                                    : Color.textPrimary
                                )
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48, alignment: .leading)
                            .background(Color.fieldBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.fieldBorder, lineWidth: 1)
                            )
                            .appShadow(.buttonTextField)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // MARK: - 가사 포함 여부
                    VStack(alignment: .leading, spacing: 8) {
                        albumSectionHeader(
                            title: "가사 포함 여부",
                            subtitle: "필수 선택",
                            showsIndicator: true
                        )
                        
                        // 가사 포함 or 미포함 선택  세그먼트
                        MakeAlbumSegmentedControl(
                            options: LyricsOption.allCases,
                            title: { $0.title },
                            selection: viewModel.album.lyricsOption,
                            onSelect: viewModel.updateLyricsOption
                        )
                    }
                    
                    // MARK: - 보컬 성별 선택
                    
                    ZStack(alignment: .topLeading) {
                        if viewModel.album.lyricsOption == .include {
                            VStack(alignment: .leading, spacing: 8) {
                                albumSectionHeader(
                                    title: "보컬 성별 선택",
                                    subtitle: "필수 선택",
                                    showsIndicator: true
                                )
                                
                                MakeAlbumSegmentedControl(
                                    options: VocalGender.allCases,
                                    title: { $0.title },
                                    selection: viewModel.album.vocalGender,
                                    onSelect: { viewModel.album.vocalGender = $0 }
                                )
                            }
                            .transition(.opacity)
                        }
                    }
                    .frame(height: Layout.vocalSectionSlotHeight)
                    .id("vocalGenderSection")
                }
                // 가사 옵션 전환 에니메이션: fade
                .animation(.easeInOut(duration: 0.2), value: viewModel.album.lyricsOption)
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 24)
            }
            .onChange(of: viewModel.album.lyricsOption) { _, newValue in
                guard newValue == .include else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("vocalGenderSection", anchor: .bottom)
                    }
                }
            }
        }
        // 하단 버튼: SafeArea 위에 고정
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MakeAlbumBottomButton(
                title: "다음으로",
                isEnabled: viewModel.isRequiredInputValid,
                action: onNextTap,
                bottomSpacing: keyboardHeight > 0 ? 20 : 0
            )
        }
    }
    
    // 섹션 헤더 빌더
    private func albumSectionHeader(
        title: String,
        subtitle: String,
        showsIndicator: Bool = false,
        subtitleWeight: Font.FontWeight = .medium
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            HStack(alignment: .top, spacing: 4) {
                Text(title)
                    .font(Font.setPretendard(weight: .semiBold, size: 16))
                    .foregroundStyle(Color.textPrimary)
                
                if showsIndicator {
                    // 필수 항목 dot
                    Circle()
                        .fill(Color("appPrimary"))
                        .frame(width: 5, height: 5)
                        .offset(y: 2)
                }
            }
            
            Text(subtitle)
                .font(Font.setPretendard(weight: subtitleWeight, size: 12))
                .foregroundStyle(Color("GrayScale/300"))
        }
    }
    
}

// MARK: - 선택 입력 뷰

private struct MakeAlbumOptionalInputContent: View {
    private enum ScrollTarget {
        static let commentary = "albumCommentarySection"
    }
    
    @ObservedObject var viewModel: MakeAlbumViewModel
    @FocusState private var isCommentaryFocused: Bool
    
    let keyboardHeight: CGFloat
    let onCreateTap: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // MARK: - 장르 선택
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text("장르 선택")
                                            .font(Font.setPretendard(weight: .semiBold, size: 16))
                                            .foregroundStyle(Color.textPrimary)
                                        
                                        Text("선택 입력")
                                            .font(Font.setPretendard(weight: .medium, size: 12))
                                            .foregroundStyle(Color("GrayScale/300"))
                                    }
                                    
                                    Text(viewModel.genreHelperText)
                                        .font(Font.setPretendard(weight: .medium, size: 12))
                                        .foregroundStyle(Color("GrayScale/300"))
                                }
                                
                                Spacer()
                                
                                // 장르 설명 모달 버튼
                                Button(action: {
                                    viewModel.isGenreDescriptionPresented = true
                                }) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color("appPrimary500"))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // 장르 목록: 가사 포함 여부에 따라 분기
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 4),
                                    GridItem(.flexible(), spacing: 4),
                                    GridItem(.flexible(), spacing: 4)
                                ],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(viewModel.displayedGenres) { genre in
                                    Button(action: {
                                        viewModel.toggleGenre(genre)
                                    }) {
                                        Text(genre.rawValue)
                                            .font(Font.setPretendard(weight: .medium, size: 16))
                                            .foregroundStyle(Color.textPrimary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 52)
                                            .background(
                                                // 장르버튼배경 -> buttonTextField shadow
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(
                                                        viewModel.album.selectedGenre == genre
                                                        ? Color("appPrimary50")
                                                        : Color("GrayScale/50")
                                                    )
                                                    .appShadow(.buttonTextField)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(
                                                        viewModel.album.selectedGenre == genre
                                                        ? Color("appPrimary100")
                                                        : Color("GrayScale/100"),
                                                        lineWidth: 1
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // MARK: - 앨범 코멘터리
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("앨범 코멘터리")
                                    .font(Font.setPretendard(weight: .semiBold, size: 16))
                                    .foregroundStyle(Color.textPrimary)
                                
                                Text("선택 입력")
                                    .font(Font.setPretendard(weight: .medium, size: 12))
                                    .foregroundStyle(Color("GrayScale/300"))
                            }
                            
                            // placeholder 및 글자 수 카운터 오버레이
                            ZStack(alignment: .topLeading) {
                                TextEditor(
                                    text: Binding(
                                        get: { viewModel.album.albumCommentary },
                                        set: { viewModel.updateAlbumCommentary($0) }
                                    )
                                )
                                .font(Font.setPretendard(weight: .medium, size: 16))
                                .foregroundColor(Color.textPrimary)
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                                .frame(height: 220)
                                .background(Color.fieldBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.fieldBorder, lineWidth: 1)
                                )
                                .appShadow(.buttonTextField)
                                // 키보드 비활성화
                                .focused($isCommentaryFocused)
                                // 키보드 비활성화 버튼
                                .toolbar {
                                    ToolbarItemGroup(placement: .keyboard) {
                                        Spacer()
                                        Button(action: {
                                            isCommentaryFocused = false
                                        }) {
                                            Image(systemName: "keyboard.chevron.compact.down")  // 키보드 비활성화 심볼
                                                .font(.system(size: 18, weight: .light))
                                        }
                                        .tint(Color("appPrimary400"))
                                    }
                                }
                                
                                if viewModel.album.albumCommentary.isEmpty {
                                    Text("어떤 분위기의 노래를 만들고 싶나요?\n지금 느끼는 감정을 기록해보세요.")
                                        .font(Font.setPretendard(weight: .regular, size: 14))
                                        .tracking(-0.28)
                                        .foregroundStyle(Color("GrayScale/300"))
                                        .padding(.horizontal, 16)
                                        .padding(.top, 20)
                                    // 터치 비활성화
                                        .allowsHitTesting(false)
                                }
                                
                                // 글자 수 카운터
                                VStack {
                                    Spacer()
                                    
                                    HStack {
                                        Spacer()
                                        
                                        Text("\(viewModel.album.albumCommentary.count)/500")
                                            .font(Font.setPretendard(weight: .medium, size: 12))
                                            .foregroundStyle(Color("GrayScale/300"))
                                            .padding(.trailing, 14)
                                            .padding(.bottom, 14)
                                    }
                                }
                                .frame(height: 220)
                                // 터치 비활성화
                                .allowsHitTesting(false)
                            }
                        }
                        .id(ScrollTarget.commentary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 140)
                }
                .onChange(of: isCommentaryFocused) { _, isFocused in
                    guard isFocused else { return }
                    Task {
                        try? await Task.sleep(for: .milliseconds(150))
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(ScrollTarget.commentary, anchor: .top)
                        }
                    }
                }
                .scrollDisabled(true)
            }
            
            MakeAlbumBottomButton(
                title: "앨범 생성하기",
                isEnabled: true,
                action: onCreateTap,
                bottomSpacing: keyboardHeight > 0 ? 44 : 0
            )
        }
    }
}

// MARK: - MakeAlbumPhotoBox
// 사진 영역 UI 컴포넌트.

private struct MakeAlbumPhotoBox: View {
    
    let image: UIImage?
    
    private enum Layout {
        static let containerHeight: CGFloat = 272
        // 디자이너 스펙: 전체 박스 대비 실제 이미지 표시 영역의 가로 비율
        static let imageWidthRatio: CGFloat = 242.0 / 362.0
    }
    
    var body: some View {
        ZStack {
            // 배경 컨테이너
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.fieldBackground)
                .frame(height: Layout.containerHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .inset(by: 0.5)
                        .stroke(Color(red: 0.93, green: 0.93, blue: 0.93), lineWidth: 1)
                )
                .appShadow(.buttonTextField)
            
            if let image {
                // 선택된 사진
                GeometryReader { proxy in
                    let imageWidth = proxy.size.width * Layout.imageWidthRatio
                    let imageHeight = proxy.size.height
                    
                    ZStack {
                        // 좌우 여백: GrayScale/900
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("GrayScale/900"))
                        
                        Image(uiImage: image)
                            .resizable()    /// 비율 유지 채택 시  ->  .scaledToFill()
                            .frame(width: imageWidth, height: imageHeight - 0.5) // 업로드 이미지 높이 조절 -> 박스 벗어남 방지
                            .clipped()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(height: Layout.containerHeight)
            } else {
                // 카메라 아이콘 + 안내 문구 (PlaceHolder)
                VStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(Color.placeholderSymbol)
                    
                    Text("음악으로 만들고 싶은 순간을 올려주세요. \nAI가 사진의 온도와 색감을 곡으로 빚어냅니다.")
                        .font(Font.setPretendard(weight: .medium, size: 14))
                        .foregroundStyle(Color("GrayScale/300"))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - MakeAlbumBottomButton
// 하단 고정 CTA 버튼 컴포넌트.
// isEnabled 상태에 따라 배경색과 텍스트 색상이 전환된다.
// 배경은 투명→흰색 LinearGradient로 스크롤 콘텐츠와 자연스럽게 이어진다.

private struct MakeAlbumBottomButton: View {
    
    let title: String
    let isEnabled: Bool
    let action: () -> Void
    
    // 키보드 유무에 따라 하단 여백 조정
    let bottomSpacing: CGFloat
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Font.setPretendard(weight: .semiBold, size: 16))
                .foregroundStyle(Color("GrayScale/50"))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            /// 배경색 조정
                .background(isEnabled ? Color.appPrimary : Color.buttonDisabledBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 32)
        .padding(.bottom, bottomSpacing)
        .background(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .white.opacity(0), location: 0),
                    .init(color: .white, location: 0.45)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }
}

#Preview {
    MakeAlbumView()
}
