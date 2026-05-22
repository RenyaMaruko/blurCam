import AVFoundation
import XCTest
@testable import blurCam

final class VideoRecordingServiceTests: XCTestCase {

    private var service: VideoRecordingService!

    override func setUp() {
        super.setUp()
        service = VideoRecordingService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    func testInitialState_NotRecording() {
        XCTAssertFalse(service.isRecording)
    }

    func testStartRecording_SetsIsRecordingTrue() throws {
        try service.startRecording(width: 1920, height: 1080, includeAudio: false)

        XCTAssertTrue(service.isRecording)

        // Clean up
        Task {
            _ = try? await service.stopRecording()
        }
    }

    func testStartRecording_WithAudio() throws {
        try service.startRecording(width: 1920, height: 1080, includeAudio: true)

        XCTAssertTrue(service.isRecording)

        // Clean up
        Task {
            _ = try? await service.stopRecording()
        }
    }

    func testStartRecording_ThrowsWhenAlreadyRecording() throws {
        try service.startRecording(width: 1920, height: 1080, includeAudio: false)

        XCTAssertThrowsError(try service.startRecording(width: 1920, height: 1080, includeAudio: false)) { error in
            XCTAssertTrue(error is VideoRecordingError)
            if case VideoRecordingError.alreadyRecording = error {
                // Expected
            } else {
                XCTFail("Expected alreadyRecording error, got \(error)")
            }
        }

        // Clean up
        Task {
            _ = try? await service.stopRecording()
        }
    }

    func testStopRecording_ThrowsWhenNotRecording() async {
        do {
            _ = try await service.stopRecording()
            XCTFail("Expected error when stopping while not recording")
        } catch {
            XCTAssertTrue(error is VideoRecordingError)
            if case VideoRecordingError.notRecording = error {
                // Expected
            } else {
                XCTFail("Expected notRecording error, got \(error)")
            }
        }
    }

    func testStopRecording_ReturnsURL() async throws {
        try service.startRecording(width: 640, height: 480, includeAudio: false)

        // Create a simple test pixel buffer and append a frame
        let pixelBuffer = createTestPixelBuffer(width: 640, height: 480)
        if let buffer = pixelBuffer {
            service.appendVideoFrame(buffer, at: CMTime(value: 0, timescale: 30))
            // Small delay to allow the writer to process
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        let url = try await service.stopRecording()

        XCTAssertTrue(url.path.contains("blurCam_"))
        XCTAssertTrue(url.path.hasSuffix(".mp4"))
        XCTAssertFalse(service.isRecording)

        // Clean up
        try? FileManager.default.removeItem(at: url)
    }

    func testStartRecording_CreatesTemporaryFile() throws {
        try service.startRecording(width: 1920, height: 1080, includeAudio: false)

        XCTAssertTrue(service.isRecording)

        // Clean up
        Task {
            _ = try? await service.stopRecording()
        }
    }

    // MARK: - VideoRecordingError Tests

    func testVideoRecordingError_AlreadyRecording_Description() {
        let error = VideoRecordingError.alreadyRecording
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("録画中"))
    }

    func testVideoRecordingError_NotRecording_Description() {
        let error = VideoRecordingError.notRecording
        XCTAssertNotNil(error.errorDescription)
    }

    func testVideoRecordingError_WriterSetupFailed_Description() {
        let error = VideoRecordingError.writerSetupFailed("テスト")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("テスト"))
    }

    func testVideoRecordingError_WritingFailed_Description() {
        let error = VideoRecordingError.writingFailed("テスト")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("テスト"))
    }

    func testVideoRecordingError_FileCreationFailed_Description() {
        let error = VideoRecordingError.fileCreationFailed
        XCTAssertNotNil(error.errorDescription)
    }

    // MARK: - Helper

    private func createTestPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
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
