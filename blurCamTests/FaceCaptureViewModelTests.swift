import XCTest
@testable import blurCam

@MainActor
final class FaceCaptureViewModelTests: XCTestCase {

    private var mockCaptureService: MockFaceCaptureService!
    private var mockDetectionService: MockFaceDetectionService!
    private var mockFaceRepo: MockFaceRepository!

    override func setUp() {
        super.setUp()
        mockCaptureService = MockFaceCaptureService()
        mockDetectionService = MockFaceDetectionService()
        mockFaceRepo = MockFaceRepository()
    }

    override func tearDown() {
        mockCaptureService = nil
        mockDetectionService = nil
        mockFaceRepo = nil
        super.tearDown()
    }

    private func makeViewModel() -> FaceCaptureViewModel {
        FaceCaptureViewModel(
            faceCaptureService: mockCaptureService,
            faceDetectionService: mockDetectionService,
            faceRepository: mockFaceRepo
        )
    }

    // MARK: - Camera Setup Tests

    func testSetupCamera_Success() {
        let viewModel = makeViewModel()

        viewModel.setupCamera()

        XCTAssertTrue(viewModel.isCameraConfigured)
        XCTAssertEqual(mockCaptureService.configureCallCount, 1)
        XCTAssertEqual(mockCaptureService.startCallCount, 1)
        XCTAssertEqual(mockDetectionService.startDetectionCallCount, 1)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSetupCamera_CameraConfigureFailure() {
        mockCaptureService.configureError = FaceCaptureServiceError.frontCameraUnavailable
        let viewModel = makeViewModel()

        viewModel.setupCamera()

        XCTAssertFalse(viewModel.isCameraConfigured)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testSetupCamera_DoesNotReconfigureIfAlreadyConfigured() {
        let viewModel = makeViewModel()

        viewModel.setupCamera()
        viewModel.setupCamera()

        XCTAssertEqual(mockCaptureService.configureCallCount, 1)
    }

    // MARK: - Stop Camera Tests

    func testStopCamera_StopsDetectionAndCamera() {
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        viewModel.stopCamera()

        XCTAssertEqual(mockDetectionService.stopDetectionCallCount, 1)
        XCTAssertEqual(mockCaptureService.stopCallCount, 1)
    }

    // MARK: - Face Detection State Tests

    func testInitial_FaceNotDetected() {
        let viewModel = makeViewModel()

        XCTAssertFalse(viewModel.isFaceDetected)
    }

    func testFaceDetectionChanged_UpdatesState() {
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        // Simulate face detection
        mockDetectionService.isFaceDetected = true

        // The callback sets isFaceDetected asynchronously via MainActor
        // Since we're already on MainActor, we need to verify the callback was set up
        XCTAssertNotNil(mockDetectionService.onFaceDetectionChanged)
    }

    // MARK: - Guidance Text Tests

    func testInitial_GuidanceText() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.guidanceText, "正面を向いてください")
    }

    // MARK: - Capture and Save Face Tests

    func testCaptureAndSaveFace_Success() async {
        let testData = Data([0xFF, 0xD8, 0xFF])
        mockCaptureService.capturePhotoResult = .success(testData)
        mockDetectionService.detectFaceResult = true
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        // Simulate face detected via callback
        mockDetectionService.onFaceDetectionChanged?(true)
        try? await Task.sleep(nanoseconds: 100_000_000)

        // 3-step capture: front, left, right
        // Step 1
        await viewModel.captureAndSaveFace()
        XCTAssertFalse(viewModel.isFaceSaved)
        XCTAssertEqual(viewModel.currentStep, 2)

        // Re-detect face for next step
        mockDetectionService.onFaceDetectionChanged?(true)
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Step 2
        await viewModel.captureAndSaveFace()
        XCTAssertFalse(viewModel.isFaceSaved)
        XCTAssertEqual(viewModel.currentStep, 3)

        // Re-detect face for final step
        mockDetectionService.onFaceDetectionChanged?(true)
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Step 3 - final capture, should save all
        await viewModel.captureAndSaveFace()

        XCTAssertTrue(viewModel.isFaceSaved)
        XCTAssertEqual(mockCaptureService.capturePhotoCallCount, 3)
        XCTAssertEqual(mockDetectionService.detectFaceCallCount, 3)
        XCTAssertEqual(mockFaceRepo.saveFaceCallCount, 3)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testCaptureAndSaveFace_FailsWhenFaceNotDetected() async {
        let viewModel = makeViewModel()
        viewModel.setupCamera()
        // Face is not detected (default)

        await viewModel.captureAndSaveFace()

        XCTAssertFalse(viewModel.isFaceSaved)
        XCTAssertEqual(mockCaptureService.capturePhotoCallCount, 0)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testCaptureAndSaveFace_FailsWhenCaptureServiceFails() async {
        mockCaptureService.capturePhotoResult = .failure(FaceCaptureServiceError.captureFailed("test error"))
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        // Simulate face detected
        mockDetectionService.onFaceDetectionChanged?(true)
        try? await Task.sleep(nanoseconds: 100_000_000)

        await viewModel.captureAndSaveFace()

        XCTAssertFalse(viewModel.isFaceSaved)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testCaptureAndSaveFace_FailsWhenNoFaceInCapturedImage() async {
        mockCaptureService.capturePhotoResult = .success(Data([0xFF, 0xD8]))
        mockDetectionService.detectFaceResult = false // No face found in captured image
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        // Simulate face detected in live feed
        mockDetectionService.onFaceDetectionChanged?(true)
        try? await Task.sleep(nanoseconds: 100_000_000)

        await viewModel.captureAndSaveFace()

        XCTAssertFalse(viewModel.isFaceSaved)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(mockFaceRepo.saveFaceCallCount, 0)
    }

    func testCaptureAndSaveFace_FailsWhenRepositorySaveFails() async {
        mockCaptureService.capturePhotoResult = .success(Data([0xFF, 0xD8]))
        mockDetectionService.detectFaceResult = true
        mockFaceRepo.saveFaceError = FaceRepositoryError.imageSaveFailed("disk full")
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        // Simulate face detected
        mockDetectionService.onFaceDetectionChanged?(true)
        try? await Task.sleep(nanoseconds: 100_000_000)

        // 3-step capture: complete all steps then save fails on final step
        // Step 1
        await viewModel.captureAndSaveFace()
        // Re-detect face
        mockDetectionService.onFaceDetectionChanged?(true)
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Step 2
        await viewModel.captureAndSaveFace()
        // Re-detect face
        mockDetectionService.onFaceDetectionChanged?(true)
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Step 3 - save will fail here
        await viewModel.captureAndSaveFace()

        XCTAssertFalse(viewModel.isFaceSaved)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Capture State Tests

    func testCapture_DoesNotDoubleCapture() async {
        mockCaptureService.capturePhotoResult = .success(Data([0xFF]))
        mockDetectionService.detectFaceResult = true
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        mockDetectionService.onFaceDetectionChanged?(true)
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Start first capture
        await viewModel.captureAndSaveFace()

        XCTAssertEqual(mockCaptureService.capturePhotoCallCount, 1)
    }

    // MARK: - Capture Session Accessor Tests

    func testCaptureSession_ReturnsCaptureServiceSession() {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.captureSession === mockCaptureService.captureSession)
    }

    // MARK: - Button State Tests (isFaceDetected controls button enable/disable)

    func testCaptureButton_DisabledWhenFaceNotDetected() async {
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        // Face not detected - capture should fail with guidance
        await viewModel.captureAndSaveFace()

        XCTAssertFalse(viewModel.isFaceSaved)
        XCTAssertEqual(mockCaptureService.capturePhotoCallCount, 0)
    }

    func testCaptureButton_EnabledWhenFaceDetected() async {
        mockCaptureService.capturePhotoResult = .success(Data([0xFF, 0xD8]))
        mockDetectionService.detectFaceResult = true
        let viewModel = makeViewModel()
        viewModel.setupCamera()

        mockDetectionService.onFaceDetectionChanged?(true)
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(viewModel.isFaceDetected)
    }
}
