import AVFoundation
import Foundation
import SwiftUI

/// ViewModel responsible for managing face capture operations.
/// Handles front camera setup, real-time face detection, and face image capture/storage.
@MainActor
final class FaceCaptureViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Whether the front camera has been configured
    @Published private(set) var isCameraConfigured: Bool = false

    /// Whether a face is currently detected in the camera feed
    @Published private(set) var isFaceDetected: Bool = false

    /// Whether a capture is currently in progress
    @Published private(set) var isCapturing: Bool = false

    /// Whether the face has been successfully saved
    @Published private(set) var isFaceSaved: Bool = false

    /// Error message to display, if any
    @Published private(set) var errorMessage: String?

    /// Guidance text shown to the user
    @Published private(set) var guidanceText: String = "顔をフレーム内に合わせてください"

    // MARK: - Dependencies

    private let faceCaptureService: FaceCaptureServiceProtocol
    private let faceDetectionService: FaceDetectionServiceProtocol
    private let faceRepository: FaceRepositoryProtocol

    // MARK: - Public Properties

    /// The AVCaptureSession for the camera preview
    var captureSession: AVCaptureSession {
        faceCaptureService.captureSession
    }

    // MARK: - Initialization

    init(
        faceCaptureService: FaceCaptureServiceProtocol = FaceCaptureService(),
        faceDetectionService: FaceDetectionServiceProtocol = FaceDetectionService(),
        faceRepository: FaceRepositoryProtocol = FaceRepository()
    ) {
        self.faceCaptureService = faceCaptureService
        self.faceDetectionService = faceDetectionService
        self.faceRepository = faceRepository

        setupFaceDetectionCallback()
    }

    // MARK: - Public Methods

    /// Sets up and starts the front camera with face detection
    func setupCamera() {
        guard !isCameraConfigured else { return }

        do {
            try faceCaptureService.configure()
            isCameraConfigured = true
            faceCaptureService.start()

            // Start face detection on the capture session
            try faceDetectionService.startDetection(on: faceCaptureService.captureSession)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            isCameraConfigured = false
        }
    }

    /// Stops the camera and face detection
    func stopCamera() {
        faceDetectionService.stopDetection()
        faceCaptureService.stop()
    }

    /// Captures the current frame and saves the face data
    func captureAndSaveFace() async {
        guard !isCapturing else { return }
        guard isFaceDetected else {
            errorMessage = "顔が検出されていません。フレーム内に顔を合わせてください。"
            return
        }

        isCapturing = true
        errorMessage = nil
        guidanceText = "撮影中..."

        do {
            // Capture photo from front camera
            let imageData = try await faceCaptureService.capturePhoto()

            // Verify face exists in the captured image
            let hasFace = faceDetectionService.detectFace(in: imageData)
            guard hasFace else {
                errorMessage = "撮影された画像に顔が検出されませんでした。もう一度お試しください。"
                isCapturing = false
                guidanceText = "顔をフレーム内に合わせてください"
                return
            }

            // Save face data locally
            try faceRepository.saveFace(imageData)

            isFaceSaved = true
            isCapturing = false
            guidanceText = "顔の登録が完了しました"
        } catch {
            errorMessage = error.localizedDescription
            isCapturing = false
            guidanceText = "顔をフレーム内に合わせてください"
        }
    }

    // MARK: - Private Methods

    private func setupFaceDetectionCallback() {
        faceDetectionService.onFaceDetectionChanged = { [weak self] detected in
            Task { @MainActor [weak self] in
                guard let self, !self.isCapturing, !self.isFaceSaved else { return }
                self.isFaceDetected = detected
                if detected {
                    self.guidanceText = "そのままの位置でシャッターボタンをタップしてください"
                } else {
                    self.guidanceText = "顔をフレーム内に合わせてください"
                }
            }
        }
    }
}
