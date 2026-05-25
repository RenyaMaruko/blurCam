import XCTest
@testable import blurCam

@MainActor
final class CameraViewModelStreamingTests: XCTestCase {

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

    // MARK: - Initial State Tests

    func testInitialStreamingState_IsIdle() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.streamingState, .idle)
    }

    func testIsStreaming_FalseInitially() {
        let viewModel = makeViewModel()
        XCTAssertFalse(viewModel.isStreaming)
    }

    // MARK: - Start Streaming Tests

    func testStartStreaming_Success() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "test-key"
        let viewModel = makeViewModel()

        viewModel.startStreaming()

        // Wait for state callback
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 1)
        XCTAssertEqual(mockStreamingService.startStreamingURL, "rtmp://live.example.com/app")
        XCTAssertEqual(mockStreamingService.startStreamingStreamKey, "test-key")
    }

    func testStartStreaming_UsesVideoProcessorDimensions() {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        mockVideoFrameProcessor.videoWidth = 1280
        mockVideoFrameProcessor.videoHeight = 720
        let viewModel = makeViewModel()

        viewModel.startStreaming()

        XCTAssertEqual(mockStreamingService.startStreamingWidth, 1280)
        XCTAssertEqual(mockStreamingService.startStreamingHeight, 720)
    }

    func testStartStreaming_FallsBackToDefaultDimensions() {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        mockVideoFrameProcessor.videoWidth = 0
        mockVideoFrameProcessor.videoHeight = 0
        let viewModel = makeViewModel()

        viewModel.startStreaming()

        XCTAssertEqual(mockStreamingService.startStreamingWidth, 1920)
        XCTAssertEqual(mockStreamingService.startStreamingHeight, 1080)
    }

    func testStartStreaming_WithExplicitURLAndKey() {
        let viewModel = makeViewModel()

        viewModel.startStreaming(url: "rtmp://explicit.com/live", streamKey: "explicit-key")

        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 1)
        XCTAssertEqual(mockStreamingService.startStreamingURL, "rtmp://explicit.com/live")
        XCTAssertEqual(mockStreamingService.startStreamingStreamKey, "explicit-key")
    }

    // MARK: - Error Handling Tests

    func testStartStreaming_MissingURL_ShowsError() {
        mockStreamingSettingsRepo.rtmpURL = nil
        let viewModel = makeViewModel()

        viewModel.startStreaming()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 0)
    }

    func testStartStreaming_EmptyURL_ShowsError() {
        mockStreamingSettingsRepo.rtmpURL = ""
        let viewModel = makeViewModel()

        viewModel.startStreaming()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 0)
    }

    func testStartStreaming_ServiceThrows_ShowsError() {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        mockStreamingService.startStreamingError = StreamingError.connectionFailed("テストエラー")
        let viewModel = makeViewModel()

        viewModel.startStreaming()

        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testStartStreaming_ConnectionError_UpdatesState() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        mockStreamingService.simulateSuccessfulConnection = true
        let viewModel = makeViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Simulate connection drop
        mockStreamingService.simulateConnectionError("接続が切断されました")
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Stop Streaming Tests

    func testStopStreaming() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        viewModel.stopStreaming()

        XCTAssertEqual(mockStreamingService.stopStreamingCallCount, 1)
        XCTAssertEqual(viewModel.streamingState, .idle)
    }

    func testStopStreaming_ClearsCallbacks() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Callbacks should be set
        XCTAssertNotNil(mockVideoFrameProcessor.onProcessedPixelBuffer)
        XCTAssertNotNil(mockVideoFrameProcessor.onAudioSampleBuffer)

        viewModel.stopStreaming()

        // Callbacks should be cleared
        XCTAssertNil(mockVideoFrameProcessor.onProcessedPixelBuffer)
        XCTAssertNil(mockVideoFrameProcessor.onAudioSampleBuffer)
    }

    // MARK: - Restart Streaming Tests

    func testRestartStreaming_AfterStop() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        // First stream
        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)
        viewModel.stopStreaming()

        // Second stream
        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 2)
        XCTAssertEqual(mockStreamingService.stopStreamingCallCount, 1)
    }

    // MARK: - Mutual Exclusion Tests (Streaming vs Recording)

    func testStartStreaming_WhileRecording_ShowsError() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockPermissionRepo.microphoneStatus = .authorized
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        // Start recording first
        await viewModel.startRecording()
        XCTAssertTrue(viewModel.isRecording)

        // Try to start streaming
        viewModel.startStreaming()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 0)
    }

    func testStartRecording_WhileStreaming_DoesNotStart() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockPermissionRepo.microphoneStatus = .authorized
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        // Start streaming first
        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Try to start recording
        await viewModel.startRecording()

        XCTAssertEqual(mockVideoRecordingService.startRecordingCallCount, 0)
        XCTAssertFalse(viewModel.isRecording)
    }

    // MARK: - Camera Switch While Streaming Tests

    func testSwitchCamera_WhileStreaming_IsAllowed() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        viewModel.switchCamera()

        // Wait for background dispatch + MainActor callback
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Camera switch should be allowed during streaming (Sprint 9)
        XCTAssertEqual(mockCameraService.switchCameraCallCount, 1)
    }

    // MARK: - Streaming Callbacks Tests

    func testStartStreaming_SetsUpCallbacks() {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        viewModel.startStreaming()

        // Callbacks should be set for forwarding frames to streaming service
        XCTAssertNotNil(mockVideoFrameProcessor.onProcessedPixelBuffer)
        XCTAssertNotNil(mockVideoFrameProcessor.onAudioSampleBuffer)
    }

    // MARK: - Stop Camera While Streaming Tests

    func testStopCamera_StopsStreaming() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://live.example.com/app"
        mockStreamingSettingsRepo.streamKey = "key"
        let viewModel = makeViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        viewModel.stopCamera()

        XCTAssertEqual(mockStreamingService.stopStreamingCallCount, 1)
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
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockPermissionRepo.microphoneStatus = .authorized
        let viewModel = makeViewModel()

        await viewModel.startRecording()

        XCTAssertTrue(viewModel.isRecording)
        XCTAssertEqual(mockVideoRecordingService.startRecordingCallCount, 1)
    }

    // MARK: - Destination-Based Streaming Tests

    func testStartStreaming_UsesSelectedDestination() async {
        let dest = StreamingDestination(
            name: "My YouTube",
            platform: .youTube,
            rtmpURL: "rtmp://a.rtmp.youtube.com/live2",
            streamKey: "dest-key-123"
        )
        mockStreamingSettingsRepo.destinations = [dest]
        mockStreamingSettingsRepo._selectedDestinationId = dest.id
        let viewModel = makeViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 1)
        XCTAssertEqual(mockStreamingService.startStreamingURL, "rtmp://a.rtmp.youtube.com/live2")
        XCTAssertEqual(mockStreamingService.startStreamingStreamKey, "dest-key-123")
    }

    func testStartStreaming_DestinationTakesPriorityOverLegacy() async {
        // Legacy settings
        mockStreamingSettingsRepo.rtmpURL = "rtmp://legacy.com/app"
        mockStreamingSettingsRepo.streamKey = "legacy-key"

        // Destination settings
        let dest = StreamingDestination(
            name: "Destination",
            platform: .twitch,
            rtmpURL: "rtmp://live.twitch.tv/app",
            streamKey: "dest-key"
        )
        mockStreamingSettingsRepo.destinations = [dest]
        mockStreamingSettingsRepo._selectedDestinationId = dest.id
        let viewModel = makeViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Should use destination, not legacy
        XCTAssertEqual(mockStreamingService.startStreamingURL, "rtmp://live.twitch.tv/app")
        XCTAssertEqual(mockStreamingService.startStreamingStreamKey, "dest-key")
    }

    func testStartStreaming_FallsBackToLegacy_WhenNoDestinationSelected() async {
        mockStreamingSettingsRepo.rtmpURL = "rtmp://legacy.com/app"
        mockStreamingSettingsRepo.streamKey = "legacy-key"
        // No destination selected
        let viewModel = makeViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockStreamingService.startStreamingURL, "rtmp://legacy.com/app")
        XCTAssertEqual(mockStreamingService.startStreamingStreamKey, "legacy-key")
    }

    func testStartStreaming_NoDestinationAndNoLegacy_ShowsError() {
        // Neither destination nor legacy settings
        let viewModel = makeViewModel()

        viewModel.startStreaming()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 0)
    }
}
