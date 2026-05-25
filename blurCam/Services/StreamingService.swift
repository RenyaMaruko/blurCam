import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import HaishinKit

/// Concrete implementation of StreamingServiceProtocol using HaishinKit RTMP (v1.9.x).
/// Manages the RTMP connection lifecycle and feeds blur-processed video frames
/// and audio sample buffers to the RTMP stream.
///
/// Architecture:
/// - RTMPConnection handles the socket connection to the RTMP server
/// - RTMPStream handles encoding and transmitting audio/video data
/// - Video frames arrive as CVPixelBuffer and are wrapped into CMSampleBuffer
/// - Audio arrives as CMSampleBuffer and is forwarded directly
/// - Connection status is monitored via NotificationCenter events
final class StreamingService: NSObject, StreamingServiceProtocol {

    // MARK: - Properties

    private(set) var streamingState: StreamingState = .idle {
        didSet {
            if oldValue != streamingState {
                onStateChanged?(streamingState)
            }
        }
    }

    var onStateChanged: ((StreamingState) -> Void)?

    // MARK: - Private Properties

    private var connection: RTMPConnection?
    private var stream: RTMPStream?

    /// Video format description for creating sample buffers from pixel buffers
    private var videoFormatDescription: CMVideoFormatDescription?
    private var videoFormatWidth: Int = 0
    private var videoFormatHeight: Int = 0

    /// Stored connection parameters for publish
    private var currentStreamName: String?

    private let streamingQueue = DispatchQueue(
        label: "com.blurCam.streamingQueue",
        qos: .userInteractive
    )

    // MARK: - Initialization

    override init() {
        super.init()
    }

    deinit {
        cleanupConnection()
    }

    // MARK: - StreamingServiceProtocol

    func startStreaming(url: String, streamKey: String, width: Int, height: Int) throws {
        guard !streamingState.isActive else {
            throw StreamingError.alreadyStreaming
        }

        guard !url.isEmpty else {
            throw StreamingError.missingConfiguration
        }

        guard url.hasPrefix("rtmp://") || url.hasPrefix("rtmps://") else {
            throw StreamingError.invalidURL
        }

        streamingState = .connecting
        videoFormatDescription = nil

        // Build the connection URL and stream name
        // RTMP URL format: rtmp://server/app
        // Stream key is used as the publish stream name
        let connectionURL: String
        let publishName: String

        if streamKey.isEmpty {
            // If no stream key, use the full URL and default publish name
            connectionURL = url
            publishName = "live"
        } else {
            connectionURL = url.hasSuffix("/") ? String(url.dropLast()) : url
            publishName = streamKey
        }

        currentStreamName = publishName

        // Create connection
        let conn = RTMPConnection()
        self.connection = conn

        // Create stream
        let rtmpStream = RTMPStream(connection: conn)
        self.stream = rtmpStream

        // Configure video codec settings
        rtmpStream.videoSettings.videoSize = .init(width: width, height: height)
        rtmpStream.videoSettings.bitRate = width * height * 2
        rtmpStream.videoSettings.maxKeyFrameIntervalDuration = 2
        rtmpStream.videoSettings.scalingMode = .letterbox

        // Configure audio codec settings
        rtmpStream.audioSettings.bitRate = 128_000

        // Register for RTMP status notifications on both connection and stream
        registerForStatusNotifications(connection: conn, stream: rtmpStream)

        // Connect (synchronous call, status arrives via notification)
        conn.connect(connectionURL)
    }

    func stopStreaming() {
        guard streamingState != .idle else { return }

        cleanupConnection()
        streamingState = .idle
    }

    func appendVideo(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard streamingState == .streaming, let stream = stream else { return }

        streamingQueue.async { [weak self] in
            guard let self = self else { return }

            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)

            // Create or update video format description if dimensions change
            if self.videoFormatDescription == nil ||
                self.videoFormatWidth != width ||
                self.videoFormatHeight != height {
                var formatDesc: CMVideoFormatDescription?
                let status = CMVideoFormatDescriptionCreateForImageBuffer(
                    allocator: kCFAllocatorDefault,
                    imageBuffer: pixelBuffer,
                    formatDescriptionOut: &formatDesc
                )
                if status == noErr, let desc = formatDesc {
                    self.videoFormatDescription = desc
                    self.videoFormatWidth = width
                    self.videoFormatHeight = height
                }
            }

            guard let formatDesc = self.videoFormatDescription else { return }

            // Create CMSampleBuffer from CVPixelBuffer
            var sampleBuffer: CMSampleBuffer?
            var timingInfo = CMSampleTimingInfo(
                duration: CMTime(value: 1, timescale: 30),
                presentationTimeStamp: presentationTime,
                decodeTimeStamp: .invalid
            )

            let status = CMSampleBufferCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer,
                dataReady: true,
                makeDataReadyCallback: nil,
                refcon: nil,
                formatDescription: formatDesc,
                sampleTiming: &timingInfo,
                sampleBufferOut: &sampleBuffer
            )

            guard status == noErr, let buffer = sampleBuffer else { return }

            stream.append(buffer)
        }
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        guard streamingState == .streaming, let stream = stream else { return }

        stream.append(sampleBuffer)
    }

    // MARK: - RTMP Status Handling

    private func registerForStatusNotifications(connection: RTMPConnection, stream: RTMPStream) {
        // HaishinKit dispatches notifications with name format: "rtmpStatus/false"
        // using the EventDispatcher system
        connection.addEventListener(.rtmpStatus, selector: #selector(handleRTMPStatus(_:)), observer: self, useCapture: false)
        stream.addEventListener(.rtmpStatus, selector: #selector(handleRTMPStatus(_:)), observer: self, useCapture: false)
    }

    @objc private func handleRTMPStatus(_ notification: Notification) {
        // Extract the Event from the notification
        let event = Event.from(notification)
        guard let data = event.data as? [String: Any],
              let code = data["code"] as? String else {
            return
        }

        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            // Connection succeeded, now publish
            if let publishName = currentStreamName {
                stream?.publish(publishName)
            }
            streamingState = .streaming

        case RTMPConnection.Code.connectFailed.rawValue:
            let description = data["description"] as? String ?? "接続に失敗しました"
            streamingState = .error(description)
            cleanupConnection()

        case RTMPConnection.Code.connectClosed.rawValue:
            if streamingState == .streaming {
                streamingState = .error("接続が切断されました")
            }
            cleanupConnection()

        case RTMPStream.Code.publishStart.rawValue:
            streamingState = .streaming

        default:
            break
        }
    }

    // MARK: - Private Methods

    private func cleanupConnection() {
        if let stream = stream {
            stream.removeEventListener(.rtmpStatus, selector: #selector(handleRTMPStatus(_:)), observer: self, useCapture: false)
        }
        if let connection = connection {
            connection.removeEventListener(.rtmpStatus, selector: #selector(handleRTMPStatus(_:)), observer: self, useCapture: false)
        }

        stream?.close()
        stream = nil

        connection?.close()
        connection = nil

        videoFormatDescription = nil
        currentStreamName = nil
    }
}
