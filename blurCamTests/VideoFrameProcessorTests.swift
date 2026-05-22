import AVFoundation
import CoreImage
import XCTest
@testable import blurCam

final class VideoFrameProcessorTests: XCTestCase {

    private var mockRecognitionService: MockFaceRecognitionService!
    private var mockBlurService: MockBlurProcessingService!
    private var processor: VideoFrameProcessor!

    override func setUp() {
        super.setUp()
        mockRecognitionService = MockFaceRecognitionService()
        mockBlurService = MockBlurProcessingService()
        processor = VideoFrameProcessor(
            faceRecognitionService: mockRecognitionService,
            blurProcessingService: mockBlurService
        )
    }

    override func tearDown() {
        mockRecognitionService = nil
        mockBlurService = nil
        processor = nil
        super.tearDown()
    }

    // MARK: - Load Registered Face

    func testLoadRegisteredFace_DelegatesToRecognitionService() {
        let data = Data([0x01, 0x02, 0x03])

        processor.loadRegisteredFace(from: data)

        XCTAssertEqual(mockRecognitionService.loadRegisteredFaceCallCount, 1)
        XCTAssertEqual(mockRecognitionService.loadRegisteredFaceData.first, data)
    }

    // MARK: - Process Still Image

    func testProcessStillImage_WithInvalidData_ReturnsNil() {
        let result = processor.processStillImage(Data())

        XCTAssertNil(result)
    }

    func testProcessStillImage_WithValidImage_NoUnregisteredFaces_ReturnsOriginalData() {
        guard let imageData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        // All faces are registered
        mockRecognitionService.detectAndIdentifyResult = [
            DetectedFace(
                boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6),
                isRegistered: true
            )
        ]

        let result = processor.processStillImage(imageData)

        // Should return original data when no unregistered faces
        XCTAssertNotNil(result)
        XCTAssertEqual(result, imageData)
    }

    func testProcessStillImage_WithValidImage_HasUnregisteredFaces_AppliesBlur() {
        guard let imageData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        // Mix of registered and unregistered faces
        mockRecognitionService.detectAndIdentifyResult = [
            DetectedFace(
                boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.3),
                isRegistered: true
            ),
            DetectedFace(
                boundingBox: CGRect(x: 0.5, y: 0.5, width: 0.3, height: 0.3),
                isRegistered: false
            )
        ]

        let result = processor.processStillImage(imageData)

        XCTAssertNotNil(result)
        XCTAssertEqual(mockBlurService.applyBlurCIImageCallCount, 1)
    }

    func testProcessStillImage_WithValidImage_NoFacesDetected_ReturnsOriginalData() {
        guard let imageData = createTestImageData() else {
            XCTFail("Failed to create test image data")
            return
        }

        mockRecognitionService.detectAndIdentifyResult = []

        let result = processor.processStillImage(imageData)

        XCTAssertNotNil(result)
        XCTAssertEqual(result, imageData)
    }

    // MARK: - Callback Setup

    func testOnFrameProcessed_CanBeSet() {
        var callbackInvoked = false
        processor.onFrameProcessed = { _ in
            callbackInvoked = true
        }

        XCTAssertNotNil(processor.onFrameProcessed)
    }

    func testOnFacesDetected_CanBeSet() {
        processor.onFacesDetected = { _ in }

        XCTAssertNotNil(processor.onFacesDetected)
    }

    func testOnProcessedPixelBuffer_CanBeSet() {
        processor.onProcessedPixelBuffer = { _, _ in }

        XCTAssertNotNil(processor.onProcessedPixelBuffer)
    }

    func testOnAudioSampleBuffer_CanBeSet() {
        processor.onAudioSampleBuffer = { _ in }

        XCTAssertNotNil(processor.onAudioSampleBuffer)
    }

    // MARK: - Video Dimensions

    func testVideoWidth_InitiallyZero() {
        XCTAssertEqual(processor.videoWidth, 0)
    }

    func testVideoHeight_InitiallyZero() {
        XCTAssertEqual(processor.videoHeight, 0)
    }

    // MARK: - Helpers

    private func createTestImageData() -> Data? {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.9)
    }
}
