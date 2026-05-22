import CoreImage
import XCTest
@testable import blurCam

final class BlurProcessingServiceTests: XCTestCase {

    private var service: BlurProcessingService!

    override func setUp() {
        super.setUp()
        service = BlurProcessingService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Blur Radius

    func testDefaultBlurRadius() {
        XCTAssertEqual(service.blurRadius, 30.0)
    }

    func testBlurRadius_CanBeChanged() {
        service.blurRadius = 50.0
        XCTAssertEqual(service.blurRadius, 50.0)
    }

    // MARK: - Apply Blur to CIImage

    func testApplyBlur_NoFaces_ReturnsOriginalImage() {
        let ciImage = createTestCIImage(width: 100, height: 100)

        let result = service.applyBlur(to: ciImage, faces: [])

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.extent.width, ciImage.extent.width)
        XCTAssertEqual(result?.extent.height, ciImage.extent.height)
    }

    func testApplyBlur_OnlyRegisteredFaces_ReturnsOriginalImage() {
        let ciImage = createTestCIImage(width: 100, height: 100)
        let registeredFace = DetectedFace(
            boundingBox: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4),
            isRegistered: true
        )

        let result = service.applyBlur(to: ciImage, faces: [registeredFace])

        XCTAssertNotNil(result)
    }

    func testApplyBlur_UnregisteredFace_ReturnsProcessedImage() {
        let ciImage = createTestCIImage(width: 200, height: 200)
        let unregisteredFace = DetectedFace(
            boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6),
            isRegistered: false
        )

        let result = service.applyBlur(to: ciImage, faces: [unregisteredFace])

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.extent.width, ciImage.extent.width)
        XCTAssertEqual(result?.extent.height, ciImage.extent.height)
    }

    func testApplyBlur_MultipleFaces_MixedRegistration() {
        let ciImage = createTestCIImage(width: 300, height: 300)
        let registeredFace = DetectedFace(
            boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.3),
            isRegistered: true
        )
        let unregisteredFace1 = DetectedFace(
            boundingBox: CGRect(x: 0.5, y: 0.5, width: 0.2, height: 0.3),
            isRegistered: false
        )
        let unregisteredFace2 = DetectedFace(
            boundingBox: CGRect(x: 0.7, y: 0.1, width: 0.2, height: 0.3),
            isRegistered: false
        )

        let result = service.applyBlur(
            to: ciImage,
            faces: [registeredFace, unregisteredFace1, unregisteredFace2]
        )

        XCTAssertNotNil(result)
    }

    func testApplyBlur_ThreeOrMoreUnregisteredFaces() {
        let ciImage = createTestCIImage(width: 400, height: 400)
        let faces = (0..<4).map { index in
            DetectedFace(
                boundingBox: CGRect(
                    x: Double(index) * 0.2 + 0.05,
                    y: 0.3,
                    width: 0.15,
                    height: 0.2
                ),
                isRegistered: false
            )
        }

        let result = service.applyBlur(to: ciImage, faces: faces)

        XCTAssertNotNil(result)
    }

    // MARK: - Apply Blur to Pixel Buffer

    func testApplyBlur_PixelBuffer_NoFaces_ReturnsImage() {
        guard let pixelBuffer = createTestPixelBuffer(width: 100, height: 100) else {
            XCTFail("Failed to create test pixel buffer")
            return
        }

        let result = service.applyBlur(
            to: pixelBuffer,
            faces: [],
            imageWidth: 100,
            imageHeight: 100
        )

        XCTAssertNotNil(result)
    }

    func testApplyBlur_PixelBuffer_WithUnregisteredFace() {
        guard let pixelBuffer = createTestPixelBuffer(width: 200, height: 200) else {
            XCTFail("Failed to create test pixel buffer")
            return
        }

        let face = DetectedFace(
            boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6),
            isRegistered: false
        )

        let result = service.applyBlur(
            to: pixelBuffer,
            faces: [face],
            imageWidth: 200,
            imageHeight: 200
        )

        XCTAssertNotNil(result)
    }

    // MARK: - Helpers

    private func createTestCIImage(width: Int, height: Int) -> CIImage {
        let color = CIColor(red: 0.5, green: 0.5, blue: 0.5)
        let image = CIImage(color: color)
        return image.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }

    private func createTestPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess else { return nil }
        return pixelBuffer
    }
}
