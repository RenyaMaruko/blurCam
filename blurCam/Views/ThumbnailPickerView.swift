import PhotosUI
import SwiftUI

/// A SwiftUI wrapper around PHPickerViewController for selecting a thumbnail image
/// from the user's photo library.
struct ThumbnailPickerView: UIViewControllerRepresentable {

    /// Called when an image is successfully selected
    var onImageSelected: (Data, String) -> Void

    /// Called when the picker is dismissed without selection
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected, onCancel: onCancel)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImageSelected: (Data, String) -> Void
        let onCancel: () -> Void

        init(onImageSelected: @escaping (Data, String) -> Void, onCancel: @escaping () -> Void) {
            self.onImageSelected = onImageSelected
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let result = results.first else {
                onCancel()
                return
            }

            let itemProvider = result.itemProvider

            // Try to load as JPEG first, then PNG
            if itemProvider.canLoadObject(ofClass: UIImage.self) {
                itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                    guard let self else { return }
                    guard let image = object as? UIImage else {
                        DispatchQueue.main.async {
                            self.onCancel()
                        }
                        return
                    }

                    // Convert to JPEG for upload (YouTube accepts JPEG, PNG, BMP, GIF)
                    // JPEG is preferred for smaller file size
                    if let jpegData = image.jpegData(compressionQuality: 0.9) {
                        DispatchQueue.main.async {
                            self.onImageSelected(jpegData, "image/jpeg")
                        }
                    } else if let pngData = image.pngData() {
                        DispatchQueue.main.async {
                            self.onImageSelected(pngData, "image/png")
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.onCancel()
                        }
                    }
                }
            } else {
                onCancel()
            }
        }
    }
}
