import AVFoundation
import Foundation
import UIKit

/// Error types for camera service operations
enum CameraServiceError: LocalizedError {
    case cameraUnavailable
    case cannotAddInput
    case cannotAddOutput
    case captureInProgress
    case captureFailed(String)
    case switchFailed(String)
    case torchUnavailable

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "カメラが利用できません"
        case .cannotAddInput:
            return "カメラ入力の設定に失敗しました"
        case .cannotAddOutput:
            return "カメラ出力の設定に失敗しました"
        case .captureInProgress:
            return "撮影処理が進行中です"
        case .captureFailed(let message):
            return "撮影に失敗しました: \(message)"
        case .switchFailed(let message):
            return "カメラの切り替えに失敗しました: \(message)"
        case .torchUnavailable:
            return "トーチが利用できません"
        }
    }
}

/// Concrete implementation of CameraServiceProtocol using AVFoundation
final class CameraService: NSObject, CameraServiceProtocol {

    let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var photoContinuation: CheckedContinuation<Data, Error>?
    private let sessionQueue = DispatchQueue(label: "com.blurCam.cameraSessionQueue")

    private(set) var currentPosition: CameraPosition = .back
    var flashMode: FlashMode = .off
    private var currentDeviceInput: AVCaptureDeviceInput?

    var isRunning: Bool {
        captureSession.isRunning
    }

    var hasFlash: Bool {
        currentDeviceInput?.device.hasFlash ?? false
    }

    var isTorchActive: Bool {
        guard let device = currentDeviceInput?.device else { return false }
        return device.hasTorch && device.isTorchActive
    }

    func configure() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Use .inputPriority to let the device format control zoom range (enables ultra-wide)
        captureSession.sessionPreset = .inputPriority

        // Use DiscoverySession to find the best multi-lens camera (enables ultra-wide 0.5x)
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInWideAngleCamera
            ],
            mediaType: .video,
            position: .back
        )

        guard let camera = discovery.devices.first else {
            throw CameraServiceError.cameraUnavailable
        }

        // Debug log removed

        let videoInput = try AVCaptureDeviceInput(device: camera)
        guard captureSession.canAddInput(videoInput) else {
            throw CameraServiceError.cannotAddInput
        }
        captureSession.addInput(videoInput)
        currentDeviceInput = videoInput
        currentPosition = .back

        // Add photo output
        guard captureSession.canAddOutput(photoOutput) else {
            throw CameraServiceError.cannotAddOutput
        }
        captureSession.addOutput(photoOutput)

        // Configure photo output for highest quality
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
            throw CameraServiceError.captureInProgress
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation

            let settings = AVCapturePhotoSettings()

            // Apply flash mode setting
            if hasFlash {
                switch flashMode {
                case .off:
                    settings.flashMode = .off
                case .auto:
                    settings.flashMode = .auto
                case .on:
                    settings.flashMode = .on
                }
            }

            // Use HEIF format if available for better quality/size ratio
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                let hevcSettings = AVCapturePhotoSettings(
                    format: [AVVideoCodecKey: AVVideoCodecType.hevc]
                )
                // Apply flash mode to HEVC settings too
                if hasFlash {
                    switch flashMode {
                    case .off:
                        hevcSettings.flashMode = .off
                    case .auto:
                        hevcSettings.flashMode = .auto
                    case .on:
                        hevcSettings.flashMode = .on
                    }
                }
                sessionQueue.async { [weak self] in
                    self?.photoOutput.capturePhoto(with: hevcSettings, delegate: self!)
                }
            } else {
                sessionQueue.async { [weak self] in
                    self?.photoOutput.capturePhoto(with: settings, delegate: self!)
                }
            }
        }
    }

    @discardableResult
    func switchCamera() throws -> CameraPosition {
        let newPosition = currentPosition.toggled

        // Find the camera for the new position
        let newCamera: AVCaptureDevice?
        if newPosition == .back {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera],
                mediaType: .video,
                position: .back
            )
            newCamera = discovery.devices.first
        } else {
            newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }

        guard let newCamera else {
            throw CameraServiceError.switchFailed("対象のカメラが見つかりません")
        }

        let newInput: AVCaptureDeviceInput
        do {
            newInput = try AVCaptureDeviceInput(device: newCamera)
        } catch {
            throw CameraServiceError.switchFailed(error.localizedDescription)
        }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Remove the current video input
        if let currentInput = currentDeviceInput {
            captureSession.removeInput(currentInput)
        }

        // Add the new input
        guard captureSession.canAddInput(newInput) else {
            // Restore the old input if we can't add the new one
            if let currentInput = currentDeviceInput {
                if captureSession.canAddInput(currentInput) {
                    captureSession.addInput(currentInput)
                }
            }
            throw CameraServiceError.switchFailed("新しいカメラ入力を追加できません")
        }

        captureSession.addInput(newInput)
        currentDeviceInput = newInput
        currentPosition = newPosition

        return newPosition
    }

    func enableTorch() throws {
        guard let device = currentDeviceInput?.device,
              device.hasTorch,
              device.isTorchAvailable else {
            throw CameraServiceError.torchUnavailable
        }

        try device.lockForConfiguration()
        device.torchMode = .on
        try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
        device.unlockForConfiguration()
    }

    func disableTorch() {
        guard let device = currentDeviceInput?.device,
              device.hasTorch else {
            return
        }

        do {
            try device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        } catch {
            // Silently fail - torch control is non-critical
        }
    }

    // MARK: - Zoom

    var zoomFactor: CGFloat {
        CGFloat(currentDeviceInput?.device.videoZoomFactor ?? 1.0)
    }

    var maxZoomFactor: CGFloat {
        min(CGFloat(currentDeviceInput?.device.activeFormat.videoMaxZoomFactor ?? 5.0), 10.0)
    }

    var minZoomFactor: CGFloat {
        CGFloat(currentDeviceInput?.device.minAvailableVideoZoomFactor ?? 1.0)
    }

    func setZoomFactor(_ factor: CGFloat) {
        guard let device = currentDeviceInput?.device else { return }
        let clamped = min(max(factor, minZoomFactor), maxZoomFactor)
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        } catch {
            // Silently fail
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        defer { photoContinuation = nil }

        if let error {
            photoContinuation?.resume(throwing: CameraServiceError.captureFailed(error.localizedDescription))
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            photoContinuation?.resume(throwing: CameraServiceError.captureFailed("画像データの取得に失敗しました"))
            return
        }

        photoContinuation?.resume(returning: imageData)
    }
}
