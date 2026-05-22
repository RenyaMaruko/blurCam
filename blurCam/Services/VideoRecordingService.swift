@preconcurrency import AVFoundation
import CoreImage
import CoreVideo
import Foundation

/// Concrete implementation of VideoRecordingServiceProtocol using AVAssetWriter.
/// Writes blur-processed video frames and optional audio to a temporary MP4 file.
///
/// Architecture:
/// - AVAssetWriter writes to a temporary file in the app's tmp directory
/// - Video frames are received as CVPixelBuffer (already blur-processed)
/// - Audio samples are received as CMSampleBuffer from the audio capture output
/// - The resulting video has blur permanently baked into the frames
final class VideoRecordingService: VideoRecordingServiceProtocol {

    // MARK: - Properties

    private(set) var isRecording: Bool = false

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var outputURL: URL?
    private var hasStartedWriting = false
    private var sessionStartTime: CMTime?

    private let writingQueue = DispatchQueue(
        label: "com.blurCam.videoWritingQueue",
        qos: .userInteractive
    )

    // MARK: - VideoRecordingServiceProtocol

    func startRecording(width: Int, height: Int, includeAudio: Bool) throws {
        guard !isRecording else {
            throw VideoRecordingError.alreadyRecording
        }

        // Create a temporary file URL for the video
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "blurCam_\(UUID().uuidString).mp4"
        let fileURL = tempDir.appendingPathComponent(fileName)

        // Remove existing file if needed
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }

        // Create AVAssetWriter
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)
        } catch {
            throw VideoRecordingError.writerSetupFailed(error.localizedDescription)
        }

        // Configure video input
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: width * height * 4, // Good quality bitrate
                AVVideoExpectedSourceFrameRateKey: 30,
                AVVideoMaxKeyFrameIntervalKey: 30
            ]
        ]

        let vInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: videoSettings
        )
        vInput.expectsMediaDataInRealTime = true

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: vInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )

        guard writer.canAdd(vInput) else {
            throw VideoRecordingError.writerSetupFailed("ビデオ入力を追加できません")
        }
        writer.add(vInput)

        // Configure audio input if requested
        if includeAudio {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128000
            ]

            let aInput = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: audioSettings
            )
            aInput.expectsMediaDataInRealTime = true

            if writer.canAdd(aInput) {
                writer.add(aInput)
                audioInput = aInput
            }
        }

        // Start writing
        guard writer.startWriting() else {
            let errorMessage = writer.error?.localizedDescription ?? "不明なエラー"
            throw VideoRecordingError.writerSetupFailed(errorMessage)
        }

        self.assetWriter = writer
        self.videoInput = vInput
        self.pixelBufferAdaptor = adaptor
        self.outputURL = fileURL
        self.hasStartedWriting = false
        self.sessionStartTime = nil
        self.isRecording = true
    }

    func appendVideoFrame(_ pixelBuffer: CVPixelBuffer, at presentationTime: CMTime) {
        writingQueue.sync {
            guard isRecording,
                  let writer = assetWriter,
                  writer.status == .writing,
                  let videoInput = videoInput,
                  let adaptor = pixelBufferAdaptor else {
                return
            }

            // Start the session with the first frame's timestamp
            if !hasStartedWriting {
                writer.startSession(atSourceTime: presentationTime)
                sessionStartTime = presentationTime
                hasStartedWriting = true
            }

            // Only append if the input is ready
            if videoInput.isReadyForMoreMediaData {
                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            }
        }
    }

    func appendAudioSample(_ sampleBuffer: CMSampleBuffer) {
        writingQueue.sync {
            guard isRecording,
                  let writer = assetWriter,
                  writer.status == .writing,
                  hasStartedWriting,
                  let audioInput = audioInput,
                  audioInput.isReadyForMoreMediaData else {
                return
            }

            audioInput.append(sampleBuffer)
        }
    }

    func stopRecording() async throws -> URL {
        guard isRecording else {
            throw VideoRecordingError.notRecording
        }

        guard let writer = assetWriter, let url = outputURL else {
            throw VideoRecordingError.notRecording
        }

        // Mark inputs as finished
        isRecording = false

        return try await withCheckedThrowingContinuation { continuation in
            writingQueue.async { [weak self] in
                self?.videoInput?.markAsFinished()
                self?.audioInput?.markAsFinished()

                writer.finishWriting {
                    if writer.status == .completed {
                        self?.cleanupWriter()
                        continuation.resume(returning: url)
                    } else {
                        let errorMessage = writer.error?.localizedDescription ?? "録画の完了に失敗しました"
                        self?.cleanupWriter()
                        continuation.resume(throwing: VideoRecordingError.writingFailed(errorMessage))
                    }
                }
            }
        }
    }

    // MARK: - Private Methods

    private func cleanupWriter() {
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil
        hasStartedWriting = false
        sessionStartTime = nil
    }
}
