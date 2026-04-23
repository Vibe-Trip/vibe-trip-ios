//
//  GenreDescriptionModalView.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI

// 장르 설명 모달
struct GenreDescriptionModalView: View {

    private enum Layout {
        static let modalHeight: CGFloat = 528
        static let modalCornerRadius: CGFloat = 12
        static let modalPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 12
        static let titleTopPadding: CGFloat = 16
        static let titleToContentSpacing: CGFloat = 23.5
    }

    let descriptions: [GenreDescriptionModel]
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.dimmedOverlay
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()

                    Text("장르 설명")
                        .font(Font.setPretendard(weight: .semiBold, size: 14))
                        .foregroundStyle(Color.text)

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.horizontal, Layout.modalPadding)
                .padding(.top, Layout.titleTopPadding)

                ScrollView {
                    VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                        ForEach(descriptions) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.genre.rawValue)
                                    .font(Font.setPretendard(weight: .semiBold, size: 16))
                                    .foregroundStyle(Color.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .multilineTextAlignment(.leading)

                                Text(item.description)
                                    .font(Font.setPretendard(weight: .regular, size: 14))
                                    .foregroundStyle(Color.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, Layout.modalPadding)
                    .padding(.bottom, Layout.modalPadding)
                    .padding(.top, Layout.titleToContentSpacing)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Layout.modalHeight)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Layout.modalCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.modalCornerRadius)
                    .stroke(Color.fieldBorder, lineWidth: 1)
            )
            .appShadow(.buttonTextField)
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    GenreDescriptionModalView(
        descriptions: [
            GenreDescriptionModel(genre: .pop, description: "누구나 즐길 수 있는 대중적이고 산뜻한 리듬"),
            GenreDescriptionModel(genre: .kPop, description: "전 세계를 사로잡은 화려하고 트렌디한 사운드")
        ],
        onClose: {}
    )
}
