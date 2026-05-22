import XCTest
@testable import blurCam

@MainActor
final class CameraViewModelBlurTests: XCTestCase {

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
    }

    override func tearDown() {
        mockCameraService = nil
        mockPhotoRepo = nil
        mockPermissionRepo = nil
        mockFaceRepo = nil
        mockVideoFrameProcessor = nil
        mockVideoRecordingService = nil
        super.tearDown()
    }

    private func makeViewModel() -> CameraViewModel {
        CameraViewModel(
            cameraService: mockCameraService,
            photoRepository: mockPhotoRepo,
            permissionRepository: mockPermissionRepo,
            faceRepository: mockFaceRepo,
            videoFrameProcessor: mockVideoFrameProcessor,
            videoRecordingService: mockVideoRecordingService
        )
    }

    // MARK: - Blur Intensity Tests

    func testApplyBlurIntensity_SetsBlurRadius() {
        let viewModel = makeViewModel()

        viewModel.applyBlurIntensity(.low)
        XCTAssertEqual(mockVideoFrameProcessor.blurProcessingService.blurRadius, 15.0)

        viewModel.applyBlurIntensity(.medium)
        XCTAssertEqual(mockVideoFrameProcessor.blurProcessingService.blurRadius, 30.0)

        viewModel.applyBlurIntensity(.high)
        XCTAssertEqual(mockVideoFrameProcessor.blurProcessingService.blurRadius, 50.0)
    }

    // MARK: - Multiple Face Loading Tests

    func testSetupCamera_LoadsMultipleFaces() {
        let reg1 = FaceRegistration(imageFileName: "face1.jpg")
        let reg2 = FaceRegistration(imageFileName: "face2.jpg")
        let imageData1 = Data([0xFF, 0xD8, 0x01])
        let imageData2 = Data([0xFF, 0xD8, 0x02])

        mockFaceRepo.registrations = [reg1, reg2]
        mockFaceRepo.hasRegisteredFace = true
        mockFaceRepo.faceImageDataMap[reg1.id] = imageData1
        mockFaceRepo.faceImageDataMap[reg2.id] = imageData2

        let viewModel = makeViewModel()
        viewModel.setupCamera()

        XCTAssertEqual(mockVideoFrameProcessor.loadRegisteredFacesCallCount, 1)
        let loadedDataArray = mockVideoFrameProcessor.loadRegisteredFacesDataArrays.first
        XCTAssertEqual(loadedDataArray?.count, 2)
        XCTAssertTrue(loadedDataArray?.contains(imageData1) ?? false)
        XCTAssertTrue(loadedDataArray?.contains(imageData2) ?? false)
    }

    func testReloadRegisteredFaces_LoadsAllFaces() {
        let reg1 = FaceRegistration(imageFileName: "face1.jpg")
        let reg2 = FaceRegistration(imageFileName: "face2.jpg")
        let imageData1 = Data([0xFF, 0xD8, 0x01])
        let imageData2 = Data([0xFF, 0xD8, 0x02])

        mockFaceRepo.registrations = [reg1, reg2]
        mockFaceRepo.hasRegisteredFace = true
        mockFaceRepo.faceImageDataMap[reg1.id] = imageData1
        mockFaceRepo.faceImageDataMap[reg2.id] = imageData2

        let viewModel = makeViewModel()
        viewModel.reloadRegisteredFaces()

        XCTAssertEqual(mockVideoFrameProcessor.loadRegisteredFacesCallCount, 1)
    }

    func testReloadRegisteredFaces_EmptyWhenNoFaces() {
        mockFaceRepo.registrations = []
        mockFaceRepo.hasRegisteredFace = false

        let viewModel = makeViewModel()
        viewModel.reloadRegisteredFaces()

        // Should not call loadRegisteredFaces when no data available
        XCTAssertEqual(mockVideoFrameProcessor.loadRegisteredFacesCallCount, 0)
    }
}
