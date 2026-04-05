//
//  ActivityViewController.swift
//  VibeTrip
//
//  Created by CHOI on 4/5/26.
//

import SwiftUI

// UIActivityViewController: iOS 공유 시트 SwiftUI 래퍼
struct ActivityViewController: UIViewControllerRepresentable {

    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
