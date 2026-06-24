//
//  AlbumDetailEmptyStateSection.swift
//  VibeTrip
//
//  Created by CHOI on 6/24/26.
//

import SwiftUI

// MARK: - AlbumDetailEmptyStateSection
// 표시할 로그 없을 시 안내 문구

struct AlbumDetailEmptyStateSection: View {
    
    private enum Constants {
        static let spacing: CGFloat = 8
        static let titleFontSize: CGFloat = 16
        static let descriptionFontSize: CGFloat = 14
    }
    
    var body: some View {
        VStack(spacing: Constants.spacing) {
            Text("아직 기록된 로그가 없어요.")
                .font(.setPretendard(weight: .semiBold, size: Constants.titleFontSize))
                .foregroundStyle(Color("GrayScale/500"))
                .multilineTextAlignment(.center)
            
            Text("로그를 작성하고 여행의 추억을 완성해 보세요.")
                .font(.setPretendard(weight: .medium, size: Constants.descriptionFontSize))
                .foregroundStyle(Color("GrayScale/400"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

