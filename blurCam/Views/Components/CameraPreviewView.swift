import AVFoundation
import SwiftUI
import UIKit

/// A UIViewRepresentable that displays the AVCaptureSession's video preview.
/// Uses AVCaptureVideoPreviewLayer for efficient, real-time camera display.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }
}

/// Custom UIView subclass that uses AVCaptureVideoPreviewLayer as its backing layer.
/// This ensures the preview layer always fills the entire view bounds.
final class CameraPreviewUIView: UIView {

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // swiftlint:disable:next force_cast
        layer as! AVCaptureVideoPreviewLayer
    }
}
