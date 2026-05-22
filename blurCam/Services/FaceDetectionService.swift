import AVFoundation
import Foundation
import UIKit
import Vision

/// Error types for face detection service operations
enum FaceDetectionServiceError: LocalizedError {
    case cannotAddVideoOutput
    case detectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .cannotAddVideoOutput:
            return "ビデオ出力の追加に失敗しました"
        case .detectionFailed(let message):
            return "顔検出に失敗しました: \(message)"
        }
    }
}

/// Concrete implementation of FaceDetectionServiceProtocol using Vision framework.
/// Uses VNDetectFaceRectanglesRequest for real-time face detection from camera frames.
final class FaceDetectionService: NSObject, FaceDetectionServiceProtocol {

    // MARK: - Properties

    private(set) var isFaceDetected: Bool = false {
        didSet {
            if oldValue != isFaceDetected {
                onFaceDetectionChanged?(isFaceDetected)
            }
        }
    }

    var onFaceDetectionChanged: ((Bool) -> Void)?

    private let videoOutput = AVCaptureVideoDataOutput()
    private let detectionQueue = DispatchQueue(label: "com.blurCam.faceDetectionQueue", qos: .userInteractive)
    private var isDetectionActive = false
    private weak var captureSession: AVCaptureSession?

    // Throttle detection to avoid overwhelming the CPU
    private var lastDetectionTime: CFTimeInterval = 0
    private let detectionInterval: CFTimeInterval = 0.15 // ~6.67 detections per second

    // MARK: - FaceDetectionServiceProtocol

    func startDetection(on session: AVCaptureSession) throws {
        guard !isDetectionActive else { return }

        videoOutput.setSampleBufferDelegate(self, queue: detectionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true

        session.beginConfiguration()
        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            throw FaceDetectionServiceError.cannotAddVideoOutput
        }
        session.addOutput(videoOutput)
        session.commitConfiguration()

        captureSession = session
        isDetectionActive = true
    }

    func stopDetection() {
        guard isDetectionActive, let session = captureSession else { return }

        session.beginConfiguration()
        session.removeOutput(videoOutput)
        session.commitConfiguration()

        isDetectionActive = false
        isFaceDetected = false
        captureSession = nil
    }

    func detectFace(in imageData: Data) -> Bool {
        guard let cgImage = createCGImage(from: imageData) else {
            return false
        }

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            guard let results = request.results else {
                return false
            }
            return !results.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Private Methods

    private func createCGImage(from data: Data) -> CGImage? {
        guard let uiImage = UIImage(data: data) else {
            return nil
        }
        return uiImage.cgImage
    }

    private func performFaceDetection(on pixelBuffer: CVPixelBuffer) {
        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let self, error == nil else {
                return
            }

            let hasFace = !(request.results?.isEmpty ?? true)

            DispatchQueue.main.async {
                self.isFaceDetected = hasFace
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.isFaceDetected = false
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension FaceDetectionService: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Throttle detection
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastDetectionTime >= detectionInterval else {
            return
        }
        lastDetectionTime = currentTime

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        performFaceDetection(on: pixelBuffer)
    }
}
