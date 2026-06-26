//
//  AlbumDetailActionButton.swift
//  VibeTrip
//
//  Created by CHOI on 6/24/26.
//

import SwiftUI

// MARK: - AlbumDetailActionButton

struct AlbumDetailActionButton: View {
    
    private enum Constants {
        static let height: CGFloat = 48
        static let cornerRadius: CGFloat = 24
        static let iconTextSpacing: CGFloat = 4
        static let fontSize: CGFloat = 14
        static let iconSize: CGFloat = 18
        static let assetIconSize: CGFloat = 22
        
        static let iconFrameWidth: CGFloat = 22
        static let horizontalPadding: CGFloat = 20
        static let verticalPadding: CGFloat = 12
    }
    
    let title: String
    let systemImageName: String
    var isAssetImage: Bool = false
    var iconColor: Color = Color("appPrimary/400")
    var referenceTitle: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Constants.iconTextSpacing) {
                // 아이콘 고정 너비
                ZStack(alignment: .topTrailing) {
                    Group {
                        if isAssetImage {
                            Image(systemImageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: Constants.assetIconSize, height: Constants.assetIconSize)
                        } else {
                            Image(systemName: systemImageName)
                                .font(.system(size: Constants.iconSize, weight: .medium))
                                .contentTransition(.symbolEffect(.replace.offUp)) /// 심볼 전환 효과
                                .foregroundStyle(iconColor)
                        }
                    }
                    .frame(width: Constants.iconFrameWidth, height: Constants.assetIconSize)
                }
                
                ZStack {
                    if let ref = referenceTitle {
                        Text(ref)
                            .opacity(0) // 레이아웃 너비 고정용
                    }
                    Text(title)
                        .fixedSize()
                        .id(title)
                        .transition(.asymmetric(    /// 타이틀 전환 효과
                            insertion: .opacity.animation(.easeIn(duration: 0.2)),
                            removal: .opacity.animation(.easeOut(duration: 0.05))
                                               ))
                }
                .font(.setPretendard(weight: .medium, size: Constants.fontSize))
            }
            .foregroundStyle(Color("appPrimary/500"))
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, Constants.verticalPadding)
            .frame(maxWidth: .infinity, minHeight: Constants.height)
            .background(Color("appPrimary/400").opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        }
        .buttonStyle(.plain)
    }
}

