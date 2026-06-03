import Foundation
@testable import blurCam

/// Mock implementation of YouTubeAPIServiceProtocol for testing
final class MockYouTubeAPIService: YouTubeAPIServiceProtocol {

    // MARK: - Mock Configuration

    var createBroadcastResult: Result<YouTubeBroadcastResponse, Error> = .success(
        YouTubeBroadcastResponse(
            kind: "youtube#liveBroadcast",
            etag: "mock-etag",
            id: "mock-broadcast-id",
            snippet: YouTubeBroadcastResponse.BroadcastSnippet(
                publishedAt: "2026-01-01T00:00:00Z",
                channelId: "mock-channel-id",
                title: "Test Broadcast",
                description: "Test description",
                scheduledStartTime: "2026-01-01T00:00:00Z"
            ),
            status: YouTubeBroadcastResponse.BroadcastStatus(
                lifeCycleStatus: "created",
                privacyStatus: "unlisted",
                recordingStatus: nil
            ),
            contentDetails: YouTubeBroadcastResponse.BroadcastContentDetails(
                boundStreamId: nil,
                enableDvr: true,
                enableAutoStart: true,
                enableAutoStop: true
            )
        )
    )

    var createStreamResult: Result<YouTubeStreamResponse, Error> = .success(
        YouTubeStreamResponse(
            kind: "youtube#liveStream",
            etag: "mock-etag",
            id: "mock-stream-id",
            snippet: YouTubeStreamResponse.StreamSnippet(
                channelId: "mock-channel-id",
                title: "Test Stream",
                description: nil
            ),
            cdn: YouTubeStreamResponse.StreamCDN(
                ingestionType: "rtmp",
                ingestionInfo: YouTubeStreamResponse.StreamCDN.IngestionInfo(
                    streamName: "mock-stream-key-abc123",
                    ingestionAddress: "rtmp://a.rtmp.youtube.com/live2",
                    backupIngestionAddress: "rtmp://b.rtmp.youtube.com/live2?backup=1"
                ),
                resolution: "1080p",
                frameRate: "30fps"
            ),
            status: YouTubeStreamResponse.StreamStatus(
                streamStatus: "ready",
                healthStatus: YouTubeStreamResponse.StreamStatus.HealthStatus(status: "good")
            )
        )
    )

    var bindResult: Result<YouTubeBindResponse, Error> = .success(
        YouTubeBindResponse(
            kind: "youtube#liveBroadcast",
            etag: "mock-etag",
            id: "mock-broadcast-id",
            contentDetails: YouTubeBindResponse.BindContentDetails(
                boundStreamId: "mock-stream-id"
            )
        )
    )

    var setupLiveStreamResult: Result<YouTubeRTMPInfo, Error>?

    var transitionBroadcastResult: Result<YouTubeBroadcastResponse, Error> = .success(
        YouTubeBroadcastResponse(
            kind: "youtube#liveBroadcast",
            etag: "mock-etag",
            id: "mock-broadcast-id",
            snippet: nil,
            status: YouTubeBroadcastResponse.BroadcastStatus(
                lifeCycleStatus: "live",
                privacyStatus: "unlisted",
                recordingStatus: nil
            ),
            contentDetails: nil
        )
    )

    var getStreamHealthResult: Result<YouTubeStreamHealthStatus, Error> = .success(.good)

    var updateBroadcastMetadataResult: Result<YouTubeBroadcastResponse, Error> = .success(
        YouTubeBroadcastResponse(
            kind: "youtube#liveBroadcast",
            etag: "mock-etag",
            id: "mock-broadcast-id",
            snippet: YouTubeBroadcastResponse.BroadcastSnippet(
                publishedAt: nil,
                channelId: nil,
                title: "Updated Title",
                description: "Updated Description",
                scheduledStartTime: nil
            ),
            status: nil,
            contentDetails: nil
        )
    )

    var uploadThumbnailError: Error?

    var getLiveChatIdResult: Result<String, Error> = .success("mock-live-chat-id")
    var fetchLiveChatMessagesResult: Result<YouTubeLiveChatMessagesResponse, Error> = .success(
        YouTubeLiveChatMessagesResponse(
            kind: "youtube#liveChatMessageListResponse",
            etag: "mock-etag",
            nextPageToken: "mock-page-token",
            pollingIntervalMillis: 5000,
            pageInfo: YouTubeLiveChatMessagesResponse.PageInfo(totalResults: 0, resultsPerPage: 200),
            items: []
        )
    )

    // MARK: - Call Tracking

    var createBroadcastCallCount = 0
    var createBroadcastConfigs: [YouTubeBroadcastConfig] = []
    var createBroadcastAccessTokens: [String] = []

    var createStreamCallCount = 0
    var createStreamConfigs: [YouTubeStreamConfig] = []
    var createStreamAccessTokens: [String] = []

    var bindCallCount = 0
    var bindBroadcastIds: [String] = []
    var bindStreamIds: [String] = []
    var bindAccessTokens: [String] = []

    var setupLiveStreamCallCount = 0

    var transitionBroadcastCallCount = 0
    var transitionBroadcastIds: [String] = []
    var transitionStatuses: [String] = []
    var transitionAccessTokens: [String] = []

    var getStreamHealthCallCount = 0
    var getStreamHealthStreamIds: [String] = []
    var getStreamHealthAccessTokens: [String] = []

    var updateBroadcastMetadataCallCount = 0
    var updateBroadcastMetadataConfigs: [YouTubeBroadcastUpdateConfig] = []
    var updateBroadcastMetadataAccessTokens: [String] = []

    var uploadThumbnailCallCount = 0
    var uploadThumbnailBroadcastIds: [String] = []
    var uploadThumbnailImageData: [Data] = []
    var uploadThumbnailMimeTypes: [String] = []
    var uploadThumbnailAccessTokens: [String] = []

    var getLiveChatIdCallCount = 0
    var getLiveChatIdBroadcastIds: [String] = []
    var getLiveChatIdAccessTokens: [String] = []

    var fetchLiveChatMessagesCallCount = 0
    var fetchLiveChatMessagesLiveChatIds: [String] = []
    var fetchLiveChatMessagesPageTokens: [String?] = []
    var fetchLiveChatMessagesAccessTokens: [String] = []

    // MARK: - YouTubeAPIServiceProtocol

    func createBroadcast(config: YouTubeBroadcastConfig, accessToken: String) async throws -> YouTubeBroadcastResponse {
        createBroadcastCallCount += 1
        createBroadcastConfigs.append(config)
        createBroadcastAccessTokens.append(accessToken)

        switch createBroadcastResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func createStream(config: YouTubeStreamConfig, accessToken: String) async throws -> YouTubeStreamResponse {
        createStreamCallCount += 1
        createStreamConfigs.append(config)
        createStreamAccessTokens.append(accessToken)

        switch createStreamResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func bindBroadcastToStream(broadcastId: String, streamId: String, accessToken: String) async throws -> YouTubeBindResponse {
        bindCallCount += 1
        bindBroadcastIds.append(broadcastId)
        bindStreamIds.append(streamId)
        bindAccessTokens.append(accessToken)

        switch bindResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func setupLiveStream(
        broadcastConfig: YouTubeBroadcastConfig,
        streamConfig: YouTubeStreamConfig,
        accessToken: String
    ) async throws -> YouTubeRTMPInfo {
        setupLiveStreamCallCount += 1

        if let overrideResult = setupLiveStreamResult {
            switch overrideResult {
            case .success(let info):
                return info
            case .failure(let error):
                throw error
            }
        }

        // Default: execute the full flow using individual mocks
        let broadcast = try await createBroadcast(config: broadcastConfig, accessToken: accessToken)
        let stream = try await createStream(config: streamConfig, accessToken: accessToken)
        _ = try await bindBroadcastToStream(broadcastId: broadcast.id, streamId: stream.id, accessToken: accessToken)

        guard let ingestionInfo = stream.cdn?.ingestionInfo,
              let rtmpURL = ingestionInfo.ingestionAddress,
              let streamKey = ingestionInfo.streamName else {
            throw YouTubeAPIError.noIngestionInfo
        }

        return YouTubeRTMPInfo(
            rtmpURL: rtmpURL,
            streamKey: streamKey,
            broadcastId: broadcast.id,
            streamId: stream.id
        )
    }

    func transitionBroadcast(broadcastId: String, toStatus: String, accessToken: String) async throws -> YouTubeBroadcastResponse {
        transitionBroadcastCallCount += 1
        transitionBroadcastIds.append(broadcastId)
        transitionStatuses.append(toStatus)
        transitionAccessTokens.append(accessToken)

        switch transitionBroadcastResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func getStreamHealth(streamId: String, accessToken: String) async throws -> YouTubeStreamHealthStatus {
        getStreamHealthCallCount += 1
        getStreamHealthStreamIds.append(streamId)
        getStreamHealthAccessTokens.append(accessToken)

        switch getStreamHealthResult {
        case .success(let health):
            return health
        case .failure(let error):
            throw error
        }
    }

    func updateBroadcastMetadata(config: YouTubeBroadcastUpdateConfig, accessToken: String) async throws -> YouTubeBroadcastResponse {
        updateBroadcastMetadataCallCount += 1
        updateBroadcastMetadataConfigs.append(config)
        updateBroadcastMetadataAccessTokens.append(accessToken)

        switch updateBroadcastMetadataResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func uploadThumbnail(broadcastId: String, imageData: Data, mimeType: String, accessToken: String) async throws {
        uploadThumbnailCallCount += 1
        uploadThumbnailBroadcastIds.append(broadcastId)
        uploadThumbnailImageData.append(imageData)
        uploadThumbnailMimeTypes.append(mimeType)
        uploadThumbnailAccessTokens.append(accessToken)

        if let error = uploadThumbnailError {
            throw error
        }
    }

    func getLiveChatId(broadcastId: String, accessToken: String) async throws -> String {
        getLiveChatIdCallCount += 1
        getLiveChatIdBroadcastIds.append(broadcastId)
        getLiveChatIdAccessTokens.append(accessToken)

        switch getLiveChatIdResult {
        case .success(let chatId):
            return chatId
        case .failure(let error):
            throw error
        }
    }

    func fetchLiveChatMessages(liveChatId: String, pageToken: String?, accessToken: String) async throws -> YouTubeLiveChatMessagesResponse {
        fetchLiveChatMessagesCallCount += 1
        fetchLiveChatMessagesLiveChatIds.append(liveChatId)
        fetchLiveChatMessagesPageTokens.append(pageToken)
        fetchLiveChatMessagesAccessTokens.append(accessToken)

        switch fetchLiveChatMessagesResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}
