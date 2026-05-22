import AVFoundation
import Foundation
import UIKit

/// Error types for face capture service operations
enum FaceCaptureServiceError: LocalizedError {
    case frontCameraUnavailable
    case cannotAddInput
    case cannotAddOutput
    case captureInProgress
    case captureFailed(String)

    var errorDescription: String? {
        switch self {
        case .frontCameraUnavailable:
            return "フロントカメラが利用できません"
        case .cannotAddInput:
            return "カメラ入力の設定に失敗しました"
        case .cannotAddOutput:
            return "カメラ出力の設定に失敗しました"
        case .captureInProgress:
            return "撮影処理が進行中です"
        case .captureFailed(let message):
            return "撮影に失敗しました: \(message)"
        }
    }
}

/// Protocol for the face capture camera service (front camera)
protocol FaceCaptureServiceProtocol: AnyObject {
    /// The AVCaptureSession for preview display
    var captureSession: AVCaptureSession { get }

    /// Whether the camera session is currently running
    var isRunning: Bool { get }

    /// Configures the camera session with the front camera
    func configure() throws

    /// Starts the camera capture session
    func start()

    /// Stops the camera capture session
    func stop()

    /// Captures a photo and returns the JPEG image data
    func capturePhoto() async throws -> Data
}

/// Camera service specifically configured for face capture using the front camera.
final class FaceCaptureService: NSObject, FaceCaptureServiceProtocol {

    let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var photoContinuation: CheckedContinuation<Data, Error>?
    private let sessionQueue = DispatchQueue(label: "com.blurCam.faceCaptureSessionQueue")

    var isRunning: Bool {
        captureSession.isRunning
    }

    func configure() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Set session preset for photo capture
        captureSession.sessionPreset = .photo

        // Add video input (front camera)
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw FaceCaptureServiceError.frontCameraUnavailable
        }

        let videoInput = try AVCaptureDeviceInput(device: frontCamera)
        guard captureSession.canAddInput(videoInput) else {
            throw FaceCaptureServiceError.cannotAddInput
        }
        captureSession.addInput(videoInput)

        // Add photo output
        guard captureSession.canAddOutput(photoOutput) else {
            throw FaceCaptureServiceError.cannotAddOutput
        }
        captureSession.addOutput(photoOutput)

        // Configure photo output
        photoOutput.maxPhotoQualityPrioritization = .quality
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }

    func capturePhoto() async throws -> Data {
        guard photoContinuation == nil else {
            throw FaceCaptureServiceError.captureInProgress
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation

            let settings = AVCapturePhotoSettings()
            sessionQueue.async { [weak self] in
                guard let self else { return }
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension FaceCaptureService: AVCapturePhotoCaptureDelegate {

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        defer { photoContinuation = nil }

        if let error {
            photoContinuation?.resume(throwing: FaceCaptureServiceError.captureFailed(error.localizedDescription))
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            photoContinuation?.resume(throwing: FaceCaptureServiceError.captureFailed("画像データの取得に失敗しました"))
            return
        }

        // Convert to JPEG for consistent storage
        if let uiImage = UIImage(data: imageData),
           let jpegData = uiImage.jpegData(compressionQuality: 0.9) {
            photoContinuation?.resume(returning: jpegData)
        } else {
            photoContinuation?.resume(returning: imageData)
        }
    }
}
