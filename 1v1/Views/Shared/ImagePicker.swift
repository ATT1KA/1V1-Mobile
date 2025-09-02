import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    let sourceType: UIImagePickerController.SourceType
    var quality: CGFloat = 0.8
    var onCompressionPreview: ((Int) -> Void)?

    init(selectedImage: Binding<UIImage?>, sourceType: UIImagePickerController.SourceType = .photoLibrary, quality: CGFloat = 0.8, onCompressionPreview: ((Int) -> Void)? = nil) {
        self._selectedImage = selectedImage
        self.sourceType = sourceType
        self.quality = quality
        self.onCompressionPreview = onCompressionPreview
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            var chosenImage: UIImage?

            if let editedImage = info[.editedImage] as? UIImage {
                chosenImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                chosenImage = originalImage
            }

            // Orientation correction
            if let image = chosenImage {
                let corrected = image.fixOrientation()

                // Minimum resolution validation for OCR
                let minWidth: CGFloat = 800
                let minHeight: CGFloat = 600
                if corrected.size.width < minWidth || corrected.size.height < minHeight {
                    // indicate invalid via preview callback (-1)
                    parent.onCompressionPreview?(-1)
                    parent.dismiss()
                    return
                }

                // Compression preview
                if let data = corrected.jpegData(compressionQuality: parent.quality) {
                    parent.onCompressionPreview?(data.count)
                }

                // Assign final image
                parent.selectedImage = corrected
            }

            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - UIImage Orientation Fix
extension UIImage {
    func fixOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }
}

