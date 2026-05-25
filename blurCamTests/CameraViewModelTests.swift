import XCTest
@testable import blurCam

@MainActor
final class CameraViewModelTests: XCTestCase {

    private var mockCameraService: MockCameraService!
    private var mockPhotoRepo: MockPhotoRepository!
    private var mockPermissionRepo: MockPermissionRepository!
    private var mockFaceRepo: MockFaceRepository!
    private var mockVideoFrameProcessor: MockVideoFrameProcessor!
    private var mockVideoRecordingService: MockVideoRecordingService!

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

    private var mockStreamingService: MockStreamingService!
    private var mockStreamingSettingsRepo: MockStreamingSettingsRepository!

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

    // MARK: - Camera Setup Tests

    func testSetupCamera_Success() {
        let viewModel = makeViewModel()

        viewModel.setupCamera()

        XCTAssertTrue(viewModel.isCameraConfigured)
        XCTAssertEqual(mockCameraService.configureCallCount, 1)
        XCTAssertEqual(mockCameraService.startCallCount, 1)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSetupCamera_Failure() {
        mockCameraService.configureError = CameraServiceError.cameraUnavailable
        let viewModel = makeViewModel()

        viewModel.setupCamera()

        XCTAssertFalse(viewModel.isCameraConfigured)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(mockCameraService.configureCallCount, 1)
        XCTAssertEqual(mockCameraService.startCallCount, 0)
    }

    func testSetupCamera_DoesNotReconfigureIfAlreadyConfigured() {
        let viewModel = makeViewModel()

        viewModel.setupCamera()
        viewModel.setupCamera()

        XCTAssertEqual(mockCameraService.configureCallCount, 1)
    }

    func testSetupCamera_StartsVideoFrameProcessing() {
        let viewModel = makeViewModel()

        viewModel.setupCamera()

        XCTAssertEqual(mockVideoFrameProcessor.startProcessingCallCount, 1)
    }

    func testSetupCamera_LoadsRegisteredFaceData() {
        let faceImageData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // Fake JPEG header
        let registration = FaceRegistration(imageFileName: "test.jpg")
        mockFaceRepo.registration = registration
        mockFaceRepo.registrations = [registration]
        mockFaceRepo.hasRegisteredFace = true
        mockFaceRepo.faceImageData = faceImageData
        mockFaceRepo.faceImageDataMap[registration.id] = faceImageData

        let viewModel = makeViewModel()
        viewModel.setupCamera()

        XCTAssertEqual(mockVideoFrameProcessor.loadRegisteredFacesCallCount, 1)
        XCTAssertEqual(mockVideoFrameProcessor.loadRegisteredFacesDataArrays.first?.first, faceImageData)
    }

    func testSetupCamera_NoRegisteredFace_DoesNotLoadFaceData() {
        mockFaceRepo.hasRegisteredFace = false
        mockFaceRepo.registration = nil
        mockFaceRepo.registrations = []

        let viewModel = makeViewModel()
        viewModel.setupCamera()

        XCTAssertEqual(mockVideoFrameProcessor.loadRegisteredFacesCallCount, 0)
    }

    func testSetupCamera_UpdatesHasFlash() {
        mockCameraService.hasFlash = true
        let viewModel = makeViewModel()

        viewModel.setupCamera()

        XCTAssertTrue(viewModel.hasFlash)
    }

    func testSetupCamera_LoadsLatestMedia() async {
        let testItem = MediaItem(
            id: "test-id",
            mediaType: .photo,
            thumbnail: nil,
            videoURL: nil,
            fullImage: nil
        )
        mockPhotoRepo.latestMediaItem = testItem
        let viewModel = makeViewModel()

        viewModel.setupCamera()

        // Wait for async media loading
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(mockPhotoRepo.fetchLatestMediaCallCount, 1)
    }

    // MARK: - Camera Start/Stop Tests

    func testStartCamera_WhenConfigured() {
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        // Reset counts after setup
        mockCameraService.startCallCount = 0
        // Reset isRunning so startCamera's guard doesn't block
        mockCameraService.isRunning = false

        viewModel.startCamera()

        XCTAssertEqual(mockCameraService.startCallCount, 1)
    }

    func testStartCamera_WhenNotConfigured_DoesNothing() {
        let viewModel = makeViewModel()

        viewModel.startCamera()

        XCTAssertEqual(mockCameraService.startCallCount, 0)
    }

    func testStopCamera() {
        let viewModel = makeViewModel()

        viewModel.stopCamera()

        XCTAssertEqual(mockCameraService.stopCallCount, 1)
        XCTAssertEqual(mockVideoFrameProcessor.stopProcessingCallCount, 1)
    }

    // MARK: - Photo Capture Tests

    func testCapturePhoto_Success() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        let testData = Data([0x01, 0x02, 0x03])
        mockCameraService.capturePhotoResult = .success(testData)
        let viewModel = makeViewModel()

        await viewModel.capturePhoto()

        // Wait a bit for state to transition to captured then idle
        XCTAssertEqual(mockCameraService.capturePhotoCallCount, 1)
        XCTAssertEqual(mockPhotoRepo.savePhotoCallCount, 1)
    }

    func testCapturePhoto_ProcessesImageWithBlur() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        let testData = Data([0x01, 0x02, 0x03])
        let processedData = Data([0x04, 0x05, 0x06])
        mockCameraService.capturePhotoResult = .success(testData)
        mockVideoFrameProcessor.processStillImageResult = processedData
        let viewModel = makeViewModel()

        await viewModel.capturePhoto()

        XCTAssertEqual(mockVideoFrameProcessor.processStillImageCallCount, 1)
        XCTAssertEqual(mockVideoFrameProcessor.processStillImageInputData.first, testData)
        // The processed data should be saved
        XCTAssertEqual(mockPhotoRepo.savedPhotoData.first, processedData)
    }

    func testCapturePhoto_FallsBackToOriginalData_WhenProcessingFails() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        let testData = Data([0x01, 0x02, 0x03])
        mockCameraService.capturePhotoResult = .success(testData)
        mockVideoFrameProcessor.processStillImageResult = nil
        let viewModel = makeViewModel()

        await viewModel.capturePhoto()

        XCTAssertEqual(mockVideoFrameProcessor.processStillImageCallCount, 1)
        // Should fall back to original data
        XCTAssertEqual(mockPhotoRepo.savedPhotoData.first, testData)
    }

    func testCapturePhoto_CameraServiceFailure() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockCameraService.capturePhotoResult = .failure(CameraServiceError.captureFailed("テストエラー"))
        let viewModel = makeViewModel()

        await viewModel.capturePhoto()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(mockPhotoRepo.savePhotoCallCount, 0)
    }

    func testCapturePhoto_PhotoRepoFailure() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockCameraService.capturePhotoResult = .success(Data([0x01]))
        mockPhotoRepo.savePhotoError = PhotoRepositoryError.saveFailed("テストエラー")
        let viewModel = makeViewModel()

        await viewModel.capturePhoto()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(mockCameraService.capturePhotoCallCount, 1)
        XCTAssertEqual(mockPhotoRepo.savePhotoCallCount, 1)
    }

    func testCapturePhoto_LoadsLatestMediaAfterCapture() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockCameraService.capturePhotoResult = .success(Data([0x01]))
        let viewModel = makeViewModel()

        await viewModel.capturePhoto()

        // Wait for async media loading
        try? await Task.sleep(nanoseconds: 200_000_000)

        // fetchLatestMedia should have been called (at least once for post-capture update)
        XCTAssertGreaterThanOrEqual(mockPhotoRepo.fetchLatestMediaCallCount, 1)
    }

    // MARK: - Photo Library Permission Tests During Capture

    func testCapturePhoto_RequestsPermissionWhenNotDetermined() async {
        mockPermissionRepo.photoLibraryStatus = .notDetermined
        mockPermissionRepo.photoLibraryRequestResult = .authorized
        mockCameraService.capturePhotoResult = .success(Data([0x01]))
        let viewModel = makeViewModel()

        await viewModel.capturePhoto()

        XCTAssertEqual(mockPermissionRepo.requestPhotoLibraryPermissionCallCount, 1)
        XCTAssertEqual(mockCameraService.capturePhotoCallCount, 1)
    }

    func testCapturePhoto_FailsWhenPhotoLibraryPermissionDenied() async {
        mockPermissionRepo.photoLibraryStatus = .denied
        let viewModel = makeViewModel()

        await viewModel.capturePhoto()

        XCTAssertEqual(mockCameraService.capturePhotoCallCount, 0)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testCapturePhoto_FailsWhenPhotoLibraryPermissionRequestDenied() async {
        mockPermissionRepo.photoLibraryStatus = .notDetermined
        mockPermissionRepo.photoLibraryRequestResult = .denied
        let viewModel = makeViewModel()

        await viewModel.capturePhoto()

        XCTAssertEqual(mockPermissionRepo.requestPhotoLibraryPermissionCallCount, 1)
        XCTAssertEqual(mockCameraService.capturePhotoCallCount, 0)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Capture State Tests

    func testInitialCaptureState_IsIdle() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.captureState, .idle)
    }

    // MARK: - CaptureSession Accessor

    func testCaptureSession_ReturnsServiceSession() {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.captureSession === mockCameraService.captureSession)
    }

    // MARK: - Detected Faces Tests

    func testInitialDetectedFaces_IsEmpty() {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.detectedFaces.isEmpty)
    }

    func testFramePublisher_Exists() {
        let viewModel = makeViewModel()

        XCTAssertNotNil(viewModel.framePublisher)
    }

    // MARK: - Camera Mode Tests

    func testInitialCameraMode_IsPhoto() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.cameraMode, .photo)
    }

    func testCameraMode_CanBeSwitchedToVideo() {
        let viewModel = makeViewModel()

        viewModel.cameraMode = .video

        XCTAssertEqual(viewModel.cameraMode, .video)
    }

    func testCameraMode_CanBeSwitchedBackToPhoto() {
        let viewModel = makeViewModel()

        viewModel.cameraMode = .video
        viewModel.cameraMode = .photo

        XCTAssertEqual(viewModel.cameraMode, .photo)
    }

    // MARK: - Video Recording Tests

    func testStartRecording_Success() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockPermissionRepo.microphoneStatus = .authorized
        let viewModel = makeViewModel()

        await viewModel.startRecording()

        XCTAssertEqual(viewModel.captureState, .recording)
        XCTAssertTrue(viewModel.isRecording)
        XCTAssertEqual(mockVideoRecordingService.startRecordingCallCount, 1)
        XCTAssertEqual(mockVideoRecordingService.startRecordingIncludeAudio, true)
    }

    func testStartRecording_WithoutMicPermission_RecordsWithoutAudio() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockPermissionRepo.microphoneStatus = .denied
        let viewModel = makeViewModel()

        await viewModel.startRecording()

        XCTAssertEqual(viewModel.captureState, .recording)
        XCTAssertEqual(mockVideoRecordingService.startRecordingCallCount, 1)
        XCTAssertEqual(mockVideoRecordingService.startRecordingIncludeAudio, false)
    }

    func testStartRecording_MicNotDetermined_RecordsWithoutAudio() async {
        // Audio is pre-configured at setupCamera time. If mic status is notDetermined,
        // startRecording simply records without audio (no runtime permission request).
        mockPermissionRepo.microphoneStatus = .notDetermined
        let viewModel = makeViewModel()

        await viewModel.startRecording()

        XCTAssertEqual(viewModel.captureState, .recording)
        XCTAssertEqual(mockVideoRecordingService.startRecordingIncludeAudio, false)
    }

    func testStartRecording_MicDenied_RecordsWithoutAudio() async {
        // When mic is denied, recording proceeds without audio
        mockPermissionRepo.microphoneStatus = .denied
        let viewModel = makeViewModel()

        await viewModel.startRecording()

        XCTAssertEqual(viewModel.captureState, .recording)
        XCTAssertEqual(mockVideoRecordingService.startRecordingIncludeAudio, false)
    }

    func testStartRecording_NoPhotoLibraryCheck_ProceedsDirectly() async {
        // Current startRecording does not check photo library permission
        mockPermissionRepo.photoLibraryStatus = .denied
        let viewModel = makeViewModel()

        await viewModel.startRecording()

        // Recording starts regardless of photo library status
        XCTAssertEqual(viewModel.captureState, .recording)
        XCTAssertEqual(mockVideoRecordingService.startRecordingCallCount, 1)
    }

    func testStartRecording_FailsWhenServiceThrows() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockPermissionRepo.microphoneStatus = .authorized
        mockVideoRecordingService.startRecordingError = VideoRecordingError.writerSetupFailed("テストエラー")
        let viewModel = makeViewModel()

        await viewModel.startRecording()

        XCTAssertNotEqual(viewModel.captureState, .recording)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testStartRecording_DoesNotStartWhenAlreadyCapturing() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        let viewModel = makeViewModel()

        // First start a recording
        await viewModel.startRecording()
        XCTAssertEqual(viewModel.captureState, .recording)

        // Try to start again - should not double-start
        await viewModel.startRecording()
        XCTAssertEqual(mockVideoRecordingService.startRecordingCallCount, 1)
    }

    func testStopRecording_Success() async {
        mockPermissionRepo.microphoneStatus = .denied
        let viewModel = makeViewModel()

        await viewModel.startRecording()
        XCTAssertEqual(viewModel.captureState, .recording)

        await viewModel.stopRecording()

        // stopRecording uses Task.detached internally, wait for it to complete
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(mockVideoRecordingService.stopRecordingCallCount, 1)
        XCTAssertEqual(mockPhotoRepo.saveVideoCallCount, 1)
    }

    func testStopRecording_ServiceFailure() async {
        mockPermissionRepo.microphoneStatus = .denied
        mockVideoRecordingService.stopRecordingError = VideoRecordingError.writingFailed("テストエラー")
        let viewModel = makeViewModel()

        await viewModel.startRecording()
        await viewModel.stopRecording()

        // stopRecording uses Task.detached internally, wait for it to complete
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testStopRecording_DoesNothingWhenNotRecording() async {
        let viewModel = makeViewModel()

        await viewModel.stopRecording()

        XCTAssertEqual(mockVideoRecordingService.stopRecordingCallCount, 0)
    }

    func testStopRecording_KeepsAudioPreConfigured() async {
        // Audio is pre-configured at setupCamera time and stays configured after stop.
        // stopRecording does NOT call stopAudioCapture.
        mockPermissionRepo.microphoneStatus = .authorized
        let viewModel = makeViewModel()

        await viewModel.startRecording()
        await viewModel.stopRecording()

        // Audio capture is not stopped - it stays pre-configured for next recording
        XCTAssertEqual(mockVideoFrameProcessor.stopAudioCaptureCallCount, 0)
    }

    func testStopRecording_DisablesTorchAfterRecording() async {
        mockPermissionRepo.microphoneStatus = .denied
        let viewModel = makeViewModel()

        await viewModel.startRecording()
        await viewModel.stopRecording()

        XCTAssertEqual(mockCameraService.disableTorchCallCount, 1)
    }

    // MARK: - Recording Duration Tests

    func testInitialRecordingDuration_IsZero() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.recordingDuration, 0)
    }

    func testFormattedRecordingDuration_ZeroSeconds() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.formattedRecordingDuration, "00:00")
    }

    // MARK: - HandleShutterAction Tests

    func testHandleShutterAction_PhotoMode_CapturesPhoto() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockCameraService.capturePhotoResult = .success(Data([0x01]))
        let viewModel = makeViewModel()
        viewModel.cameraMode = .photo

        viewModel.handleShutterAction()

        // Allow async work to complete
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockCameraService.capturePhotoCallCount, 1)
    }

    func testHandleShutterAction_VideoMode_StartsRecording() async {
        mockPermissionRepo.microphoneStatus = .denied
        let viewModel = makeViewModel()
        viewModel.cameraMode = .video

        viewModel.handleShutterAction()

        // startRecording has a 0.35s Task.sleep for sound, need to wait longer
        try? await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertEqual(mockVideoRecordingService.startRecordingCallCount, 1)
    }

    func testHandleShutterAction_VideoMode_WhileRecording_StopsRecording() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockPermissionRepo.microphoneStatus = .denied
        let viewModel = makeViewModel()
        viewModel.cameraMode = .video

        await viewModel.startRecording()
        XCTAssertTrue(viewModel.isRecording)

        viewModel.handleShutterAction()

        // Allow async work to complete
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockVideoRecordingService.stopRecordingCallCount, 1)
    }

    // MARK: - Audio Capture Integration Tests

    func testSetupCamera_WithAudioPermission_PreConfiguresAudioCapture() {
        // Audio is now pre-configured during setupCamera when mic is authorized
        mockPermissionRepo.microphoneStatus = .authorized
        let viewModel = makeViewModel()

        viewModel.setupCamera()

        XCTAssertEqual(mockVideoFrameProcessor.startAudioCaptureCallCount, 1)
    }

    func testSetupCamera_WithoutAudioPermission_DoesNotPreConfigureAudioCapture() {
        // When mic is denied, audio capture is not pre-configured
        mockPermissionRepo.microphoneStatus = .denied
        let viewModel = makeViewModel()

        viewModel.setupCamera()

        XCTAssertEqual(mockVideoFrameProcessor.startAudioCaptureCallCount, 0)
    }

    // MARK: - isRecording Tests

    func testIsRecording_FalseWhenIdle() {
        let viewModel = makeViewModel()

        XCTAssertFalse(viewModel.isRecording)
    }

    func testIsRecording_TrueWhenRecording() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockPermissionRepo.microphoneStatus = .denied
        let viewModel = makeViewModel()

        await viewModel.startRecording()

        XCTAssertTrue(viewModel.isRecording)
    }

    // MARK: - Video Dimensions Tests

    func testStartRecording_UsesFrameProcessorDimensions() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockPermissionRepo.microphoneStatus = .denied
        mockVideoFrameProcessor.videoWidth = 1280
        mockVideoFrameProcessor.videoHeight = 720
        let viewModel = makeViewModel()

        await viewModel.startRecording()

        XCTAssertEqual(mockVideoRecordingService.startRecordingWidth, 1280)
        XCTAssertEqual(mockVideoRecordingService.startRecordingHeight, 720)
    }

    func testStartRecording_FallsBackToDefaultDimensions() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockPermissionRepo.microphoneStatus = .denied
        mockVideoFrameProcessor.videoWidth = 0
        mockVideoFrameProcessor.videoHeight = 0
        let viewModel = makeViewModel()

        await viewModel.startRecording()

        XCTAssertEqual(mockVideoRecordingService.startRecordingWidth, 1920)
        XCTAssertEqual(mockVideoRecordingService.startRecordingHeight, 1080)
    }

    // MARK: - Camera Switch Tests

    func testSwitchCamera_Success() async {
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        XCTAssertEqual(viewModel.cameraPosition, .back)

        viewModel.switchCamera()

        // Wait for background dispatch + MainActor callback
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(mockCameraService.switchCameraCallCount, 1)
        XCTAssertEqual(viewModel.cameraPosition, .front)
    }

    func testSwitchCamera_TogglesTwice_BackToFrontToBack() async {
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        viewModel.switchCamera()

        // Wait for first switch to complete
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(viewModel.cameraPosition, .front)

        // Now isSwitchingCamera should be false, so second switch is allowed
        viewModel.switchCamera()

        // Wait for second switch to complete
        try? await Task.sleep(nanoseconds: 500_000_000)
        // The second call should toggle back
        XCTAssertEqual(viewModel.cameraPosition, .back)
    }

    func testSwitchCamera_StopsAndRestartsFrameProcessing() async {
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        let stopCountBefore = mockVideoFrameProcessor.stopProcessingCallCount
        let startCountBefore = mockVideoFrameProcessor.startProcessingCallCount

        viewModel.switchCamera()

        // Wait for background dispatch to complete
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(mockVideoFrameProcessor.stopProcessingCallCount, stopCountBefore + 1)
        XCTAssertEqual(mockVideoFrameProcessor.startProcessingCallCount, startCountBefore + 1)
    }

    func testSwitchCamera_ReloadsRegisteredFaceData() async {
        let faceImageData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let registration = FaceRegistration(imageFileName: "test.jpg")
        mockFaceRepo.registration = registration
        mockFaceRepo.registrations = [registration]
        mockFaceRepo.hasRegisteredFace = true
        mockFaceRepo.faceImageData = faceImageData
        mockFaceRepo.faceImageDataMap[registration.id] = faceImageData

        let viewModel = makeViewModel()
        viewModel.setupCamera()

        let loadCountBefore = mockVideoFrameProcessor.loadRegisteredFacesCallCount

        viewModel.switchCamera()

        // Wait for background dispatch + MainActor callback
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(mockVideoFrameProcessor.loadRegisteredFacesCallCount, loadCountBefore + 1)
    }

    func testSwitchCamera_NotConfigured_DoesNothing() {
        let viewModel = makeViewModel()

        viewModel.switchCamera()

        XCTAssertEqual(mockCameraService.switchCameraCallCount, 0)
    }

    func testSwitchCamera_WhileRecording_DoesNothing() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockPermissionRepo.microphoneStatus = .denied
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        await viewModel.startRecording()
        XCTAssertTrue(viewModel.isRecording)

        viewModel.switchCamera()

        XCTAssertEqual(mockCameraService.switchCameraCallCount, 0)
    }

    func testSwitchCamera_Failure_SetsErrorMessage() async {
        mockCameraService.switchCameraError = CameraServiceError.switchFailed("テストエラー")
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        viewModel.switchCamera()

        // Wait for background dispatch + MainActor error callback
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testSwitchCamera_UpdatesHasFlash() async {
        let viewModel = makeViewModel()
        viewModel.setupCamera()
        XCTAssertTrue(viewModel.hasFlash) // back camera has flash

        // Simulate front camera not having flash
        mockCameraService.hasFlash = false

        viewModel.switchCamera()

        // Wait for background dispatch + MainActor callback
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertFalse(viewModel.hasFlash)
    }

    func testSwitchCamera_ResetsFlashMode_WhenNoFlash() async {
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        // Set flash to on
        viewModel.toggleFlashMode() // off -> auto
        viewModel.toggleFlashMode() // auto -> on
        XCTAssertEqual(viewModel.flashMode, .on)

        // Switch to front camera with no flash
        mockCameraService.hasFlash = false
        viewModel.switchCamera()

        // Wait for background dispatch + MainActor callback
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(viewModel.flashMode, .off)
    }

    func testSwitchCamera_SetsSwitchingState() async {
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        viewModel.switchCamera()

        XCTAssertTrue(viewModel.isSwitchingCamera)

        // Wait for the switching animation to finish
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertFalse(viewModel.isSwitchingCamera)
    }

    // MARK: - Flash Control Tests

    func testInitialFlashMode_IsOff() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.flashMode, .off)
    }

    func testToggleFlashMode_OffToAuto() {
        let viewModel = makeViewModel()

        viewModel.toggleFlashMode()

        XCTAssertEqual(viewModel.flashMode, .auto)
        XCTAssertEqual(mockCameraService.flashMode, .auto)
    }

    func testToggleFlashMode_AutoToOn() {
        let viewModel = makeViewModel()

        viewModel.toggleFlashMode() // off -> auto
        viewModel.toggleFlashMode() // auto -> on

        XCTAssertEqual(viewModel.flashMode, .on)
        XCTAssertEqual(mockCameraService.flashMode, .on)
    }

    func testToggleFlashMode_OnToOff() {
        let viewModel = makeViewModel()

        viewModel.toggleFlashMode() // off -> auto
        viewModel.toggleFlashMode() // auto -> on
        viewModel.toggleFlashMode() // on -> off

        XCTAssertEqual(viewModel.flashMode, .off)
        XCTAssertEqual(mockCameraService.flashMode, .off)
    }

    func testToggleFlashMode_FullCycle() {
        let viewModel = makeViewModel()

        viewModel.toggleFlashMode()
        XCTAssertEqual(viewModel.flashMode, .auto)

        viewModel.toggleFlashMode()
        XCTAssertEqual(viewModel.flashMode, .on)

        viewModel.toggleFlashMode()
        XCTAssertEqual(viewModel.flashMode, .off)
    }

    func testToggleFlashMode_SyncsWithCameraService() {
        let viewModel = makeViewModel()

        viewModel.toggleFlashMode()
        XCTAssertEqual(mockCameraService.flashMode, .auto)

        viewModel.toggleFlashMode()
        XCTAssertEqual(mockCameraService.flashMode, .on)

        viewModel.toggleFlashMode()
        XCTAssertEqual(mockCameraService.flashMode, .off)
    }

    // MARK: - Flash + Recording Tests

    func testStartRecording_WithFlashOn_EnablesTorch() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockPermissionRepo.microphoneStatus = .denied
        let viewModel = makeViewModel()

        // Set flash to on
        viewModel.toggleFlashMode() // off -> auto
        viewModel.toggleFlashMode() // auto -> on

        await viewModel.startRecording()

        XCTAssertEqual(mockCameraService.enableTorchCallCount, 1)
    }

    func testStartRecording_WithFlashOff_DoesNotEnableTorch() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockPermissionRepo.microphoneStatus = .denied
        let viewModel = makeViewModel()

        // Flash is off by default
        await viewModel.startRecording()

        XCTAssertEqual(mockCameraService.enableTorchCallCount, 0)
    }

    func testStartRecording_WithFlashAuto_DoesNotEnableTorch() async {
        mockPermissionRepo.photoLibraryStatus = .authorized
        mockPermissionRepo.microphoneStatus = .denied
        let viewModel = makeViewModel()

        viewModel.toggleFlashMode() // off -> auto

        await viewModel.startRecording()

        XCTAssertEqual(mockCameraService.enableTorchCallCount, 0)
    }

    // MARK: - Media Preview Tests

    func testInitialLatestMediaItem_IsNil() {
        let viewModel = makeViewModel()

        XCTAssertNil(viewModel.latestMediaItem)
    }

    func testShowMediaPreview_InitiallyFalse() {
        let viewModel = makeViewModel()

        XCTAssertFalse(viewModel.showMediaPreview)
    }

    func testLoadLatestMedia_FetchesFromRepository() async {
        let testItem = MediaItem(
            id: "test-id",
            mediaType: .photo,
            thumbnail: nil,
            videoURL: nil,
            fullImage: nil
        )
        mockPhotoRepo.latestMediaItem = testItem
        let viewModel = makeViewModel()

        viewModel.loadLatestMedia()

        // Wait for async
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(viewModel.latestMediaItem, testItem)
        XCTAssertEqual(mockPhotoRepo.fetchLatestMediaCallCount, 1)
    }

    func testLoadLatestMedia_WhenRepositoryReturnsNil() async {
        mockPhotoRepo.latestMediaItem = nil
        let viewModel = makeViewModel()

        viewModel.loadLatestMedia()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertNil(viewModel.latestMediaItem)
    }

    // MARK: - Camera Position Tests

    func testInitialCameraPosition_IsBack() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.cameraPosition, .back)
    }

    func testInitialHasFlash_MatchesCameraService() {
        mockCameraService.hasFlash = false
        let viewModel = makeViewModel()

        // Before setup, hasFlash defaults to false
        XCTAssertFalse(viewModel.hasFlash)
    }

    // MARK: - Initial Switching State Tests

    func testInitialSwitchingCamera_IsFalse() {
        let viewModel = makeViewModel()

        XCTAssertFalse(viewModel.isSwitchingCamera)
    }
}
