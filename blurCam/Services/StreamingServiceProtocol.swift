import AVFoundation
import CoreVideo
import Foundation

/// Error types for streaming operations
enum StreamingError: LocalizedError {
    case alreadyStreaming
    case notStreaming
    case connectionFailed(String)
    case invalidURL
    case missingConfiguration

    var errorDescription: String? {
        switch self {
        case .alreadyStreaming:
            return "既に配信中です"
        case .notStreaming:
            return "配信されていません"
        case .connectionFailed(let message):
            return "RTMP接続に失敗しました: \(message)"
        case .invalidURL:
            return "無効なRTMP URLです"
        case .missingConfiguration:
            return "配信先が設定されていません。設定画面でRTMP URLとストリームキーを入力してください。"
        }
    }
}

/// Protocol abstracting live streaming capabilities.
/// Uses RTMP to send blur-processed video frames and audio to a streaming server.
protocol StreamingServiceProtocol: AnyObject {
    /// The current streaming state
    var streamingState: StreamingState { get }

    /// Callback invoked when the streaming state changes.
    /// Called on any thread; callers must dispatch to main if needed.
    var onStateChanged: ((StreamingState) -> Void)? { get set }

    /// Connect to an RTMP server and begin streaming.
    /// - Parameters:
    ///   - url: The RTMP server URL (e.g., "rtmp://live.example.com/app")
    ///   - streamKey: The stream key for authentication
    ///   - width: Video frame width in pixels
    ///   - height: Video frame height in pixels
    func startStreaming(url: String, streamKey: String, width: Int, height: Int) throws

    /// Stop streaming and disconnect from the RTMP server.
    func stopStreaming()

    /// Append a processed video frame to the stream.
    /// - Parameters:
    ///   - pixelBuffer: The blur-processed pixel buffer to stream
    ///   - presentationTime: The presentation timestamp of the frame
    func appendVideo(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime)

    /// Append an audio sample buffer to the stream.
    /// - Parameter sampleBuffer: The audio sample buffer to stream
    func appendAudio(_ sampleBuffer: CMSampleBuffer)
}
