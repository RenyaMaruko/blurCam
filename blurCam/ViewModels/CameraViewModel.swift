import AudioToolbox
import AVFoundation
import CoreImage
import Foundation
import SwiftUI

/// ViewModel responsible for managing camera operations including
/// session management, real-time face detection/blur processing,
/// photo capture, video recording with mode switching,
/// camera switching, flash control, media preview,
/// and blur intensity configuration.
@MainActor
final class CameraViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var captureState: CaptureState = .idle
    @Published private(set) var isCameraConfigured: Bool = false
    @Published private(set) var errorMessage: String?

    /// Detected faces in the current frame (for UI overlay)
    @Published private(set) var detectedFaces: [DetectedFace] = []

    /// Current camera mode (photo or video)
    @Published var cameraMode: CameraMode = .photo

    /// Recording elapsed time in seconds
    @Published private(set) var recordingDuration: TimeInterval = 0

    /// Current camera position (front or back)
    @Published private(set) var cameraPosition: CameraPosition = .back

    /// Current flash mode
    @Published private(set) var flashMode: FlashMode = .off

    /// Whether the current camera device has a flash
    @Published private(set) var hasFlash: Bool = false

    /// Whether the camera is in the process of switching (for animation)
    @Published private(set) var isSwitchingCamera: Bool = false

    /// The latest captured media item for thumbnail display
    @Published private(set) var latestMediaItem: MediaItem?

    /// Whether to show the media preview screen
    @Published var showMediaPreview: Bool = false

    /// Current zoom display text (e.g. "0.5x", "1x", "2.3x")
    @Published private(set) var zoomDisplayText: String = "1x"

    // MARK: - Dependencies

    private let cameraService: CameraServiceProtocol
    private let photoRepository: PhotoRepositoryProtocol
    private let permissionRepository: PermissionRepositoryProtocol
    private let faceRepository: FaceRepositoryProtocol
    private let videoFrameProcessor: VideoFrameProcessorProtocol
    private let videoRecordingService: VideoRecordingServiceProtocol

    // MARK: - Public Properties

    /// The AVCaptureSession for use by the camera preview layer
    var captureSession: AVCaptureSession {
        cameraService.captureSession
    }

    /// The frame publisher for displaying processed frames
    let framePublisher = FramePublisher()

    /// Whether video is currently being recorded
    var isRecording: Bool {
        captureState == .recording
    }

    /// Formatted recording duration string (MM:SS)
    var formattedRecordingDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Private Properties

    private var recordingTimer: Timer?
    private var recordingStartTime: Date?

    // MARK: - Initialization

    init(
        cameraService: CameraServiceProtocol = CameraService(),
        photoRepository: PhotoRepositoryProtocol = PhotoRepository(),
        permissionRepository: PermissionRepositoryProtocol = PermissionRepository(),
        faceRepository: FaceRepositoryProtocol = FaceRepository(),
        videoFrameProcessor: VideoFrameProcessorProtocol? = nil,
        videoRecordingService: VideoRecordingServiceProtocol? = nil
    ) {
        self.cameraService = cameraService
        self.photoRepository = photoRepository
        self.permissionRepository = permissionRepository
        self.faceRepository = faceRepository
        self.videoFrameProcessor = videoFrameProcessor ?? VideoFrameProcessor()
        self.videoRecordingService = videoRecordingService ?? VideoRecordingService()

        setupFrameProcessorCallbacks()
    }

    // MARK: - Public Methods

    /// Sets up the camera session. Should be called after permissions are granted.
    func setupCamera() {
        guard !isCameraConfigured else { return }

        do {
            try cameraService.configure()
            isCameraConfigured = true
            cameraPosition = cameraService.currentPosition
            hasFlash = cameraService.hasFlash

            // Load registered face data for recognition
            loadRegisteredFaceData()

            // Start video frame processing for real-time blur
            try videoFrameProcessor.startProcessing(on: cameraService.captureSession)

            // Pre-configure audio capture so recording start/stop doesn't need session reconfiguration
            if permissionRepository.microphonePermissionStatus() == .authorized {
                try? videoFrameProcessor.startAudioCapture(on: cameraService.captureSession)
            }

            cameraService.start()
            errorMessage = nil

            // Start at 1x (standard) by setting zoom to switch-over point
            let initialZoom = switchOverFactor
            cameraService.setZoomFactor(initialZoom)
            updateZoomDisplayText()

            // Load the latest media thumbnail
            loadLatestMedia()
        } catch {
            errorMessage = error.localizedDescription
            isCameraConfigured = false
        }
    }

    /// Starts the camera session (safe to call multiple times)
    func startCamera() {
        guard isCameraConfigured, !cameraService.isRunning else { return }
        cameraService.start()
    }

    /// Stops the camera session
    func stopCamera() {
        if isRecording {
            Task {
                await stopRecording()
            }
        }
        videoFrameProcessor.stopProcessing()
        cameraService.stop()
    }

    /// Captures a photo and saves it to the photo library with blur applied
    func capturePhoto() async {
        guard captureState != .capturing else { return }

        // Immediate visual feedback — button animates and returns instantly
        captureState = .capturing
        errorMessage = nil

        // Return button to normal quickly so it doesn't feel stuck
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            if captureState == .capturing {
                captureState = .idle
            }
        }

        // Check photo library permission first
        let photoPermission = permissionRepository.photoLibraryPermissionStatus()
        if photoPermission == .notDetermined {
            let newStatus = await permissionRepository.requestPhotoLibraryPermission()
            if newStatus == .denied {
                errorMessage = "フォトライブラリへのアクセスが拒否されました"
                return
            }
        } else if photoPermission == .denied {
            errorMessage = "フォトライブラリへのアクセスが拒否されました"
            return
        }

        do {
            let imageData = try await cameraService.capturePhoto()

            // Process the captured photo to apply blur to unregistered faces
            let processedData: Data
            if let blurredData = videoFrameProcessor.processStillImage(imageData) {
                processedData = blurredData
            } else {
                processedData = imageData
            }

            try await photoRepository.savePhoto(processedData)

            // Update the latest media thumbnail
            loadLatestMedia()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Handles the shutter button action based on current mode
    func handleShutterAction() {
        switch cameraMode {
        case .photo:
            // Fire and forget — button returns immediately
            Task { await capturePhoto() }
        case .video:
            if isRecording {
                // Immediate UI feedback for stop
                captureState = .stoppingRecording
                Task { await stopRecording() }
            } else {
                Task { await startRecording() }
            }
        }
    }

    /// Starts video recording
    func startRecording() async {
        guard captureState == .idle else { return }

        // Immediate UI feedback — button changes to square + play sound instantly
        captureState = .recording
        recordingDuration = 0
        recordingStartTime = Date()
        startRecordingTimer()
        AudioServicesPlaySystemSound(1117) // iPhone video recording start sound
        errorMessage = nil

        // Audio is pre-configured at camera setup — just check if it's available
        let includeAudio = (permissionRepository.microphonePermissionStatus() == .authorized)

        let width = videoFrameProcessor.videoWidth > 0 ? videoFrameProcessor.videoWidth : 1920
        let height = videoFrameProcessor.videoHeight > 0 ? videoFrameProcessor.videoHeight : 1080

        do {
            try videoRecordingService.startRecording(
                width: width,
                height: height,
                includeAudio: includeAudio
            )
            setupRecordingCallbacks()
            if flashMode == .on {
                try? cameraService.enableTorch()
            }
        } catch {
            errorMessage = error.localizedDescription
            captureState = .idle
            stopRecordingTimer()
        }
    }

    /// Stops video recording and saves the video
    func stopRecording() async {
        guard captureState == .recording || captureState == .stoppingRecording else { return }

        // Immediate UI feedback — button changes back + sound
        captureState = .idle
        stopRecordingTimer()
        AudioServicesPlaySystemSound(1118) // iPhone video recording stop sound
        cameraService.disableTorch()
        teardownRecordingCallbacks()

        // Heavy work (audio teardown, finalize video, save) on background
        let processor = videoFrameProcessor
        let recorder = videoRecordingService
        let photoRepo = photoRepository

        Task.detached { [weak self] in
            // Audio stays configured — no need to tear down between recordings
            do {
                let videoURL = try await recorder.stopRecording()
                try await photoRepo.saveVideo(videoURL)
                try? FileManager.default.removeItem(at: videoURL)

                await MainActor.run {
                    self?.loadLatestMedia()
                }
            } catch {
                await MainActor.run {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Camera Switch

    /// Switches between front and back camera with animation
    func switchCamera() {
        guard isCameraConfigured, !isSwitchingCamera, !isRecording else { return }

        // Start animation immediately on main thread
        isSwitchingCamera = true

        // Do camera switch on background thread to not block the animation
        let session = cameraService.captureSession
        let processor = videoFrameProcessor
        let service = cameraService

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            session.stopRunning()
            processor.stopProcessing()

            do {
                let newPosition = try service.switchCamera()
                try processor.startProcessing(on: session)
                session.startRunning()

                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.cameraPosition = newPosition
                    self.hasFlash = service.hasFlash
                    if !self.hasFlash && self.flashMode != .off {
                        self.flashMode = .off
                        service.flashMode = .off
                    }
                    self.loadRegisteredFaceData()
                }
            } catch {
                session.startRunning()
                Task { @MainActor [weak self] in
                    self?.errorMessage = error.localizedDescription
                }
            }

            // End animation after camera is ready
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 200_000_000)
                self?.isSwitchingCamera = false
            }
        }
    }

    // MARK: - Flash Control

    /// Cycles the flash mode: off -> auto -> on -> off
    func toggleFlashMode() {
        let newMode = flashMode.next
        flashMode = newMode
        cameraService.flashMode = newMode
    }

    // MARK: - Zoom

    var zoomFactor: CGFloat {
        cameraService.zoomFactor
    }

    func setZoomFactor(_ factor: CGFloat) {
        cameraService.setZoomFactor(factor)
        updateZoomDisplayText()
    }

    /// The switch-over zoom factor where the camera switches from ultra-wide to wide lens.
    /// On DualWide/Triple cameras this is typically 2.0, meaning zoom 1.0 = ultra-wide (0.5x display).
    private var switchOverFactor: CGFloat {
        // Read from the device's virtualDeviceSwitchOverVideoZoomFactors
        if let first = cameraService.captureSession.inputs
            .compactMap({ ($0 as? AVCaptureDeviceInput)?.device })
            .first?.virtualDeviceSwitchOverVideoZoomFactors.first {
            return CGFloat(first.doubleValue)
        }
        return 1.0 // Single lens: no conversion needed
    }

    private func updateZoomDisplayText() {
        let factor = cameraService.zoomFactor
        // Convert device zoom to display zoom (e.g. device 1.0 = display 0.5x when switchOver=2)
        let displayFactor = factor / switchOverFactor

        if abs(displayFactor - 1.0) < 0.05 {
            zoomDisplayText = "1x"
        } else if abs(displayFactor - 0.5) < 0.03 {
            zoomDisplayText = "0.5x"
        } else if displayFactor == floor(displayFactor) {
            zoomDisplayText = "\(Int(displayFactor))x"
        } else {
            zoomDisplayText = String(format: "%.1fx", displayFactor)
        }
    }

    // MARK: - Media Preview

    /// Loads the latest media item from the photo library
    func loadLatestMedia() {
        Task {
            let item = await photoRepository.fetchLatestMedia()
            await MainActor.run {
                latestMediaItem = item
            }
        }
    }

    // MARK: - Blur Intensity

    /// Applies a blur intensity setting to the blur processing service
    func applyBlurIntensity(_ intensity: BlurIntensity) {
        videoFrameProcessor.blurProcessingService.blurRadius = intensity.blurRadius
    }

    // MARK: - Face Data Reloading

    /// Reloads all registered face data from the repository.
    /// Called when faces are added or deleted from settings.
    func reloadRegisteredFaces() {
        loadRegisteredFaceData()
    }

    // MARK: - Private Methods

    private func setupFrameProcessorCallbacks() {
        videoFrameProcessor.onFrameProcessed = { [weak self] ciImage in
            guard let self else { return }
            self.framePublisher.updateFrame(ciImage)
        }

        videoFrameProcessor.onFacesDetected = { [weak self] faces in
            guard let self else { return }
            self.framePublisher.updateFaces(faces)
            DispatchQueue.main.async {
                self.detectedFaces = faces
            }
        }
    }

    private func setupRecordingCallbacks() {
        videoFrameProcessor.onProcessedPixelBuffer = { [weak self] pixelBuffer, presentationTime in
            guard let self else { return }
            self.videoRecordingService.appendVideoFrame(pixelBuffer, at: presentationTime)
        }

        videoFrameProcessor.onAudioSampleBuffer = { [weak self] sampleBuffer in
            guard let self else { return }
            self.videoRecordingService.appendAudioSample(sampleBuffer)
        }
    }

    private func teardownRecordingCallbacks() {
        videoFrameProcessor.onProcessedPixelBuffer = nil
        videoFrameProcessor.onAudioSampleBuffer = nil
    }

    private func loadRegisteredFaceData() {
        let registrations = faceRepository.loadAllRegistrations()
        var faceImageDataArray: [Data] = []

        for registration in registrations {
            if let faceImageData = faceRepository.loadFaceImage(for: registration) {
                faceImageDataArray.append(faceImageData)
            }
        }

        if faceImageDataArray.isEmpty {
            // Fall back to legacy single registration
            if let registration = faceRepository.loadRegistration(),
               let faceImageData = faceRepository.loadFaceImage(for: registration) {
                faceImageDataArray.append(faceImageData)
            }
        }

        if !faceImageDataArray.isEmpty {
            videoFrameProcessor.loadRegisteredFaces(from: faceImageDataArray)
        }
    }

    private func resetCaptureStateAfterDelay() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            if captureState != .idle && captureState != .recording {
                captureState = .idle
            }
        }
    }

    // MARK: - Recording Timer

    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
    }
}
