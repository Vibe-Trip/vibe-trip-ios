//
//  OrderedPhotoPicker.swift
//  VibeTrip
//
//  Created by Codex on 4/3/26.
//

import SwiftUI
import PhotosUI

// 선택 순서를 번호로 보여주는 다중 사진 선택 뷰
struct OrderedPhotoPicker: UIViewControllerRepresentable {

    @Binding var isPresented: Bool
    let maxSelectionCount: Int
    let onSelect: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onSelect: onSelect)
    }

    // PHPicker를 ordered selection으로 구성해 선택 순서 배지를 시스템 UI로 표시
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = maxSelectionCount
        configuration.selection = .ordered
        configuration.preferredAssetRepresentationMode = .current

        let pickerViewController = PHPickerViewController(configuration: configuration)
        pickerViewController.delegate = context.coordinator
        return pickerViewController
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {

        @Binding private var isPresented: Bool
        private let onSelect: ([UIImage]) -> Void

        init(isPresented: Binding<Bool>, onSelect: @escaping ([UIImage]) -> Void) {
            _isPresented = isPresented
            self.onSelect = onSelect
        }

        // 선택 결과를 선택한 순서대로 UIImage 배열로 변환해서 상위 View에 전달
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                isPresented = false
                picker.dismiss(animated: true)
                return
            }

            let dispatchGroup = DispatchGroup()
            var images = Array<UIImage?>(repeating: nil, count: results.count)

            for (index, result) in results.enumerated() {
                let provider = result.itemProvider
                guard provider.canLoadObject(ofClass: UIImage.self) else { continue }

                dispatchGroup.enter()
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    if let image = object as? UIImage {
                        images[index] = image
                    }
                    dispatchGroup.leave()
                }
            }

            dispatchGroup.notify(queue: .main) {
                self.onSelect(images.compactMap { $0 })
                self.isPresented = false
                picker.dismiss(animated: true)
            }
        }
    }
}

#Preview {
    OrderedPhotoPicker(
        isPresented: .constant(true),
        maxSelectionCount: 5,
        onSelect: { _ in }
    )
}
