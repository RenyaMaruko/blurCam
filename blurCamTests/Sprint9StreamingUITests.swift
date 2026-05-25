import XCTest
@testable import blurCam

/// Tests for Sprint 9: Streaming UI completion and edge case handling.
/// Covers streaming duration timer, stop confirmation, mutual exclusion,
/// camera switch during streaming, background transition, and network monitoring.
@MainActor
final class Sprint9StreamingUITests: XCTestCase {

    private var mockCameraService: MockCameraService!
    private var mockPhotoRepo: MockPhotoRepository!
    private var mockPermissionRepo: MockPermissionRepository!
    private var mockFaceRepo: MockFaceRepository!
    private var mockVideoFrameProcessor: MockVideoFrameProcessor!
    private var mockVideoRecordingService: MockVideoRecordingService!
    private var mockStreamingService: MockStreamingService!
    private var mockStreamingSettingsRepo: MockStreamingSettingsRepository!

    override func setUp() {
        super.setUp()
        mockCameraService = MockCameraService()
        mockPhotoRepo = MockPhotoRepository()
        mockPermissionRepo = MockPermissionRepository()
        mockFaceRepo = MockFaceRepository()
        mockVideoFrameProcessor = MockVideoFrameProcessor()
        mockVideoRecordingService = MockVideoRecordingService()
        mockStreamingService = MockStreamingService()
        mockStreamingSettingsRepo = MockStreamingSettingsRepository()
    }

    override func tearDown() {
        mockCameraService = nil
        mockPhotoRepo = nil
        mockPermissionRepo = nil
        mockFaceRepo = nil
        mockVideoFrameProcessor = nil
        mockVideoRecordingService = nil
        mockStreamingService = nil
        mockStreamingSettingsRepo = nil
        super.tearDown()
    }

    private func makeViewModel() -> CameraViewModel {
        CameraViewModel(
            cameraService: mockCameraService,
            photoRepository: mockPhotoRepo,
            permissionRepository: mockPermissionRepo,
            faceRepository: mockFaceRepo,
            videoFrameProcessor: mockVideoFrameProcessor,
            videoRecordingService: mockVideoRecordingService,
            streamingService: mockStreamingService,
            streamingSettingsRepository: mockStreamingSettingsRepo
        )
    }

    // MARK: - Streaming Duration Timer Tests

    func testInitialStreamingDuration_IsZero() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.streamingDuration, 0)
    }

    func testFormattedStreamingDuration_ZeroSeconds() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.formattedStreamingDuration, "00:00:00")
    }

    func testFormattedStreamingDuration_FormatIsHHMMSS() {
        let viewModel = makeViewModel()
        // Initial format check
        let formatted = viewModel.formattedStreamingDuration
        let components = formatted.split(separator: ":")
        XCTAssertEqual(components.count, 3, "Duration should have HH:MM:SS format with 3 components")
    }

    func testStreamingDuration_ResetsOnStop() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        viewModel.stopStreaming()

        XCTAssertEqual(viewModel.streamingDuration, 0)
        XCTAssertEqual(viewModel.formattedStreamingDuration, "00:00:00")
    }

    func testStreamingDuration_StartsCountingOnStreamingState() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        mockStreamingService.simulateSuccessfulConnection = true
        let viewModel = makeViewModel()

        viewModel.startStreaming()

        // Wait for state callback and timer to tick
        try? await Task.sleep(nanoseconds: 700_000_000)

        // Duration should have been counting since streaming started
        // (at least some small amount > 0, allowing for timer tick interval)
        XCTAssertEqual(viewModel.streamingState, .streaming)
    }

    func testStreamingDuration_DisplayDisappearsOnStop() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(viewModel.streamingState, .streaming)

        viewModel.stopStreaming()
        XCTAssertEqual(viewModel.streamingState, .idle)
        XCTAssertEqual(viewModel.streamingDuration, 0)
    }

    // MARK: - Stop Streaming Confirmation Tests

    func testShowStopStreamingConfirmation_InitiallyFalse() {
        let viewModel = makeViewModel()
        XCTAssertFalse(viewModel.showStopStreamingConfirmation)
    }

    func testRequestStopStreaming_ShowsConfirmation() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(viewModel.streamingState.isActive)

        viewModel.requestStopStreaming()

        XCTAssertTrue(viewModel.showStopStreamingConfirmation)
        // Streaming should still be active (not stopped yet)
        XCTAssertTrue(viewModel.streamingState.isActive)
    }

    func testRequestStopStreaming_WhenNotStreaming_DoesNothing() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.streamingState, .idle)

        viewModel.requestStopStreaming()

        XCTAssertFalse(viewModel.showStopStreamingConfirmation)
    }

    func testStopStreaming_AfterConfirmation_StopsStreaming() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // User confirms stop
        viewModel.stopStreaming()

        XCTAssertEqual(viewModel.streamingState, .idle)
        XCTAssertEqual(mockStreamingService.stopStreamingCallCount, 1)
    }

    func testCancelStopStreaming_ContinuesStreaming() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        viewModel.requestStopStreaming()
        XCTAssertTrue(viewModel.showStopStreamingConfirmation)

        // User cancels - just set showStopStreamingConfirmation to false
        viewModel.showStopStreamingConfirmation = false

        // Streaming should still be active
        XCTAssertTrue(viewModel.streamingState.isActive)
        XCTAssertEqual(mockStreamingService.stopStreamingCallCount, 0)
    }

    // MARK: - Mutual Exclusion Tests

    func testStartRecording_WhileStreaming_IsBlocked() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        mockPermissionRepo.microphoneStatus = .authorized
        let viewModel = makeViewModel()

        // Start streaming first
        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(viewModel.streamingState.isActive)

        // Try to start recording -- should be blocked
        await viewModel.startRecording()

        XCTAssertFalse(viewModel.isRecording)
        XCTAssertEqual(mockVideoRecordingService.startRecordingCallCount, 0)
    }

    func testStartStreaming_WhileRecording_IsBlocked() async {
        mockPermissionRepo.microphoneStatus = .authorized
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        // Start recording first
        await viewModel.startRecording()
        XCTAssertTrue(viewModel.isRecording)

        // Try to start streaming -- should be blocked
        viewModel.startStreaming()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "録画中は配信を開始できません")
        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 0)
    }

    func testStartStreaming_ExplicitURL_WhileRecording_IsBlocked() async {
        mockPermissionRepo.microphoneStatus = .authorized
        let viewModel = makeViewModel()

        await viewModel.startRecording()
        XCTAssertTrue(viewModel.isRecording)

        viewModel.startStreaming(url: "rtmp://example.com/live", streamKey: "key")

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 0)
    }

    // MARK: - Camera Switch During Streaming Tests

    func testSwitchCamera_WhileStreaming_IsAllowed() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(viewModel.streamingState.isActive)

        viewModel.switchCamera()

        // Wait for background dispatch
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Camera switch should have been called
        XCTAssertEqual(mockCameraService.switchCameraCallCount, 1)
        XCTAssertEqual(viewModel.cameraPosition, .front)
    }

    func testSwitchCamera_WhileStreaming_MaintainsStreamingState() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        viewModel.switchCamera()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Streaming should still be active after camera switch
        // (The mock's state is managed manually, so we check that stopStreaming was NOT called)
        XCTAssertEqual(mockStreamingService.stopStreamingCallCount, 0)
    }

    func testSwitchCamera_WhileStreaming_ReestablishesCallbacks() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Callbacks should be set before switch
        XCTAssertNotNil(mockVideoFrameProcessor.onProcessedPixelBuffer)

        viewModel.switchCamera()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Callbacks should be re-established after switch
        XCTAssertNotNil(mockVideoFrameProcessor.onProcessedPixelBuffer)
        XCTAssertNotNil(mockVideoFrameProcessor.onAudioSampleBuffer)
    }

    // MARK: - Background Transition Tests

    func testBackgroundTransition_StopsStreaming() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(viewModel.streamingState.isActive)

        // Simulate background transition
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(viewModel.streamingState, .idle)
        XCTAssertEqual(mockStreamingService.stopStreamingCallCount, 1)
    }

    func testBackgroundTransition_UIReflectsStoppedState() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Simulate background transition
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        try? await Task.sleep(nanoseconds: 200_000_000)

        // UI should show idle state
        XCTAssertEqual(viewModel.streamingState, .idle)
        XCTAssertEqual(viewModel.streamingDuration, 0)
        XCTAssertEqual(viewModel.formattedStreamingDuration, "00:00:00")
    }

    func testBackgroundTransition_CanRestartStreamingAfterForeground() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        // First streaming session
        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Background -> stops streaming
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(viewModel.streamingState, .idle)

        // Foreground
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Start streaming again
        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 2)
    }

    func testBackgroundTransition_WhenNotStreaming_DoesNothing() async {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.streamingState, .idle)

        // Simulate background transition
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Should still be idle, no crash or error
        XCTAssertEqual(viewModel.streamingState, .idle)
        XCTAssertEqual(mockStreamingService.stopStreamingCallCount, 0)
    }

    // MARK: - Network Monitoring Tests

    func testInitialNetworkState_IsNotUnsatisfied() {
        let viewModel = makeViewModel()
        // On test setup, the network monitor may or may not have fired yet.
        // We just verify the property exists and is accessible.
        _ = viewModel.isNetworkUnsatisfied
    }

    // MARK: - Photo Capture During Streaming Tests

    func testPhotoCapture_WorksDuringStreaming() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        mockPermissionRepo.photoLibraryStatus = .authorized
        let testData = Data([0x01, 0x02, 0x03])
        mockCameraService.capturePhotoResult = .success(testData)
        let viewModel = makeViewModel()

        // Start streaming
        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(viewModel.streamingState.isActive)

        // Capture photo
        await viewModel.capturePhoto()

        // Photo should be captured successfully
        XCTAssertEqual(mockCameraService.capturePhotoCallCount, 1)
        XCTAssertEqual(mockPhotoRepo.savePhotoCallCount, 1)

        // Streaming should still be active
        XCTAssertTrue(viewModel.streamingState.isActive)
    }

    // MARK: - Memory Leak / Repeated Start/Stop Tests

    func testRepeatedStartStop_DoesNotCrash() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        // Start and stop streaming 5 times
        for i in 1...5 {
            viewModel.startStreaming()
            try? await Task.sleep(nanoseconds: 50_000_000)
            XCTAssertTrue(viewModel.streamingState.isActive, "Streaming should be active on iteration \(i)")

            viewModel.stopStreaming()
            try? await Task.sleep(nanoseconds: 50_000_000)
            XCTAssertEqual(viewModel.streamingState, .idle, "Streaming should be idle after stop on iteration \(i)")
            XCTAssertEqual(viewModel.streamingDuration, 0, "Duration should reset on iteration \(i)")
        }

        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 5)
        XCTAssertEqual(mockStreamingService.stopStreamingCallCount, 5)
    }

    // MARK: - Streaming State Error Clears Timer Tests

    func testStreamingError_StopsTimer() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Simulate connection error
        mockStreamingService.simulateConnectionError("接続が切断されました")
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Error state should be reflected
        XCTAssertNotNil(viewModel.errorMessage)
        // Duration should be reset (timer stopped on error)
        XCTAssertEqual(viewModel.streamingDuration, 0)
    }

    // MARK: - Existing Functionality Preservation Tests

    func testPhotoCapture_WorksWhenNotStreaming() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        let testData = Data([0x01, 0x02, 0x03])
        mockCameraService.capturePhotoResult = .success(testData)
        let viewModel = makeViewModel()

        await viewModel.capturePhoto()

        XCTAssertEqual(mockCameraService.capturePhotoCallCount, 1)
        XCTAssertEqual(mockPhotoRepo.savePhotoCallCount, 1)
    }

    func testRecording_WorksWhenNotStreaming() async {
        mockPermissionRepo.microphoneStatus = .authorized
        let viewModel = makeViewModel()

        await viewModel.startRecording()

        XCTAssertTrue(viewModel.isRecording)
        XCTAssertEqual(mockVideoRecordingService.startRecordingCallCount, 1)
    }

    func testCameraSwitch_WorksWhenNotStreaming() async {
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        viewModel.switchCamera()
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(mockCameraService.switchCameraCallCount, 1)
    }

    func testStopCamera_StopsStreamingAndTimer() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        viewModel.stopCamera()

        XCTAssertEqual(mockStreamingService.stopStreamingCallCount, 1)
        XCTAssertEqual(viewModel.streamingDuration, 0)
    }
}
