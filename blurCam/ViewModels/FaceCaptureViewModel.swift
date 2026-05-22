import AVFoundation
import Foundation
import SwiftUI

/// ViewModel responsible for managing multi-angle face capture.
/// Captures 3 photos (front, slight left, slight right) for robust face recognition.
@MainActor
final class FaceCaptureViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isCameraConfigured: Bool = false
    @Published private(set) var isFaceDetected: Bool = false
    @Published private(set) var isCapturing: Bool = false
    @Published private(set) var isFaceSaved: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var guidanceText: String = "正面を向いてください"

    /// Current capture step (1, 2, or 3)
    @Published private(set) var currentStep: Int = 1

    /// Total number of captures required
    let totalSteps: Int = 3

    /// Progress (0.0 to 1.0)
    var progress: Float {
        Float(currentStep - 1) / Float(totalSteps)
    }

    // MARK: - Dependencies

    private let faceCaptureService: FaceCaptureServiceProtocol
    private let faceDetectionService: FaceDetectionServiceProtocol
    private let faceRepository: FaceRepositoryProtocol

    // MARK: - Private

    private var capturedImages: [Data] = []
    private let groupId = UUID()

    private let stepGuidance: [String] = [
        "正面を向いてください",
        "少し左を向いてください",
        "少し右を向いてください"
    ]

    // MARK: - Public Properties

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

    func setupCamera() {
        guard !isCameraConfigured else { return }

        do {
            try faceCaptureService.configure()
            isCameraConfigured = true
            // Add detection output BEFORE starting session to avoid configuration conflicts
            try faceDetectionService.startDetection(on: faceCaptureService.captureSession)
            faceCaptureService.start()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            isCameraConfigured = false
        }
    }

    func stopCamera() {
        faceDetectionService.stopDetection()
        faceCaptureService.stop()
    }

    /// Captures the current frame for the current step
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
            let imageData = try await faceCaptureService.capturePhoto()

            let hasFace = faceDetectionService.detectFace(in: imageData)
            guard hasFace else {
                errorMessage = "撮影された画像に顔が検出されませんでした。もう一度お試しください。"
                isCapturing = false
                guidanceText = stepGuidance[currentStep - 1]
                return
            }

            capturedImages.append(imageData)

            if currentStep < totalSteps {
                // Move to next step
                currentStep += 1
                isCapturing = false
                guidanceText = stepGuidance[currentStep - 1]
            } else {
                // All photos captured - save all with same groupId
                for imageData in capturedImages {
                    try faceRepository.saveFace(imageData, groupId: groupId)
                }
                isFaceSaved = true
                isCapturing = false
                guidanceText = "顔の登録が完了しました"
            }
        } catch {
            errorMessage = error.localizedDescription
            isCapturing = false
            guidanceText = stepGuidance[currentStep - 1]
        }
    }

    // MARK: - Private Methods

    private func setupFaceDetectionCallback() {
        faceDetectionService.onFaceDetectionChanged = { [weak self] detected in
            Task { @MainActor [weak self] in
                guard let self, !self.isCapturing, !self.isFaceSaved else { return }
                self.isFaceDetected = detected
                if detected {
                    self.guidanceText = "そのままシャッターをタップ (\(self.currentStep)/\(self.totalSteps))"
                } else {
                    self.guidanceText = self.stepGuidance[self.currentStep - 1]
                }
            }
        }
    }
}
