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

            cameraService.start()
            errorMessage = nil

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

        captureState = .capturing
        errorMessage = nil

        // Check photo library permission first
        let photoPermission = permissionRepository.photoLibraryPermissionStatus()
        if photoPermission == .notDetermined {
            let newStatus = await permissionRepository.requestPhotoLibraryPermission()
            if newStatus == .denied {
                captureState = .failed("フォトライブラリへのアクセスが拒否されました")
                errorMessage = "フォトライブラリへのアクセスが拒否されました"
                resetCaptureStateAfterDelay()
                return
            }
        } else if photoPermission == .denied {
            captureState = .failed("フォトライブラリへのアクセスが拒否されました")
            errorMessage = "フォトライブラリへのアクセスが拒否されました"
            resetCaptureStateAfterDelay()
            return
        }

        do {
            let imageData = try await cameraService.capturePhoto()

            // Process the captured photo to apply blur to unregistered faces
            let processedData: Data
            if let blurredData = videoFrameProcessor.processStillImage(imageData) {
                processedData = blurredData
            } else {
                // Fall back to original data if processing fails
                processedData = imageData
            }

            try await photoRepository.savePhoto(processedData)
            captureState = .captured

            // Update the latest media thumbnail
            loadLatestMedia()

            resetCaptureStateAfterDelay()
        } catch {
            captureState = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
            resetCaptureStateAfterDelay()
        }
    }

    /// Handles the shutter button action based on current mode
    func handleShutterAction() {
        switch cameraMode {
        case .photo:
            Task {
                await capturePhoto()
            }
        case .video:
            if isRecording {
                Task {
                    await stopRecording()
                }
            } else {
                Task {
                    await startRecording()
                }
            }
        }
    }

    /// Starts video recording
    func startRecording() async {
        guard captureState == .idle else { return }
        errorMessage = nil

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

        // Check microphone permission - request if not determined
        let micPermission = permissionRepository.microphonePermissionStatus()
        var includeAudio = false
        if micPermission == .notDetermined {
            let newMicStatus = await permissionRepository.requestMicrophonePermission()
            includeAudio = (newMicStatus == .authorized)
        } else {
            includeAudio = (micPermission == .authorized)
        }

        // Set up audio capture if we have permission
        if includeAudio {
            do {
                try videoFrameProcessor.startAudioCapture(on: cameraService.captureSession)
            } catch {
                // Continue without audio if setup fails
                includeAudio = false
            }
        }

        // Get current video dimensions
        let width = videoFrameProcessor.videoWidth > 0 ? videoFrameProcessor.videoWidth : 1920
        let height = videoFrameProcessor.videoHeight > 0 ? videoFrameProcessor.videoHeight : 1080

        do {
            try videoRecordingService.startRecording(
                width: width,
                height: height,
                includeAudio: includeAudio
            )

            // Set up callbacks for recording
            setupRecordingCallbacks()

            // Enable torch if flash is on during video recording
            if flashMode == .on {
                try? cameraService.enableTorch()
            }

            captureState = .recording
            recordingDuration = 0
            recordingStartTime = Date()
            startRecordingTimer()
        } catch {
            errorMessage = error.localizedDescription
            videoFrameProcessor.stopAudioCapture()
        }
    }

    /// Stops video recording and saves the video
    func stopRecording() async {
        guard captureState == .recording else { return }

        captureState = .stoppingRecording
        stopRecordingTimer()

        // Disable torch when stopping recording
        cameraService.disableTorch()

        // Remove recording callbacks
        teardownRecordingCallbacks()

        // Stop audio capture
        videoFrameProcessor.stopAudioCapture()

        do {
            let videoURL = try await videoRecordingService.stopRecording()

            // Save video to photo library
            try await photoRepository.saveVideo(videoURL)

            // Clean up the temporary file
            try? FileManager.default.removeItem(at: videoURL)

            captureState = .captured

            // Update the latest media thumbnail
            loadLatestMedia()

            resetCaptureStateAfterDelay()
        } catch {
            captureState = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
            resetCaptureStateAfterDelay()
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
