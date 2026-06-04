import Foundation

/// Protocol for YouTube Data API v3 Live Streaming operations
protocol YouTubeAPIServiceProtocol {
    /// Create a new broadcast (liveBroadcasts.insert)
    func createBroadcast(config: YouTubeBroadcastConfig, accessToken: String) async throws -> YouTubeBroadcastResponse

    /// Create a new stream (liveStreams.insert)
    func createStream(config: YouTubeStreamConfig, accessToken: String) async throws -> YouTubeStreamResponse

    /// Bind a broadcast to a stream (liveBroadcasts.bind)
    func bindBroadcastToStream(broadcastId: String, streamId: String, accessToken: String) async throws -> YouTubeBindResponse

    /// Create broadcast + stream, bind them, and return RTMP info
    func setupLiveStream(
        broadcastConfig: YouTubeBroadcastConfig,
        streamConfig: YouTubeStreamConfig,
        accessToken: String
    ) async throws -> YouTubeRTMPInfo

    /// Transition a broadcast to a new status (liveBroadcasts.transition)
    func transitionBroadcast(broadcastId: String, toStatus: String, accessToken: String) async throws -> YouTubeBroadcastResponse

    /// Get the current health status of a live stream (liveStreams.list)
    func getStreamHealth(streamId: String, accessToken: String) async throws -> YouTubeStreamHealthStatus

    /// Update broadcast metadata (liveBroadcasts.update)
    func updateBroadcastMetadata(config: YouTubeBroadcastUpdateConfig, accessToken: String) async throws -> YouTubeBroadcastResponse

    /// Upload a thumbnail for a broadcast (thumbnails.set)
    func uploadThumbnail(broadcastId: String, imageData: Data, mimeType: String, accessToken: String) async throws

    /// Get the liveChatId for a broadcast (liveBroadcasts.list with snippet part)
    func getLiveChatId(broadcastId: String, accessToken: String) async throws -> String

    /// Fetch live chat messages (liveChatMessages.list)
    func fetchLiveChatMessages(liveChatId: String, pageToken: String?, accessToken: String) async throws -> YouTubeLiveChatMessagesResponse
}

/// Service for interacting with YouTube Data API v3 Live Streaming endpoints.
/// Handles broadcast creation, stream creation, and binding operations.
final class YouTubeAPIService: YouTubeAPIServiceProtocol {

    // MARK: - Constants

    private let baseURL = "https://www.googleapis.com/youtube/v3"
    private let session: URLSession

    // MARK: - Initialization

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public Methods

    func createBroadcast(config: YouTubeBroadcastConfig, accessToken: String) async throws -> YouTubeBroadcastResponse {
        let url = "\(baseURL)/liveBroadcasts?part=snippet,status,contentDetails"

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var snippet: [String: Any] = [
            "title": config.title,
            "description": config.description,
            "scheduledStartTime": isoFormatter.string(from: config.scheduledStartTime)
        ]

        // Add category ID if specified
        if let categoryId = config.categoryId {
            snippet["categoryId"] = categoryId
        }

        var contentDetails: [String: Any] = [
            "enableAutoStart": true,
            "enableAutoStop": true,
            "enableDvr": config.enableDVR,
            "enableLowLatency": (config.latencyPreference == "low" || config.latencyPreference == "ultraLow")
        ]

        // Add latency preference if specified
        if let latencyPreference = config.latencyPreference {
            contentDetails["latencyPreference"] = latencyPreference
        }

        // Add chat enable/disable
        contentDetails["enableClosedCaptions"] = false

        let body: [String: Any] = [
            "snippet": snippet,
            "status": [
                "privacyStatus": config.privacy.rawValue,
                "selfDeclaredMadeForKids": false
            ],
            "contentDetails": contentDetails
        ]

        let data = try await performRequest(
            url: url,
            method: "POST",
            body: body,
            accessToken: accessToken
        )

        do {
            let response = try JSONDecoder().decode(YouTubeBroadcastResponse.self, from: data)
            return response
        } catch {
            throw YouTubeAPIError.invalidResponse("Broadcast response: \(error.localizedDescription)")
        }
    }

    func createStream(config: YouTubeStreamConfig, accessToken: String) async throws -> YouTubeStreamResponse {
        let url = "\(baseURL)/liveStreams?part=snippet,cdn,status"

        let body: [String: Any] = [
            "snippet": [
                "title": config.title
            ],
            "cdn": [
                "ingestionType": config.ingestionType,
                "resolution": config.resolution,
                "frameRate": config.frameRate
            ]
        ]

        let data = try await performRequest(
            url: url,
            method: "POST",
            body: body,
            accessToken: accessToken
        )

        do {
            let response = try JSONDecoder().decode(YouTubeStreamResponse.self, from: data)
            return response
        } catch {
            throw YouTubeAPIError.invalidResponse("Stream response: \(error.localizedDescription)")
        }
    }

    func bindBroadcastToStream(broadcastId: String, streamId: String, accessToken: String) async throws -> YouTubeBindResponse {
        let url = "\(baseURL)/liveBroadcasts/bind?id=\(broadcastId)&part=id,contentDetails&streamId=\(streamId)"

        let data = try await performRequest(
            url: url,
            method: "POST",
            body: nil,
            accessToken: accessToken
        )

        do {
            let response = try JSONDecoder().decode(YouTubeBindResponse.self, from: data)
            return response
        } catch {
            throw YouTubeAPIError.invalidResponse("Bind response: \(error.localizedDescription)")
        }
    }

    func setupLiveStream(
        broadcastConfig: YouTubeBroadcastConfig,
        streamConfig: YouTubeStreamConfig,
        accessToken: String
    ) async throws -> YouTubeRTMPInfo {
        // Step 1: Create broadcast
        let broadcast: YouTubeBroadcastResponse
        do {
            broadcast = try await createBroadcast(config: broadcastConfig, accessToken: accessToken)
        } catch let error as YouTubeAPIError {
            throw error
        } catch {
            throw YouTubeAPIError.broadcastCreationFailed(error.localizedDescription)
        }

        // Step 2: Create stream
        let stream: YouTubeStreamResponse
        do {
            stream = try await createStream(config: streamConfig, accessToken: accessToken)
        } catch let error as YouTubeAPIError {
            throw error
        } catch {
            throw YouTubeAPIError.streamCreationFailed(error.localizedDescription)
        }

        // Step 3: Bind broadcast to stream
        do {
            _ = try await bindBroadcastToStream(
                broadcastId: broadcast.id,
                streamId: stream.id,
                accessToken: accessToken
            )
        } catch let error as YouTubeAPIError {
            throw error
        } catch {
            throw YouTubeAPIError.bindFailed(error.localizedDescription)
        }

        // Step 4: Extract RTMP info from stream response
        guard let ingestionInfo = stream.cdn?.ingestionInfo,
              let rtmpURL = ingestionInfo.ingestionAddress,
              let streamKey = ingestionInfo.streamName,
              !rtmpURL.isEmpty,
              !streamKey.isEmpty else {
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
        let url = "\(baseURL)/liveBroadcasts/transition?broadcastStatus=\(toStatus)&id=\(broadcastId)&part=id,status,snippet"

        let data = try await performRequest(
            url: url,
            method: "POST",
            body: nil,
            accessToken: accessToken
        )

        do {
            let response = try JSONDecoder().decode(YouTubeBroadcastResponse.self, from: data)
            return response
        } catch {
            throw YouTubeAPIError.transitionFailed("Response parse: \(error.localizedDescription)")
        }
    }

    func getStreamHealth(streamId: String, accessToken: String) async throws -> YouTubeStreamHealthStatus {
        let url = "\(baseURL)/liveStreams?part=status&id=\(streamId)"

        let data = try await performRequest(
            url: url,
            method: "GET",
            body: nil,
            accessToken: accessToken
        )

        // Parse the liveStreams.list response
        struct StreamListResponse: Codable {
            let items: [YouTubeStreamResponse]?
        }

        do {
            let response = try JSONDecoder().decode(StreamListResponse.self, from: data)
            guard let stream = response.items?.first,
                  let healthStatusString = stream.status?.healthStatus?.status else {
                return .noData
            }
            return YouTubeStreamHealthStatus(rawValue: healthStatusString) ?? .noData
        } catch {
            throw YouTubeAPIError.invalidResponse("Stream health: \(error.localizedDescription)")
        }
    }

    func updateBroadcastMetadata(config: YouTubeBroadcastUpdateConfig, accessToken: String) async throws -> YouTubeBroadcastResponse {
        let url = "\(baseURL)/liveBroadcasts?part=snippet"

        let body: [String: Any] = [
            "id": config.broadcastId,
            "snippet": [
                "title": config.title,
                "description": config.description,
                "scheduledStartTime": ISO8601DateFormatter().string(from: Date())
            ]
        ]

        let data = try await performRequest(
            url: url,
            method: "PUT",
            body: body,
            accessToken: accessToken
        )

        do {
            let response = try JSONDecoder().decode(YouTubeBroadcastResponse.self, from: data)
            return response
        } catch {
            throw YouTubeAPIError.invalidResponse("Broadcast update: \(error.localizedDescription)")
        }
    }

    func uploadThumbnail(broadcastId: String, imageData: Data, mimeType: String, accessToken: String) async throws {
        let urlString = "https://www.googleapis.com/upload/youtube/v3/thumbnails/set?videoId=\(broadcastId)&uploadType=media"

        guard let url = URL(string: urlString) else {
            throw YouTubeAPIError.thumbnailUploadFailed("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(imageData.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = imageData

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw YouTubeAPIError.thumbnailUploadFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw YouTubeAPIError.thumbnailUploadFailed("Non-HTTP response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return // Success
        case 401:
            throw YouTubeAPIError.authenticationError("認証が無効です")
        case 403:
            let errorMessage = parseErrorMessage(from: data) ?? ""
            if errorMessage.lowercased().contains("quota") ||
                parseErrorReason(from: data) == "quotaExceeded" {
                throw YouTubeAPIError.quotaExceeded
            }
            throw YouTubeAPIError.thumbnailUploadFailed(errorMessage)
        default:
            let errorMessage = parseErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw YouTubeAPIError.thumbnailUploadFailed(errorMessage)
        }
    }

    func getLiveChatId(broadcastId: String, accessToken: String) async throws -> String {
        let url = "\(baseURL)/liveBroadcasts?part=snippet,contentDetails&id=\(broadcastId)"

        let data = try await performRequest(
            url: url,
            method: "GET",
            body: nil,
            accessToken: accessToken
        )

        do {
            let response = try JSONDecoder().decode(YouTubeBroadcastListResponse.self, from: data)
            // Extract liveChatId from snippet
            // The YouTube API returns liveChatId in snippet for broadcasts with chat enabled
            guard let broadcast = response.items?.first else {
                throw YouTubeAPIError.invalidResponse("Broadcast not found for ID: \(broadcastId)")
            }

            // liveChatId is in snippet for the broadcast
            // We need to parse it from the raw JSON since our model may not have it
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = json["items"] as? [[String: Any]],
               let firstItem = items.first,
               let snippet = firstItem["snippet"] as? [String: Any],
               let liveChatId = snippet["liveChatId"] as? String,
               !liveChatId.isEmpty {
                return liveChatId
            }

            throw YouTubeAPIError.invalidResponse("liveChatId not available for broadcast: \(broadcast.id)")
        } catch let error as YouTubeAPIError {
            throw error
        } catch {
            throw YouTubeAPIError.invalidResponse("LiveChatId response: \(error.localizedDescription)")
        }
    }

    func fetchLiveChatMessages(liveChatId: String, pageToken: String?, accessToken: String) async throws -> YouTubeLiveChatMessagesResponse {
        var urlString = "\(baseURL)/liveChat/messages?liveChatId=\(liveChatId)&part=snippet,authorDetails&maxResults=200"

        if let pageToken = pageToken, !pageToken.isEmpty {
            urlString += "&pageToken=\(pageToken)"
        }

        let data = try await performRequest(
            url: urlString,
            method: "GET",
            body: nil,
            accessToken: accessToken
        )

        do {
            let response = try JSONDecoder().decode(YouTubeLiveChatMessagesResponse.self, from: data)
            return response
        } catch {
            throw YouTubeAPIError.invalidResponse("LiveChat messages: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func performRequest(
        url urlString: String,
        method: String,
        body: [String: Any]?,
        accessToken: String
    ) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw YouTubeAPIError.invalidResponse("Invalid URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw YouTubeAPIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw YouTubeAPIError.invalidResponse("Non-HTTP response")
        }

        // Handle HTTP error codes
        switch httpResponse.statusCode {
        case 200...299:
            return data

        case 401:
            let errorMessage = parseErrorMessage(from: data) ?? "認証が無効です"
            throw YouTubeAPIError.authenticationError(errorMessage)

        case 403:
            let errorMessage = parseErrorMessage(from: data) ?? ""
            if errorMessage.lowercased().contains("quota") ||
                parseErrorReason(from: data) == "quotaExceeded" {
                throw YouTubeAPIError.quotaExceeded
            }
            throw YouTubeAPIError.authenticationError(errorMessage)

        case 404:
            let errorMessage = parseErrorMessage(from: data) ?? "リソースが見つかりません"
            throw YouTubeAPIError.invalidResponse(errorMessage)

        default:
            let errorMessage = parseErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw YouTubeAPIError.unknown(errorMessage)
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        let errorResponse = try? JSONDecoder().decode(YouTubeAPIErrorResponse.self, from: data)
        return errorResponse?.error?.message
    }

    private func parseErrorReason(from data: Data) -> String? {
        let errorResponse = try? JSONDecoder().decode(YouTubeAPIErrorResponse.self, from: data)
        return errorResponse?.error?.errors?.first?.reason
    }
}
