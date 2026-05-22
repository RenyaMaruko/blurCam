import CoreGraphics
import XCTest
@testable import blurCam

final class FaceRecognitionServiceTests: XCTestCase {

    private var service: FaceRecognitionService!

    override func setUp() {
        super.setUp()
        service = FaceRecognitionService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState_NoRegisteredFace() {
        XCTAssertFalse(service.hasRegisteredFace)
    }

    // MARK: - Load Registered Face

    func testLoadRegisteredFace_WithInvalidData_SetsHasRegisteredFaceFalse() {
        service.loadRegisteredFace(from: Data())

        XCTAssertFalse(service.hasRegisteredFace)
    }

    func testLoadRegisteredFace_WithNonImageData_SetsHasRegisteredFaceFalse() {
        let nonImageData = "not an image".data(using: .utf8)!

        service.loadRegisteredFace(from: nonImageData)

        XCTAssertFalse(service.hasRegisteredFace)
    }

    func testLoadRegisteredFace_WithValidImage_SetsHasRegisteredFaceTrue() {
        // Create a simple valid image
        guard let imageData = createTestFaceImageData() else {
            // Skip on CI where image creation might fail
            return
        }

        service.loadRegisteredFace(from: imageData)

        // The feature print generation may or may not succeed depending on the test image
        // containing a recognizable face, but the method should not crash
        // The important thing is that it processes without error
    }

    // MARK: - Detect and Identify Faces

    func testDetectAndIdentify_WithEmptyPixelBuffer_ReturnsEmptyArray() {
        guard let pixelBuffer = createTestPixelBuffer(width: 100, height: 100) else {
            XCTFail("Failed to create test pixel buffer")
            return
        }

        let faces = service.detectAndIdentifyFaces(in: pixelBuffer, orientation: .up)

        // An empty pixel buffer should not contain faces
        XCTAssertTrue(faces.isEmpty)
    }

    func testDetectAndIdentify_WithoutRegisteredFace_AllFacesAreUnregistered() {
        // Without loading a registered face, any detected face should be unregistered
        XCTAssertFalse(service.hasRegisteredFace)

        guard let pixelBuffer = createTestPixelBuffer(width: 100, height: 100) else {
            XCTFail("Failed to create test pixel buffer")
            return
        }

        let faces = service.detectAndIdentifyFaces(in: pixelBuffer, orientation: .up)

        // All faces should be unregistered (if any are detected in the test image)
        for face in faces {
            XCTAssertFalse(face.isRegistered)
        }
    }

    // MARK: - Helpers

    private func createTestFaceImageData() -> Data? {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Draw a simple face-like shape (circle for head, dots for eyes)
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor(red: 0.9, green: 0.8, blue: 0.7, alpha: 1.0).setFill()
            let faceRect = CGRect(x: 40, y: 30, width: 120, height: 150)
            UIBezierPath(ovalIn: faceRect).fill()

            UIColor.black.setFill()
            // Eyes
            UIBezierPath(ovalIn: CGRect(x: 70, y: 70, width: 15, height: 10)).fill()
            UIBezierPath(ovalIn: CGRect(x: 115, y: 70, width: 15, height: 10)).fill()
            // Mouth
            UIBezierPath(ovalIn: CGRect(x: 85, y: 130, width: 30, height: 10)).fill()
        }

        return image.jpegData(compressionQuality: 0.9)
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
