//
//  EditAlbumView.swift
//  VibeTrip
//
//  Created by CHOI on 3/26/26.
//

import SwiftUI
import UIKit


@MainActor
struct EditAlbumView: View {

    // MARK: - 더미 데이터

    @State private var selectedImage: UIImage?
    @State private var albumTitle: String
    @State private var destination: String
    
    @State private var stagedStartDate: Date = Date()
    @State private var stagedEndDate: Date = Date()
    @State private var formattedDateRange: String = ""

    
    @State private var lyricsOption: LyricsOption = .include
    @State private var vocalGender: VocalGender? = .female
    @State private var selectedGenre: AlbumGenre? = nil
    @State private var commentary: String = ""

    // UI 상태
    @State private var isPhotoPickerPresented = false
    @State private var isDatePickerPresented = false
    @State private var isGenreDescriptionPresented = false
    @State private var isExitAlertPresented = false
    @State private var toastMessage: String?

    // 장르 안내 헬퍼 텍스트
    private var genreHelperText: String {
        lyricsOption == .include
            ? "미선택 시 장르는 Pop으로 선택됩니다"
            : "미선택 시 장르는 Lofi로 선택됩니다"
    }

    // 가사 포함 여부에 따라 장르 목록 분기
    private var displayedGenres: [AlbumGenre] {
        lyricsOption == .include ? AlbumGenre.vocalGenres : AlbumGenre.instrumentalGenres
    }

    // GenreDescriptionModalView에 전달할 장르 설명 데이터
    private var genreDescriptions: [GenreDescriptionModel] {
        displayedGenres.map { GenreDescriptionModel(genre: $0, description: $0.descriptionText(for: lyricsOption)) }
    }

    // 앨범 생성 플로우를 벗어날 때 호출되는 콜백
    private let onExit: () -> Void

    init(album: AlbumCard, onExit: @escaping () -> Void = {}) {
        _albumTitle = State(initialValue: album.title ?? "")
        _destination = State(initialValue: album.location)
        self.onExit = onExit
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 경고 배너
                InfoBannerView(
                    message: "앨범 정보를 수정하면\n기존 음악은 사라지고 새로운 곡이 생성됩니다."
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {

                        // MARK: - 사진
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader(title: "사진", subtitle: "필수 선택", isRequired: true)

                            Button(action: { isPhotoPickerPresented = true }) {
                                EditAlbumPhotoBox(image: selectedImage)
                            }
                            .buttonStyle(.plain)
                        }

                        // MARK: - 앨범 제목
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader(title: "앨범 제목", subtitle: "필수 입력 (최대 15자)", isRequired: true)

                            TextField("앨범 제목을 입력해주세요.", text: $albumTitle)
                                .font(Font.setPretendard(weight: .regular, size: 16))
                                .foregroundColor(Color.textPrimary)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48, alignment: .leading)
                                .background(Color.fieldBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.fieldBorder, lineWidth: 1))
                                .shadow(color: .black.opacity(0.06), radius: 1.5, x: 0, y: 1)
                                .onChange(of: albumTitle) { _, newValue in
                                    let limited = String(newValue.prefix(15))
                                    if newValue != limited {
                                        albumTitle = limited
                                    }
                                }
                        }

                        // MARK: - 여행지
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader(title: "여행지", subtitle: "필수 입력 (최대 25자)", isRequired: true)

                            TextField("여행지의 이름을 입력해주세요.", text: $destination)
                                .font(Font.setPretendard(weight: .regular, size: 16))
                                .foregroundColor(Color.textPrimary)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48, alignment: .leading)
                                .background(Color.fieldBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.fieldBorder, lineWidth: 1))
                                .shadow(color: .black.opacity(0.06), radius: 1.5, x: 0, y: 1)
                                .onChange(of: destination) { _, newValue in
                                    let limited = String(newValue.prefix(25))
                                    if newValue != limited {
                                        destination = limited
                                        toastMessage = "25자 이상 입력 불가해요."
                                    }
                                }
                        }

                        // MARK: - 여행기간
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader(title: "여행기간", subtitle: "필수 입력", isRequired: true)

                            Button(action: { isDatePickerPresented = true }) {
                                HStack {
                                    Text(
                                        formattedDateRange.isEmpty
                                        ? "여행 기간을 입력해주세요."
                                        : formattedDateRange
                                    )
                                    .font(Font.setPretendard(weight: .regular, size: 16))
                                    .foregroundStyle(
                                        formattedDateRange.isEmpty
                                        ? Color.textSecondary
                                        : Color.textPrimary
                                    )

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48, alignment: .leading)
                                .background(Color.fieldBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.fieldBorder, lineWidth: 1))
                                .shadow(color: .black.opacity(0.06), radius: 1.5, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                        }

                        // MARK: - 가사 포함 여부
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader(title: "가사 포함 여부", subtitle: "필수 선택", isRequired: true)

                            MakeAlbumSegmentedControl(
                                options: LyricsOption.allCases,
                                title: { $0.title },
                                selection: lyricsOption,
                                onSelect: { option in
                                    lyricsOption = option
                                    if option == .exclude {
                                        vocalGender = nil
                                        // 장르 변경 시 기존 선택 해제
                                        if let genre = selectedGenre, AlbumGenre.vocalGenres.contains(genre) {
                                            selectedGenre = nil
                                        }
                                    } else {
                                        if let genre = selectedGenre, AlbumGenre.instrumentalGenres.contains(genre) {
                                            selectedGenre = nil
                                        }
                                    }
                                }
                            )
                        }

                        // MARK: - 보컬 성별
                        if lyricsOption == .include {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionHeader(title: "보컬 성별 선택", subtitle: "필수 선택", isRequired: true)

                                MakeAlbumSegmentedControl(
                                    options: VocalGender.allCases,
                                    title: { $0.title },
                                    selection: vocalGender,
                                    onSelect: { vocalGender = $0 }
                                )
                            }
                            .transition(.opacity)
                        }

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
                                            .foregroundStyle(Color.textSecondary)
                                    }

                                    Text(genreHelperText)
                                        .font(Font.setPretendard(weight: .medium, size: 12))
                                        .foregroundStyle(Color.textSecondary)
                                }

                                Spacer()

                                // 장르 설명 모달 버튼
                                Button(action: { isGenreDescriptionPresented = true }) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color.appPrimary.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 4),
                                    GridItem(.flexible(), spacing: 4),
                                    GridItem(.flexible(), spacing: 4)
                                ],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(displayedGenres) { genre in
                                    Button(action: {
                                        selectedGenre = selectedGenre == genre ? nil : genre
                                    }) {
                                        Text(genre.rawValue)
                                            .font(Font.setPretendard(weight: .medium, size: 16))
                                            .foregroundStyle(Color.textPrimary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 52)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(
                                                        selectedGenre == genre
                                                        ? Color.chipSelectedBackground
                                                        : Color.chipUnselectedBackground
                                                    )
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(
                                                        selectedGenre == genre
                                                        ? Color.appPrimary.opacity(0.35)
                                                        : Color.fieldBorder,
                                                        lineWidth: 1
                                                    )
                                            )
                                            .shadow(color: .black.opacity(0.06), radius: 1.5, x: 0, y: 1)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // MARK: - 앨범 코멘터리
                        CommentarySection(commentary: $commentary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .animation(.easeInOut(duration: 0.2), value: lyricsOption)
                }
            }
            // 네비게이션 바
            .safeAreaInset(edge: .top, spacing: 0) {
                AppNavigationBar(title: "앨범 수정", style: .solidWhite, onBackTap: { isExitAlertPresented = true })
            }

        }
        // 하단 고정 버튼
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EditAlbumBottomButton(
                // TODO: isEditValid 조건 연결
                isEnabled: true,
                action: {
                    // TODO: submitEdit() 연결
                }
            )
        }
        // 장르 설명 모달 (하단 버튼 포함 전체 화면 커버)
        .overlay {
            if isGenreDescriptionPresented {
                GenreDescriptionModalView(
                    descriptions: genreDescriptions,
                    onClose: { isGenreDescriptionPresented = false }
                )
            }
        }
        // 토스트
        .overlay(alignment: .bottom) {
            if let message = toastMessage {
                AppToastView(message: message)
                    .padding(.bottom, 140)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toastMessage)
        .onChange(of: toastMessage) { _, newValue in
            guard newValue != nil else { return }
            Task {
                try? await Task.sleep(for: .seconds(2))
                toastMessage = nil
            }
        }
        // 사진 선택 시트
        .sheet(isPresented: $isPhotoPickerPresented) {
            MakeAlbumPhotoPickerView { data in
                guard let data else { return }
                let maxBytes = 10 * 1024 * 1024
                guard data.count <= maxBytes else {
                    toastMessage = "10MB 이하의 사진만 올릴 수 있어요"
                    return
                }
                guard let image = UIImage(data: data) else { return }
                selectedImage = image
            }
        }
        // 여행기간 선택 시트
        .sheet(isPresented: $isDatePickerPresented) {
            DateRangePickerSheetView(
                startDate: $stagedStartDate,
                endDate: $stagedEndDate,
                onConfirm: {
                    formattedDateRange = "\(stagedStartDate.albumDateString) - \(stagedEndDate.albumDateString)"
                    isDatePickerPresented = false
                }
            )
        }
        // 화면 이탈 팝업
        .overlay {
            if isExitAlertPresented {
                ExitPopupView(
                    title: "앨범 수정을 멈출까요?",
                    message: "페이지를 벗어나면 작성 중인 내용이\n저장되지 않고 사라지게 돼요.",
                    onCancel: { isExitAlertPresented = false },
                    onConfirm: {
                        isExitAlertPresented = false
                        onExit()
                    }
                )
            }
        }
    }

    // 섹션 헤더 빌더
    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String, isRequired: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            HStack(alignment: .top, spacing: 4) {
                Text(title)
                    .font(Font.setPretendard(weight: .semiBold, size: 16))
                    .foregroundStyle(Color.textPrimary)

                if isRequired {
                    Circle()
                        .fill(Color(red: 0.5, green: 0.52, blue: 0.89))
                        .frame(width: 5, height: 5)
                        .offset(y: 2)
                }
            }

            Text(subtitle)
                .font(Font.setPretendard(weight: .medium, size: 12))
                .foregroundStyle(Color.textSecondary)
        }
    }
}


// MARK: - EditAlbumPhotoBox

private struct EditAlbumPhotoBox: View {

    let image: UIImage?

    private enum Layout {
        static let containerHeight: CGFloat = 210
        static let imageWidthRatio: CGFloat = 242.0 / 362.0
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.fieldBackground)
                .frame(height: Layout.containerHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .inset(by: 0.5)
                        .stroke(Color.fieldBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 1.5, x: 0, y: 1)

            if let image {
                GeometryReader { proxy in
                    let imageWidth = proxy.size.width * Layout.imageWidthRatio
                    let imageHeight = proxy.size.height

                    ZStack {
                        // 좌우 여백: GrayScale/900
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("GrayScale/900"))

                        Image(uiImage: image)
                            .resizable()    /// 비율 유지 채택 시  ->  .scaledToFill()
                            .frame(width: imageWidth, height: imageHeight - 0.5)
                            .clipped()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(height: Layout.containerHeight)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(Color.placeholderSymbol)

                    Text("앨범 커버 사진을 선택해주세요.")
                        .font(Font.setPretendard(weight: .medium, size: 14))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            }
        }
    }
}


// MARK: - CommentarySection

private struct CommentarySection: View {

    @Binding var commentary: String
    @FocusState private var isFocused: Bool

    private let maxCount = 500

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("앨범 코멘터리")
                    .font(Font.setPretendard(weight: .semiBold, size: 16))
                    .foregroundStyle(Color.textPrimary)

                Text("선택 입력")
                    .font(Font.setPretendard(weight: .medium, size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $commentary)
                    .font(Font.setPretendard(weight: .medium, size: 16))
                    .foregroundColor(Color.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .frame(height: 220)
                    .background(Color.fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.fieldBorder, lineWidth: 1))
                    .shadow(color: .black.opacity(0.06), radius: 1.5, x: 0, y: 1)
                    .focused($isFocused)
                    .onChange(of: commentary) { _, newValue in
                        let limited = String(newValue.prefix(maxCount))
                        if newValue != limited {
                            commentary = limited
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("완료") { isFocused = false }
                        }
                    }

                if commentary.isEmpty {
                    Text("어떤 분위기의 노래를 만들고 싶나요?\n지금 느끼는 감정을 기록해보세요.")
                        .font(Font.setPretendard(weight: .medium, size: 16))
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .allowsHitTesting(false)
                }

                // 글자 수 카운터
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(commentary.count)/\(maxCount)")
                            .font(Font.setPretendard(weight: .medium, size: 12))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.trailing, 14)
                            .padding(.bottom, 14)
                    }
                }
                .frame(height: 220)
                .allowsHitTesting(false)
            }
        }
    }
}


// MARK: - EditAlbumBottomButton

private struct EditAlbumBottomButton: View {

    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("수정 완료")
                .font(Font.setPretendard(weight: .semiBold, size: 18))
                .foregroundStyle(isEnabled ? .white : Color.buttonDisabledForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isEnabled ? Color.appPrimary : Color.buttonDisabledBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 32)
        .padding(.bottom, 16)
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


// MARK: - Preview

#if DEBUG
#Preview {
    EditAlbumView(album: .mockItems[0])
}
#endif
