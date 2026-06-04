import Foundation

/// Represents a streaming platform with preset RTMP URL configuration.
/// Each platform provides a default ingest URL that users can use directly.
enum StreamingPlatform: String, Codable, CaseIterable, Identifiable {
    case youTube = "youtube"
    case twitch = "twitch"
    case custom = "custom"

    var id: String { rawValue }

    /// Display name shown in the UI
    var displayName: String {
        switch self {
        case .youTube:
            return "YouTube Live"
        case .twitch:
            return "Twitch"
        case .custom:
            return "カスタムRTMP"
        }
    }

    /// Preset RTMP ingest URL for the platform.
    /// Returns an empty string for custom, as the user provides their own URL.
    var presetURL: String {
        switch self {
        case .youTube:
            return "rtmp://a.rtmp.youtube.com/live2"
        case .twitch:
            return "rtmp://live.twitch.tv/app"
        case .custom:
            return ""
        }
    }

    /// SF Symbol icon name for the platform
    var iconName: String {
        switch self {
        case .youTube:
            return "play.rectangle.fill"
        case .twitch:
            return "gamecontroller.fill"
        case .custom:
            return "server.rack"
        }
    }

    /// Platforms available for manual RTMP destination setup
    static var manualDestinationCases: [StreamingPlatform] {
        return [.youTube, .twitch, .custom]
    }
}

/// Represents the YouTube API-based streaming flow type.
/// This is separate from StreamingPlatform to keep the existing
/// manual RTMP flow untouched.
enum YouTubeStreamingFlowType: Equatable {
    /// Manual RTMP: user enters URL and stream key
    case manual
    /// YouTube API: automatic broadcast/stream creation
    case youTubeAPI
}
