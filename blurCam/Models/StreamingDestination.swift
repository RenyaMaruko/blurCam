import Foundation

/// Represents a saved streaming destination with RTMP connection details.
/// Persisted via Codable to UserDefaults through the StreamingSettingsRepository.
struct StreamingDestination: Identifiable, Codable, Equatable {
    /// Unique identifier for this destination
    let id: UUID

    /// User-provided name for this destination (e.g., "My YouTube Channel")
    let name: String

    /// The streaming platform type
    let platform: StreamingPlatform

    /// The RTMP ingest URL (e.g., "rtmp://a.rtmp.youtube.com/live2")
    let rtmpURL: String

    /// The stream key for authentication
    let streamKey: String

    /// When this destination was created
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        platform: StreamingPlatform,
        rtmpURL: String,
        streamKey: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.platform = platform
        self.rtmpURL = rtmpURL
        self.streamKey = streamKey
        self.createdAt = createdAt
    }
}
