//
//  AlbumDetailLogMenu.swift
//  VibeTrip
//
//  Created by CHOI on 6/24/26.
//

import SwiftUI

// MARK: - LogMenuItemButtonStyle

struct LogMenuItemButtonStyle: ButtonStyle {
    
    private enum Constants {
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 8
        static let cornerRadius: CGFloat = 8
        static let highlightBackground = Color(red: 0.92, green: 0.92, blue: 0.98)
        static let animationDuration: Double = 0.1
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, Constants.verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(configuration.isPressed ? Constants.highlightBackground : Color.clear)
            .cornerRadius(Constants.cornerRadius)
            .animation(.easeInOut(duration: Constants.animationDuration), value: configuration.isPressed)
    }
}

// MARK: - AlbumDetailLogMenuPopup

struct AlbumDetailLogMenuPopup: View {
    
    private enum Constants {
        static let popupWidth: CGFloat = 140
        static let padding: CGFloat = 8
        static let itemSpacing: CGFloat = 8
        static let cornerRadius: CGFloat = 12
        static let itemFontSize: CGFloat = 14
    }
    
    let onEditLog: () -> Void
    let onDeleteLog: () -> Void
    
    var body: some View {
        VStack(alignment: .center, spacing: Constants.itemSpacing) {
            Button(action: onEditLog) {
                Text("로그 수정")
                    .font(.setPretendard(weight: .medium, size: Constants.itemFontSize))
                    .foregroundStyle(Color.text)
            }
            .buttonStyle(LogMenuItemButtonStyle())
            
            Button(action: onDeleteLog) {
                Text("로그 삭제")
                    .font(.setPretendard(weight: .medium, size: Constants.itemFontSize))
                    .foregroundStyle(Color.text)
            }
            .buttonStyle(LogMenuItemButtonStyle())
        }
        .padding(Constants.padding)
        .frame(width: Constants.popupWidth, alignment: .center)
        .background(.white)
        .cornerRadius(Constants.cornerRadius)
        // 로그메뉴팝업 -> detailMenu shadow
        .appShadow(.detailMenu)
    }
}

