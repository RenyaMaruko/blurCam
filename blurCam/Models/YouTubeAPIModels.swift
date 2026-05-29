import Foundation

// MARK: - Error Types

/// Error types for YouTube API operations
enum YouTubeAPIError: LocalizedError, Equatable {
    case networkError(String)
    case authenticationError(String)
    case quotaExceeded
    case invalidResponse(String)
    case broadcastCreationFailed(String)
    case streamCreationFailed(String)
    case bindFailed(String)
    case noIngestionInfo
    case transitionFailed(String)
    case thumbnailUploadFailed(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .authenticationError(let message):
            return "認証エラー: \(message)"
        case .quotaExceeded:
            return "YouTube APIの利用上限に達しました。しばらく時間をおいてから再試行してください。"
        case .invalidResponse(let message):
            return "APIレスポンスの解析に失敗しました: \(message)"
        case .broadcastCreationFailed(let message):
            return "配信枠の作成に失敗しました: \(message)"
        case .streamCreationFailed(let message):
            return "ストリームの作成に失敗しました: \(message)"
        case .bindFailed(let message):
            return "配信枠とストリームの紐付けに失敗しました: \(message)"
        case .noIngestionInfo:
            return "RTMP接続情報を取得できませんでした"
        case .transitionFailed(let message):
            return "配信ステータスの遷移に失敗しました: \(message)"
        case .thumbnailUploadFailed(let message):
            return "サムネイルのアップロードに失敗しました: \(message)"
        case .unknown(let message):
            return "不明なエラー: \(message)"
        }
    }

    /// Categorizes the error type for handling decisions
    var category: YouTubeAPIErrorCategory {
        switch self {
        case .networkError:
            return .network
        case .authenticationError:
            return .authentication
        case .quotaExceeded:
            return .quota
        default:
            return .other
        }
    }
}

/// Categories for YouTube API errors
enum YouTubeAPIErrorCategory {
    case network
    case authentication
    case quota
    case other
}

// MARK: - Privacy Status

/// Privacy setting for YouTube broadcasts
enum YouTubeBroadcastPrivacy: String, Codable, CaseIterable {
    case publicBroadcast = "public"
    case unlisted = "unlisted"
    case privateBroadcast = "private"

    var displayName: String {
        switch self {
        case .publicBroadcast:
            return "公開"
        case .unlisted:
            return "限定公開"
        case .privateBroadcast:
            return "非公開"
        }
    }
}

// MARK: - Broadcast Request/Response

/// Configuration for creating a new YouTube broadcast
struct YouTubeBroadcastConfig {
    let title: String
    let description: String
    let privacy: YouTubeBroadcastPrivacy
    let scheduledStartTime: Date
    let categoryId: String?
    let latencyPreference: String?
    let enableChat: Bool
    let enableDVR: Bool

    init(
        title: String = "blurCam Live",
        description: String = "",
        privacy: YouTubeBroadcastPrivacy = .unlisted,
        scheduledStartTime: Date = Date(),
        categoryId: String? = nil,
        latencyPreference: String? = nil,
        enableChat: Bool = true,
        enableDVR: Bool = true
    ) {
        self.title = title
        self.description = description
        self.privacy = privacy
        self.scheduledStartTime = scheduledStartTime
        self.categoryId = categoryId
        self.latencyPreference = latencyPreference
        self.enableChat = enableChat
        self.enableDVR = enableDVR
    }

    /// Creates a YouTubeBroadcastConfig from YouTubeLiveSettings
    init(from settings: YouTubeLiveSettings, scheduledStartTime: Date = Date()) {
        self.title = settings.title.isEmpty ? "blurCam Live" : settings.title
        self.description = settings.description
        self.privacy = settings.privacy
        self.scheduledStartTime = scheduledStartTime
        self.categoryId = settings.category.rawValue
        self.latencyPreference = settings.latencyPreference.rawValue
        self.enableChat = settings.enableChat
        self.enableDVR = settings.enableDVR
    }
}

/// Response from liveBroadcasts.insert API
struct YouTubeBroadcastResponse: Codable {
    let kind: String?
    let etag: String?
    let id: String
    let snippet: BroadcastSnippet?
    let status: BroadcastStatus?
    let contentDetails: BroadcastContentDetails?

    struct BroadcastSnippet: Codable {
        let publishedAt: String?
        let channelId: String?
        let title: String?
        let description: String?
        let scheduledStartTime: String?
    }

    struct BroadcastStatus: Codable {
        let lifeCycleStatus: String?
        let privacyStatus: String?
        let recordingStatus: String?
    }

    struct BroadcastContentDetails: Codable {
        let boundStreamId: String?
        let enableDvr: Bool?
        let enableAutoStart: Bool?
        let enableAutoStop: Bool?
    }
}

// MARK: - Stream Request/Response

/// Configuration for creating a new YouTube stream
struct YouTubeStreamConfig {
    let title: String
    let resolution: String
    let frameRate: String
    let ingestionType: String

    init(
        title: String = "blurCam Stream",
        resolution: String = "1080p",
        frameRate: String = "30fps",
        ingestionType: String = "rtmp"
    ) {
        self.title = title
        self.resolution = resolution
        self.frameRate = frameRate
        self.ingestionType = ingestionType
    }
}

/// Response from liveStreams.insert API
struct YouTubeStreamResponse: Codable {
    let kind: String?
    let etag: String?
    let id: String
    let snippet: StreamSnippet?
    let cdn: StreamCDN?
    let status: StreamStatus?

    struct StreamSnippet: Codable {
        let channelId: String?
        let title: String?
        let description: String?
    }

    struct StreamCDN: Codable {
        let ingestionType: String?
        let ingestionInfo: IngestionInfo?
        let resolution: String?
        let frameRate: String?

        struct IngestionInfo: Codable {
            let streamName: String?
            let ingestionAddress: String?
            let backupIngestionAddress: String?
        }
    }

    struct StreamStatus: Codable {
        let streamStatus: String?
        let healthStatus: HealthStatus?

        struct HealthStatus: Codable {
            let status: String?
        }
    }
}

// MARK: - Bind Response

/// Response from liveBroadcasts.bind API
struct YouTubeBindResponse: Codable {
    let kind: String?
    let etag: String?
    let id: String
    let contentDetails: BindContentDetails?

    struct BindContentDetails: Codable {
        let boundStreamId: String?
    }
}

// MARK: - RTMP Connection Info

/// Contains the RTMP connection information extracted from YouTube API responses
struct YouTubeRTMPInfo: Equatable {
    /// RTMP ingest URL (e.g., "rtmp://a.rtmp.youtube.com/live2")
    let rtmpURL: String
    /// Stream key (stream name)
    let streamKey: String
    /// Broadcast ID for lifecycle management
    let broadcastId: String
    /// Stream ID for status monitoring
    let streamId: String
}

// MARK: - API Error Response

/// Error response structure from YouTube API
struct YouTubeAPIErrorResponse: Codable {
    let error: APIError?

    struct APIError: Codable {
        let code: Int?
        let message: String?
        let errors: [APIErrorDetail]?

        struct APIErrorDetail: Codable {
            let domain: String?
            let reason: String?
            let message: String?
        }
    }
}

// MARK: - Stream Health Status

/// Represents the health status of a YouTube live stream
enum YouTubeStreamHealthStatus: String, Equatable {
    case good = "good"
    case ok = "ok"
    case bad = "bad"
    case noData = "noData"

    var displayName: String {
        switch self {
        case .good:
            return "良好"
        case .ok:
            return "正常"
        case .bad:
            return "低下"
        case .noData:
            return "データなし"
        }
    }

    var isHealthy: Bool {
        self == .good || self == .ok
    }
}

// MARK: - Broadcast Lifecycle Status

/// Represents the lifecycle status of a YouTube broadcast
enum YouTubeBroadcastLifecycleStatus: String, Equatable {
    case created = "created"
    case ready = "ready"
    case testing = "testing"
    case live = "live"
    case complete = "complete"
    case revoked = "revoked"

    var displayName: String {
        switch self {
        case .created:
            return "作成済み"
        case .ready:
            return "準備完了"
        case .testing:
            return "テスト中"
        case .live:
            return "配信中"
        case .complete:
            return "完了"
        case .revoked:
            return "取消済み"
        }
    }
}

// MARK: - Broadcast Update Config

/// Configuration for updating an existing YouTube broadcast's metadata
struct YouTubeBroadcastUpdateConfig {
    let broadcastId: String
    let title: String
    let description: String
}
