import Foundation

/// YouTube live broadcast category options.
/// Maps to YouTube videoCategories for live streaming.
enum YouTubeCategory: String, Codable, CaseIterable, Identifiable {
    case gaming = "20"
    case entertainment = "24"
    case education = "27"
    case scienceTechnology = "28"
    case peopleBlogs = "22"
    case music = "10"
    case sports = "17"
    case news = "25"
    case howtoStyle = "26"
    case comedy = "23"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gaming:
            return "ゲーム"
        case .entertainment:
            return "エンタメ"
        case .education:
            return "教育"
        case .scienceTechnology:
            return "科学と技術"
        case .peopleBlogs:
            return "ブログ"
        case .music:
            return "音楽"
        case .sports:
            return "スポーツ"
        case .news:
            return "ニュース"
        case .howtoStyle:
            return "ハウツーとスタイル"
        case .comedy:
            return "コメディ"
        }
    }
}

/// YouTube live broadcast latency preference.
/// Maps to contentDetails.latencyPreference in the YouTube API.
enum YouTubeLatencyPreference: String, Codable, CaseIterable, Identifiable {
    case normal = "normal"
    case low = "low"
    case ultraLow = "ultraLow"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal:
            return "通常遅延"
        case .low:
            return "低遅延"
        case .ultraLow:
            return "超低遅延"
        }
    }
}

/// Persisted YouTube live broadcast settings.
/// Stores all configuration options for creating a YouTube live broadcast via API.
struct YouTubeLiveSettings: Codable, Equatable {
    /// Broadcast title (required, cannot be empty)
    var title: String

    /// Broadcast description (optional)
    var description: String

    /// Privacy status for the broadcast
    var privacy: YouTubeBroadcastPrivacy

    /// Video category ID
    var category: YouTubeCategory

    /// Latency preference
    var latencyPreference: YouTubeLatencyPreference

    /// Whether live chat is enabled
    var enableChat: Bool

    /// Whether DVR (rewind during live) is enabled
    var enableDVR: Bool

    init(
        title: String = "blurCam Live",
        description: String = "",
        privacy: YouTubeBroadcastPrivacy = .privateBroadcast,
        category: YouTubeCategory = .entertainment,
        latencyPreference: YouTubeLatencyPreference = .normal,
        enableChat: Bool = true,
        enableDVR: Bool = true
    ) {
        self.title = title
        self.description = description
        self.privacy = privacy
        self.category = category
        self.latencyPreference = latencyPreference
        self.enableChat = enableChat
        self.enableDVR = enableDVR
    }
}
