import AVFoundation
import CoreImage
import CoreVideo
import Foundation
@testable import blurCam

/// Mock implementation of VideoRecordingServiceProtocol for testing
final class MockVideoRecordingService: VideoRecordingServiceProtocol {

    // MARK: - Configurable State

    private(set) var isRecording: Bool = false
    var startRecordingError: Error?
    var stopRecordingError: Error?
    var stopRecordingURL: URL = URL(fileURLWithPath: "/tmp/mock_video.mp4")

    // MARK: - Call Tracking

    var startRecordingCallCount = 0
    var startRecordingWidth: Int?
    var startRecordingHeight: Int?
    var startRecordingIncludeAudio: Bool?
    var appendVideoFrameCallCount = 0
    var appendAudioSampleCallCount = 0
    var stopRecordingCallCount = 0

    // MARK: - VideoRecordingServiceProtocol

    func startRecording(width: Int, height: Int, includeAudio: Bool) throws {
        startRecordingCallCount += 1
        startRecordingWidth = width
        startRecordingHeight = height
        startRecordingIncludeAudio = includeAudio
        if let error = startRecordingError {
            throw error
        }
        isRecording = true
    }

    func appendVideoFrame(_ pixelBuffer: CVPixelBuffer, at presentationTime: CMTime) {
        appendVideoFrameCallCount += 1
    }

    func appendAudioSample(_ sampleBuffer: CMSampleBuffer) {
        appendAudioSampleCallCount += 1
    }

    func stopRecording() async throws -> URL {
        stopRecordingCallCount += 1
        isRecording = false
        if let error = stopRecordingError {
            throw error
        }
        return stopRecordingURL
    }
}
