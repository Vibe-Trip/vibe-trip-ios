//
//  AlbumDetailNavigationOverlay.swift
//  VibeTrip
//
//  Created by CHOI on 6/24/26.
//

import SwiftUI

// MARK: - AlbumDetailNavigationOverlay

struct AlbumDetailNavigationOverlay: View {
    
    private enum Constants {
        static let horizontalPadding: CGFloat = 20
        static let topPadding: CGFloat = 12
        static let iconSize: CGFloat = 22
        static let touchTargetSize: CGFloat = 44
    }
    
    let onBackTap: () -> Void
    let onMoreTap: () -> Void
    
    var body: some View {
        HStack {
            // 뒤로가기 버튼
            Button(action: onBackTap) {
                Image(systemName: "chevron.left")
                    .font(.system(size: Constants.iconSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .blendMode(.difference)
                    .frame(width: Constants.touchTargetSize, height: Constants.touchTargetSize)
            }
            
            Spacer()
            
            // 앨범 옵션 버튼
            Button(action: onMoreTap) {
                Image(systemName: "ellipsis")
                    .font(.system(size: Constants.iconSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .blendMode(.difference)
                    .frame(width: Constants.touchTargetSize, height: Constants.touchTargetSize)
            }
        }
        .compositingGroup()
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.top, Constants.topPadding)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

