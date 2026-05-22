import AVFoundation
import CoreImage
import Foundation

/// Error types for video recording operations
enum VideoRecordingError: LocalizedError {
    case alreadyRecording
    case notRecording
    case writerSetupFailed(String)
    case writingFailed(String)
    case fileCreationFailed

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "既に録画中です"
        case .notRecording:
            return "録画されていません"
        case .writerSetupFailed(let message):
            return "録画の初期化に失敗しました: \(message)"
        case .writingFailed(let message):
            return "録画中にエラーが発生しました: \(message)"
        case .fileCreationFailed:
            return "録画ファイルの作成に失敗しました"
        }
    }
}

/// Protocol abstracting video recording capabilities.
/// Uses AVAssetWriter to write processed (blur-applied) video frames.
protocol VideoRecordingServiceProtocol: AnyObject {
    /// Whether recording is currently in progress
    var isRecording: Bool { get }

    /// Start recording video to a temporary file.
    /// - Parameters:
    ///   - width: Video frame width in pixels
    ///   - height: Video frame height in pixels
    ///   - includeAudio: Whether to include audio track
    func startRecording(width: Int, height: Int, includeAudio: Bool) throws

    /// Append a processed video frame (with blur applied).
    /// - Parameters:
    ///   - pixelBuffer: The processed pixel buffer to write
    ///   - presentationTime: The presentation timestamp of the frame
    func appendVideoFrame(_ pixelBuffer: CVPixelBuffer, at presentationTime: CMTime)

    /// Append an audio sample buffer.
    /// - Parameter sampleBuffer: The audio sample buffer to write
    func appendAudioSample(_ sampleBuffer: CMSampleBuffer)

    /// Stop recording and finalize the video file.
    /// - Returns: The URL of the recorded video file
    func stopRecording() async throws -> URL
}
