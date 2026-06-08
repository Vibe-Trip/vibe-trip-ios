//
//  MailComposeView.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI
import MessageUI

struct MailComposeView: UIViewControllerRepresentable {

    let toRecipients: [String]
    let subject: String
    let onDismiss: () -> Void

    // MARK: - Coordinator

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            // 작성 종료 후 시트 닫기
            controller.dismiss(animated: true)
            onDismiss()
        }
    }

    // MARK: - UIViewControllerRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        // 문의하기 기본 수신자/제목 세팅
        vc.setToRecipients(toRecipients)
        vc.setSubject(subject)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    // 실제 기기에서 메일 앱이 설정된 경우에만 동작
    Text("MailComposeView Preview\n(메일 앱 설정 시 실기기에서 확인)")
        .multilineTextAlignment(.center)
        .font(.caption)
        .foregroundStyle(.secondary)
}
