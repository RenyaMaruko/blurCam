import AudioToolbox
import AVFoundation
import CoreImage
import Foundation
import Network
import SwiftUI

/// ViewModel responsible for managing camera operations including
/// session management, real-time face detection/blur processing,
/// photo capture, video recording with mode switching,
/// camera switching, flash control, media preview,
/// blur intensity configuration, and RTMP live streaming.
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

    /// Current streaming state
    @Published private(set) var streamingState: StreamingState = .idle

    /// Streaming elapsed time in seconds
    @Published private(set) var streamingDuration: TimeInterval = 0

    /// Whether the network connection is currently unsatisfied (no connectivity)
    @Published private(set) var isNetworkUnsatisfied: Bool = false

    /// Whether the user has requested to stop streaming (triggers confirmation dialog)
    @Published var showStopStreamingConfirmation: Bool = false

    // MARK: - Dependencies

    private let cameraService: CameraServiceProtocol
    private let photoRepository: PhotoRepositoryProtocol
    private let permissionRepository: PermissionRepositoryProtocol
    private let faceRepository: FaceRepositoryProtocol
    private let videoFrameProcessor: VideoFrameProcessorProtocol
    private let videoRecordingService: VideoRecordingServiceProtocol
    private let streamingService: StreamingServiceProtocol
    private let streamingSettingsRepository: StreamingSettingsRepositoryProtocol

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

    /// Whether live streaming is currently active
    var isStreaming: Bool {
        streamingState == .streaming
    }

    /// Formatted recording duration string (MM:SS)
    var formattedRecordingDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Formatted streaming duration string (HH:MM:SS)
    var formattedStreamingDuration: String {
        let totalSeconds = Int(streamingDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    // MARK: - Private Properties

    private var recordingTimer: Timer?
    private var recordingStartTime: Date?

    private var streamingTimer: Timer?
    private var streamingStartTime: Date?

    private var networkMonitor: NWPathMonitor?
    private let networkMonitorQueue = DispatchQueue(label: "com.blurCam.networkMonitor")

    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    // MARK: - Initialization

    init(
        cameraService: CameraServiceProtocol = CameraService(),
        photoRepository: PhotoRepositoryProtocol = PhotoRepository(),
        permissionRepository: PermissionRepositoryProtocol = PermissionRepository(),
        faceRepository: FaceRepositoryProtocol = FaceRepository(),
        videoFrameProcessor: VideoFrameProcessorProtocol? = nil,
        videoRecordingService: VideoRecordingServiceProtocol? = nil,
        streamingService: StreamingServiceProtocol? = nil,
        streamingSettingsRepository: StreamingSettingsRepositoryProtocol? = nil
    ) {
        self.cameraService = cameraService
        self.photoRepository = photoRepository
        self.permissionRepository = permissionRepository
        self.faceRepository = faceRepository
        self.videoFrameProcessor = videoFrameProcessor ?? VideoFrameProcessor()
        self.videoRecordingService = videoRecordingService ?? VideoRecordingService()
        self.streamingService = streamingService ?? StreamingService()
        self.streamingSettingsRepository = streamingSettingsRepository ?? StreamingSettingsRepository()

        setupFrameProcessorCallbacks()
        setupStreamingStateCallback()
        setupBackgroundObservers()
        setupNetworkMonitor()
    }

    deinit {
        // Clean up observers and timers to prevent leaks
        if let bgObs = backgroundObserver {
            NotificationCenter.default.removeObserver(bgObs)
        }
        if let fgObs = foregroundObserver {
            NotificationCenter.default.removeObserver(fgObs)
        }
        networkMonitor?.cancel()
        networkMonitor = nil
        recordingTimer?.invalidate()
        streamingTimer?.invalidate()
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

    /// Stops the camera session and any active streaming/recording
    func stopCamera() {
        if isRecording {
            Task {
                await stopRecording()
            }
        }
        if streamingState.isActive {
            stopStreaming()
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
        guard captureState == .idle, !streamingState.isActive else { return }

        // Immediate UI feedback — button changes to square instantly
        captureState = .recording
        recordingDuration = 0
        recordingStartTime = Date()
        startRecordingTimer()
        errorMessage = nil

        // Play sound and wait for it to finish before starting actual recording
        // so the sound doesn't get captured in the video audio
        AudioServicesPlaySystemSound(1117)
        try? await Task.sleep(nanoseconds: 350_000_000) // Wait for sound to finish (~0.35s)

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

        // Immediate UI feedback — button changes back
        captureState = .idle
        stopRecordingTimer()
        cameraService.disableTorch()
        teardownRecordingCallbacks()

        // Stop recording first, then play sound (so sound doesn't get in the video)
        let recorder = videoRecordingService
        let photoRepo = photoRepository

        Task.detached { [weak self] in
            do {
                let videoURL = try await recorder.stopRecording()

                // Play stop sound after recording is finalized
                await MainActor.run {
                    AudioServicesPlaySystemSound(1118)
                }
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

    /// Switches between front and back camera with animation.
    /// During streaming, the RTMP connection is maintained while the camera input is swapped.
    /// The streaming callbacks are temporarily removed and re-established after the switch.
    func switchCamera() {
        guard isCameraConfigured, !isSwitchingCamera, !isRecording else { return }

        isSwitchingCamera = true

        let isStreaming = streamingState.isActive
        let session = cameraService.captureSession
        let processor = videoFrameProcessor
        let service = cameraService

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if isStreaming {
                // During streaming: swap camera input without stopping session.
                // Audio and video keep flowing to RTMP, preventing YouTube disconnect.
                do {
                    let newPosition = try service.switchCamera()
                    processor.refreshVideoConnection()

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
                    Task { @MainActor [weak self] in
                        self?.errorMessage = error.localizedDescription
                    }
                }
            } else {
                // Not streaming: full stop/restart for clean state
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
            }

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

    // MARK: - Streaming

    /// Starts RTMP live streaming using the currently selected destination or legacy settings
    func startStreaming() {
        // Block if recording is in progress (mutual exclusion)
        guard !isRecording else {
            errorMessage = "録画中は配信を開始できません"
            return
        }

        // Try to load selected destination first
        let rtmpURL: String
        let streamKey: String

        if let destination = streamingSettingsRepository.loadSelectedDestination() {
            rtmpURL = destination.rtmpURL
            streamKey = destination.streamKey
        } else if let legacyURL = streamingSettingsRepository.loadRTMPURL(),
                  !legacyURL.isEmpty {
            // Fall back to legacy settings
            rtmpURL = legacyURL
            streamKey = streamingSettingsRepository.loadStreamKey() ?? ""
        } else {
            errorMessage = StreamingError.missingConfiguration.localizedDescription
            return
        }

        errorMessage = nil

        let width = videoFrameProcessor.videoWidth > 0 ? videoFrameProcessor.videoWidth : 1920
        let height = videoFrameProcessor.videoHeight > 0 ? videoFrameProcessor.videoHeight : 1080

        do {
            try streamingService.startStreaming(
                url: rtmpURL,
                streamKey: streamKey,
                width: width,
                height: height
            )
            setupStreamingCallbacks()
        } catch {
            errorMessage = error.localizedDescription
            streamingState = .idle
        }
    }

    /// Starts RTMP live streaming with explicit URL and stream key
    func startStreaming(url: String, streamKey: String) {
        guard !isRecording else {
            errorMessage = "録画中は配信を開始できません"
            return
        }

        errorMessage = nil

        let width = videoFrameProcessor.videoWidth > 0 ? videoFrameProcessor.videoWidth : 1920
        let height = videoFrameProcessor.videoHeight > 0 ? videoFrameProcessor.videoHeight : 1080

        do {
            try streamingService.startStreaming(
                url: url,
                streamKey: streamKey,
                width: width,
                height: height
            )
            setupStreamingCallbacks()
        } catch {
            errorMessage = error.localizedDescription
            streamingState = .idle
        }
    }

    /// Requests streaming stop with a confirmation dialog.
    /// If streaming is active, sets showStopStreamingConfirmation to true.
    func requestStopStreaming() {
        guard streamingState.isActive else { return }
        showStopStreamingConfirmation = true
    }

    /// Stops RTMP live streaming and cleans up timer and callbacks
    func stopStreaming() {
        teardownStreamingCallbacks()
        stopStreamingTimer()
        streamingService.stopStreaming()
        streamingState = .idle
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

    private func setupStreamingStateCallback() {
        streamingService.onStateChanged = { [weak self] newState in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.streamingState = newState

                switch newState {
                case .streaming:
                    // Start the streaming elapsed timer when streaming begins
                    self.startStreamingTimer()
                case .error(let message):
                    self.errorMessage = message
                    self.teardownStreamingCallbacks()
                    self.stopStreamingTimer()
                case .idle:
                    self.stopStreamingTimer()
                case .connecting:
                    break
                }
            }
        }
    }

    private func setupStreamingCallbacks() {
        videoFrameProcessor.onProcessedPixelBuffer = { [weak self] pixelBuffer, presentationTime in
            guard let self else { return }
            self.streamingService.appendVideo(pixelBuffer, presentationTime: presentationTime)
        }

        videoFrameProcessor.onAudioSampleBuffer = { [weak self] sampleBuffer in
            guard let self else { return }
            self.streamingService.appendAudio(sampleBuffer)
        }
    }

    private func teardownStreamingCallbacks() {
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

        // Always update — pass empty array to clear when all faces are deleted
        videoFrameProcessor.loadRegisteredFaces(from: faceImageDataArray)
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

    // MARK: - Streaming Timer

    private func startStreamingTimer() {
        // Only start if not already running
        guard streamingTimer == nil else { return }
        streamingDuration = 0
        streamingStartTime = Date()
        streamingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let startTime = self.streamingStartTime else { return }
                self.streamingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopStreamingTimer() {
        streamingTimer?.invalidate()
        streamingTimer = nil
        streamingStartTime = nil
        streamingDuration = 0
    }

    // MARK: - Background / Foreground Observers

    private func setupBackgroundObservers() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleBackgroundTransition()
            }
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleForegroundTransition()
            }
        }
    }

    /// Called when the app moves to background. Stops streaming to prevent resource issues.
    private func handleBackgroundTransition() {
        if streamingState.isActive {
            stopStreaming()
        }
    }

    /// Called when the app returns to foreground. Ensures UI state is consistent.
    private func handleForegroundTransition() {
        // Streaming was stopped on background transition, ensure UI reflects idle state
        if streamingState != .idle && !streamingService.streamingState.isActive {
            streamingState = .idle
            stopStreamingTimer()
        }
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitor() {
        let monitor = NWPathMonitor()
        self.networkMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let unsatisfied = (path.status != .satisfied)
                self.isNetworkUnsatisfied = unsatisfied
            }
        }
        monitor.start(queue: networkMonitorQueue)
    }
}
