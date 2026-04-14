//
//  MakeAlbumPhotoPickerView.swift
//  VibeTrip
//
//  Created by CHOI on 3/24/26.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// 사진 선택 뷰
struct MakeAlbumPhotoPickerView: UIViewControllerRepresentable {

    let onSelect: (Data?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    // selectionLimit = 1: 한 장 선택 제한
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let pickerViewController = PHPickerViewController(configuration: configuration)
        pickerViewController.delegate = context.coordinator
        return pickerViewController
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    // Picker 결과를 Data로 변환해 상위 View에 전달
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {

        private let onSelect: (Data?) -> Void

        init(onSelect: @escaping (Data?) -> Void) {
            self.onSelect = onSelect
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                picker.dismiss(animated: true)
                return
            }

            let provider = result.itemProvider

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    DispatchQueue.main.async {
                        self.onSelect(data)
                        picker.dismiss(animated: true)
                    }
                }
                return
            }

            DispatchQueue.main.async {
                self.onSelect(nil)
                picker.dismiss(animated: true)
            }
        }
    }
}

#Preview {
    MakeAlbumPhotoPickerView(onSelect: { _ in })
}
