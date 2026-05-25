import AVFoundation
import CoreVideo
import Foundation
@testable import blurCam

/// Mock implementation of StreamingServiceProtocol for testing
final class MockStreamingService: StreamingServiceProtocol {

    // MARK: - Configurable State

    private(set) var streamingState: StreamingState = .idle
    var onStateChanged: ((StreamingState) -> Void)?
    var startStreamingError: Error?

    /// Simulate automatic state transition on startStreaming
    var simulateSuccessfulConnection: Bool = true

    // MARK: - Call Tracking

    var startStreamingCallCount = 0
    var startStreamingURL: String?
    var startStreamingStreamKey: String?
    var startStreamingWidth: Int?
    var startStreamingHeight: Int?
    var stopStreamingCallCount = 0
    var appendVideoCallCount = 0
    var appendAudioCallCount = 0

    // MARK: - StreamingServiceProtocol

    func startStreaming(url: String, streamKey: String, width: Int, height: Int) throws {
        startStreamingCallCount += 1
        startStreamingURL = url
        startStreamingStreamKey = streamKey
        startStreamingWidth = width
        startStreamingHeight = height

        if let error = startStreamingError {
            throw error
        }

        streamingState = .connecting
        onStateChanged?(.connecting)

        if simulateSuccessfulConnection {
            streamingState = .streaming
            onStateChanged?(.streaming)
        }
    }

    func stopStreaming() {
        stopStreamingCallCount += 1
        streamingState = .idle
        onStateChanged?(.idle)
    }

    func appendVideo(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        appendVideoCallCount += 1
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        appendAudioCallCount += 1
    }

    // MARK: - Test Helpers

    /// Simulate a connection error
    func simulateConnectionError(_ message: String) {
        streamingState = .error(message)
        onStateChanged?(.error(message))
    }

    /// Simulate network disconnection
    func simulateDisconnection() {
        streamingState = .error("接続が切断されました")
        onStateChanged?(.error("接続が切断されました"))
    }
}
