//
//  AlbumDetailAlbumMenu.swift
//  VibeTrip
//
//  Created by CHOI on 6/24/26.
//

import SwiftUI

// MARK: - AlbumMenuItemButtonStyle

struct AlbumMenuItemButtonStyle: ButtonStyle {
    
    private enum Constants {
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 8
        static let cornerRadius: CGFloat = 8
        static let highlightBackground = Color(red: 0.92, green: 0.92, blue: 0.98)
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, Constants.verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(configuration.isPressed ? Constants.highlightBackground : Color.clear)
            .cornerRadius(Constants.cornerRadius)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - AlbumDetailAlbumMenuPopup

struct AlbumDetailAlbumMenuPopup: View {
    
    private enum Constants {
        static let popupWidth: CGFloat = 160
        static let padding: CGFloat = 8
        static let itemSpacing: CGFloat = 8
        static let cornerRadius: CGFloat = 12
        static let itemFontSize: CGFloat = 14
    }
    
    let isMusicUrlReady: Bool
    let onDownloadMusic: () -> Void
    let onEditAlbum: () -> Void
    let onDeleteAlbum: () -> Void
    let onReport: () -> Void
    
    // 팝업 메뉴 항목
    private enum MenuItem: CaseIterable {
        case downloadMusic, editAlbum, deleteAlbum, report
        
        var title: String {
            switch self {
            case .downloadMusic: return "배경 음악 다운로드"
            case .editAlbum:    return "앨범 수정"
            case .deleteAlbum:  return "앨범 삭제"
            case .report:       return "AI 음악 신고하기"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: Constants.itemSpacing) {
            ForEach(MenuItem.allCases, id: \.self) { item in
                menuItem(item)
            }
        }
        .padding(Constants.padding)
        .frame(width: Constants.popupWidth, alignment: .center)
        .background(.white)
        .cornerRadius(Constants.cornerRadius)
        // 앨범메뉴팝업 -> detailMenu shadow
        .appShadow(.detailMenu)
    }
    
    @ViewBuilder
    private func menuItem(_ item: MenuItem) -> some View {
        let isDisabled = item == .downloadMusic && !isMusicUrlReady
        Button {
            switch item {
            case .downloadMusic: onDownloadMusic()
            case .editAlbum:     onEditAlbum()
            case .deleteAlbum:   onDeleteAlbum()
            case .report:        onReport()
            }
        } label: {
            HStack(alignment: .center, spacing: 0) {
                Text(item.title)
                    .font(.setPretendard(weight: .medium, size: Constants.itemFontSize))
                    .foregroundStyle(isDisabled ? Color("GrayScale/50") : Color.text)
            }
        }
        .disabled(isDisabled)
        .buttonStyle(AlbumMenuItemButtonStyle())
    }
}

