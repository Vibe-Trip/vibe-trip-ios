//
//  MakeAlbumNavigationBar.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI

// 앨범 생성 화면 네비게이션 바
struct MakeAlbumNavigationBar: View {

    let title: String
    let onBackTap: () -> Void

    var body: some View {
        HStack {
            Button(action: onBackTap) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(title)
                .font(Font.setPretendard(weight: .medium, size: 16))
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .padding(.horizontal, 20)
        .background(Color.white)
    }
}

#Preview {
    MakeAlbumNavigationBar(title: "앨범 만들기", onBackTap: {})
}
