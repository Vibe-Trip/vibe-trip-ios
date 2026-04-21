//
//  MakeAlbumSegmentedControl.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI

// 2분할 세그먼트 버튼
struct MakeAlbumSegmentedControl<Option: Identifiable & Hashable>: View {

    let options: [Option]
    let title: (Option) -> String
    let selection: Option?
    let onSelect: (Option) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                let isSelected = selection == option

                Button(action: {
                    onSelect(option)
                }) {
                    Text(title(option))
                        .font(Font.setPretendard(weight: .medium, size: 16))
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            // 세그먼트배경 -> buttonTextField shadow
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.chipSelectedBackground : Color.chipUnselectedBackground)
                                .appShadow(.buttonTextField)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.chipSelectedBorder : Color.fieldBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    MakeAlbumSegmentedControl(
        options: LyricsOption.allCases,
        title: { $0.title },
        selection: .include,
        onSelect: { _ in }
    )
    .padding()
}
