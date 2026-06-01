//
//  InfoBannerView.swift
//  VibeTrip
//
//  Created by CHOI on 3/26/26.
//

import SwiftUI

// 경고 배너 컴포넌트
struct InfoBannerView: View {
    
    let message: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(message)
                .font(Font.setPretendard(weight: .regular, size: 14))
                .multilineTextAlignment(.center)
                .foregroundColor(Color(red: 0.47, green: 0.49, blue: 0.52))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color(red: 0.92, green: 0.92, blue: 0.98))
        .cornerRadius(8)
        .appShadow(.buttonTextField)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .inset(by: 0.5)
                .stroke(Color(red: 0.67, green: 0.68, blue: 0.93), lineWidth: 1)
        )
    }
}

#Preview {
    InfoBannerView(
        message: "앨범 정보를 수정하면\n기존 음악은 사라지고 새로운 곡이 생성됩니다."
    )
    .padding()
}
