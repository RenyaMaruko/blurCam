import XCTest
@testable import blurCam

/// Tests for YouTubeLiveChatService polling and message delivery
final class YouTubeLiveChatServiceTests: XCTestCase {

    private var mockAPIService: MockYouTubeAPIService!
    private var mockAuthService: MockGoogleAuthService!
    private var chatService: YouTubeLiveChatService!

    override func setUp() {
        super.setUp()
        mockAPIService = MockYouTubeAPIService()
        mockAuthService = MockGoogleAuthService()
        mockAuthService.accessToken = "test-access-token"
        chatService = YouTubeLiveChatService(
            apiService: mockAPIService,
            authService: mockAuthService
        )
    }

    override func tearDown() {
        chatService.stopPolling()
        chatService = nil
        mockAPIService = nil
        mockAuthService = nil
        super.tearDown()
    }

    // MARK: - startPolling Tests

    func testStartPolling_getsLiveChatIdAndStartsPolling() async throws {
        mockAPIService.getLiveChatIdResult = .success("chat-id-123")

        try await chatService.startPolling(broadcastId: "broadcast-123", accessToken: "token")

        XCTAssertTrue(chatService.isPolling)
        XCTAssertEqual(mockAPIService.getLiveChatIdCallCount, 1)
        XCTAssertEqual(mockAPIService.getLiveChatIdBroadcastIds.first, "broadcast-123")
    }

    func testStartPolling_throwsWhenLiveChatIdNotAvailable() async {
        mockAPIService.getLiveChatIdResult = .failure(YouTubeAPIError.invalidResponse("No chat"))

        do {
            try await chatService.startPolling(broadcastId: "broadcast-123", accessToken: "token")
            XCTFail("Expected error")
        } catch {
            XCTAssertFalse(chatService.isPolling)
        }
    }

    func testStartPolling_doesNotStartTwice() async throws {
        mockAPIService.getLiveChatIdResult = .success("chat-id-123")

        try await chatService.startPolling(broadcastId: "broadcast-123", accessToken: "token")
        try await chatService.startPolling(broadcastId: "broadcast-456", accessToken: "token")

        // Should only call getLiveChatId once since second call is guarded
        XCTAssertEqual(mockAPIService.getLiveChatIdCallCount, 1)
    }

    // MARK: - startPollingWithChatId Tests

    func testStartPollingWithChatId_startsPolling() {
        chatService.startPollingWithChatId("chat-id-abc", accessToken: "token")

        XCTAssertTrue(chatService.isPolling)
    }

    func testStartPollingWithChatId_doesNotStartTwice() {
        chatService.startPollingWithChatId("chat-id-abc", accessToken: "token")
        chatService.startPollingWithChatId("chat-id-def", accessToken: "token")

        // Second call is guarded
        XCTAssertTrue(chatService.isPolling)
    }

    // MARK: - stopPolling Tests

    func testStopPolling_stopsAndCleansUp() async throws {
        mockAPIService.getLiveChatIdResult = .success("chat-id-123")
        try await chatService.startPolling(broadcastId: "broadcast-123", accessToken: "token")

        chatService.stopPolling()

        XCTAssertFalse(chatService.isPolling)
    }

    // MARK: - Message Delivery Tests

    func testNewMessages_deliveredViaCallback() async throws {
        let expectation = XCTestExpectation(description: "Messages delivered")

        let mockMessages = [
            YouTubeLiveChatMessageItem(
                kind: "youtube#liveChatMessage",
                etag: "etag1",
                id: "msg-1",
                snippet: YouTubeLiveChatMessageItem.ChatMessageSnippet(
                    type: "textMessageEvent",
                    liveChatId: "chat-id",
                    authorChannelId: "channel-1",
                    publishedAt: "2026-01-01T00:00:00Z",
                    hasDisplayContent: true,
                    displayMessage: "Hello World",
                    textMessageDetails: YouTubeLiveChatMessageItem.ChatMessageSnippet.TextMessageDetails(
                        messageText: "Hello World"
                    ),
                    superChatDetails: nil
                ),
                authorDetails: YouTubeLiveChatMessageItem.ChatAuthorDetails(
                    channelId: "channel-1",
                    channelUrl: nil,
                    displayName: "TestUser",
                    profileImageUrl: nil,
                    isVerified: false,
                    isChatOwner: false,
                    isChatSponsor: false,
                    isChatModerator: false
                )
            )
        ]

        mockAPIService.fetchLiveChatMessagesResult = .success(
            YouTubeLiveChatMessagesResponse(
                kind: "youtube#liveChatMessageListResponse",
                etag: "etag",
                nextPageToken: "token-2",
                pollingIntervalMillis: 5000,
                pageInfo: nil,
                items: mockMessages
            )
        )

        var receivedMessages: [LiveChatMessage] = []
        chatService.onNewMessages = { messages in
            receivedMessages = messages
            expectation.fulfill()
        }

        chatService.startPollingWithChatId("chat-id", accessToken: "token")

        await fulfillment(of: [expectation], timeout: 8.0)

        XCTAssertEqual(receivedMessages.count, 1)
        XCTAssertEqual(receivedMessages.first?.authorName, "TestUser")
        XCTAssertEqual(receivedMessages.first?.message, "Hello World")
    }

    // MARK: - Error Handling Tests

    func testPollingError_reportedButContinues() async {
        let expectation = XCTestExpectation(description: "Error reported")

        mockAPIService.fetchLiveChatMessagesResult = .failure(
            YouTubeAPIError.networkError("timeout")
        )

        var receivedError: Error?
        chatService.onError = { error in
            receivedError = error
            expectation.fulfill()
        }

        chatService.startPollingWithChatId("chat-id", accessToken: "token")

        await fulfillment(of: [expectation], timeout: 8.0)

        XCTAssertNotNil(receivedError)
        XCTAssertTrue(chatService.isPolling, "Should continue polling after error")
    }
}

// MARK: - LiveChatMessage Model Tests

final class LiveChatMessageModelTests: XCTestCase {

    func testLiveChatMessage_initFromAPIItem() {
        let item = YouTubeLiveChatMessageItem(
            kind: "youtube#liveChatMessage",
            etag: "etag",
            id: "msg-123",
            snippet: YouTubeLiveChatMessageItem.ChatMessageSnippet(
                type: "textMessageEvent",
                liveChatId: "chat-id",
                authorChannelId: "channel-1",
                publishedAt: "2026-01-01T00:00:00Z",
                hasDisplayContent: true,
                displayMessage: "Test message",
                textMessageDetails: YouTubeLiveChatMessageItem.ChatMessageSnippet.TextMessageDetails(
                    messageText: "Test message"
                ),
                superChatDetails: nil
            ),
            authorDetails: YouTubeLiveChatMessageItem.ChatAuthorDetails(
                channelId: "channel-1",
                channelUrl: nil,
                displayName: "User1",
                profileImageUrl: nil,
                isVerified: false,
                isChatOwner: false,
                isChatSponsor: false,
                isChatModerator: true
            )
        )

        let message = LiveChatMessage(from: item)

        XCTAssertEqual(message.id, "msg-123")
        XCTAssertEqual(message.authorName, "User1")
        XCTAssertEqual(message.message, "Test message")
        XCTAssertTrue(message.isModerator)
        XCTAssertFalse(message.isOwner)
        XCTAssertFalse(message.isSuperChat)
        XCTAssertNil(message.superChatAmount)
    }

    func testLiveChatMessage_initFromSuperChatItem() {
        let item = YouTubeLiveChatMessageItem(
            kind: "youtube#liveChatMessage",
            etag: "etag",
            id: "msg-sc-1",
            snippet: YouTubeLiveChatMessageItem.ChatMessageSnippet(
                type: "superChatEvent",
                liveChatId: "chat-id",
                authorChannelId: "channel-2",
                publishedAt: "2026-01-01T00:01:00Z",
                hasDisplayContent: true,
                displayMessage: "Great stream!",
                textMessageDetails: nil,
                superChatDetails: YouTubeLiveChatMessageItem.ChatMessageSnippet.SuperChatDetails(
                    amountMicros: "5000000",
                    currency: "USD",
                    amountDisplayString: "$5.00",
                    tier: 2,
                    userComment: "Great stream!"
                )
            ),
            authorDetails: YouTubeLiveChatMessageItem.ChatAuthorDetails(
                channelId: "channel-2",
                channelUrl: nil,
                displayName: "SuperFan",
                profileImageUrl: nil,
                isVerified: false,
                isChatOwner: false,
                isChatSponsor: true,
                isChatModerator: false
            )
        )

        let message = LiveChatMessage(from: item)

        XCTAssertEqual(message.id, "msg-sc-1")
        XCTAssertEqual(message.authorName, "SuperFan")
        XCTAssertEqual(message.message, "Great stream!")
        XCTAssertTrue(message.isSuperChat)
        XCTAssertEqual(message.superChatAmount, "$5.00")
    }

    func testLiveChatMessage_initFromOwnerItem() {
        let item = YouTubeLiveChatMessageItem(
            kind: "youtube#liveChatMessage",
            etag: "etag",
            id: "msg-owner-1",
            snippet: YouTubeLiveChatMessageItem.ChatMessageSnippet(
                type: "textMessageEvent",
                liveChatId: "chat-id",
                authorChannelId: "channel-owner",
                publishedAt: "2026-01-01T00:02:00Z",
                hasDisplayContent: true,
                displayMessage: "Welcome!",
                textMessageDetails: YouTubeLiveChatMessageItem.ChatMessageSnippet.TextMessageDetails(
                    messageText: "Welcome!"
                ),
                superChatDetails: nil
            ),
            authorDetails: YouTubeLiveChatMessageItem.ChatAuthorDetails(
                channelId: "channel-owner",
                channelUrl: nil,
                displayName: "StreamOwner",
                profileImageUrl: nil,
                isVerified: true,
                isChatOwner: true,
                isChatSponsor: false,
                isChatModerator: false
            )
        )

        let message = LiveChatMessage(from: item)

        XCTAssertTrue(message.isOwner)
        XCTAssertFalse(message.isModerator)
    }

    func testLiveChatMessage_directInit() {
        let message = LiveChatMessage(
            id: "test-1",
            authorName: "TestUser",
            message: "Hello",
            isModerator: false,
            isOwner: false,
            isSuperChat: false,
            superChatAmount: nil,
            timestamp: Date()
        )

        XCTAssertEqual(message.id, "test-1")
        XCTAssertEqual(message.authorName, "TestUser")
        XCTAssertEqual(message.message, "Hello")
    }

    func testLiveChatMessage_equatable() {
        let msg1 = LiveChatMessage(id: "1", authorName: "A", message: "Hello")
        let msg2 = LiveChatMessage(id: "1", authorName: "B", message: "World")
        let msg3 = LiveChatMessage(id: "2", authorName: "A", message: "Hello")

        XCTAssertEqual(msg1, msg2, "Messages with same ID should be equal")
        XCTAssertNotEqual(msg1, msg3, "Messages with different IDs should not be equal")
    }

    func testLiveChatMessage_fallbackDisplayMessage() {
        // When displayMessage is nil, should fall back to textMessageDetails
        let item = YouTubeLiveChatMessageItem(
            kind: nil,
            etag: nil,
            id: "msg-fallback",
            snippet: YouTubeLiveChatMessageItem.ChatMessageSnippet(
                type: "textMessageEvent",
                liveChatId: nil,
                authorChannelId: nil,
                publishedAt: nil,
                hasDisplayContent: nil,
                displayMessage: nil,
                textMessageDetails: YouTubeLiveChatMessageItem.ChatMessageSnippet.TextMessageDetails(
                    messageText: "Fallback text"
                ),
                superChatDetails: nil
            ),
            authorDetails: YouTubeLiveChatMessageItem.ChatAuthorDetails(
                channelId: nil,
                channelUrl: nil,
                displayName: "User",
                profileImageUrl: nil,
                isVerified: nil,
                isChatOwner: nil,
                isChatSponsor: nil,
                isChatModerator: nil
            )
        )

        let message = LiveChatMessage(from: item)
        XCTAssertEqual(message.message, "Fallback text")
    }

    func testLiveChatMessage_missingAuthorName() {
        let item = YouTubeLiveChatMessageItem(
            kind: nil,
            etag: nil,
            id: "msg-no-name",
            snippet: nil,
            authorDetails: YouTubeLiveChatMessageItem.ChatAuthorDetails(
                channelId: nil,
                channelUrl: nil,
                displayName: nil,
                profileImageUrl: nil,
                isVerified: nil,
                isChatOwner: nil,
                isChatSponsor: nil,
                isChatModerator: nil
            )
        )

        let message = LiveChatMessage(from: item)
        XCTAssertEqual(message.authorName, "Unknown")
        XCTAssertEqual(message.message, "")
    }
}

// MARK: - YouTubeLiveChatMessagesResponse Codable Tests

final class YouTubeLiveChatMessagesResponseTests: XCTestCase {

    func testDecode_validResponse() throws {
        let json = """
        {
            "kind": "youtube#liveChatMessageListResponse",
            "etag": "etag123",
            "nextPageToken": "nextToken",
            "pollingIntervalMillis": 4000,
            "pageInfo": {
                "totalResults": 2,
                "resultsPerPage": 200
            },
            "items": [
                {
                    "kind": "youtube#liveChatMessage",
                    "etag": "item-etag",
                    "id": "msg-1",
                    "snippet": {
                        "type": "textMessageEvent",
                        "liveChatId": "chat-123",
                        "authorChannelId": "channel-1",
                        "publishedAt": "2026-01-01T00:00:00.000Z",
                        "hasDisplayContent": true,
                        "displayMessage": "Hello!",
                        "textMessageDetails": {
                            "messageText": "Hello!"
                        }
                    },
                    "authorDetails": {
                        "channelId": "channel-1",
                        "displayName": "TestUser",
                        "isChatOwner": false,
                        "isChatModerator": false,
                        "isVerified": false,
                        "isChatSponsor": false
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(YouTubeLiveChatMessagesResponse.self, from: json)

        XCTAssertEqual(response.kind, "youtube#liveChatMessageListResponse")
        XCTAssertEqual(response.nextPageToken, "nextToken")
        XCTAssertEqual(response.pollingIntervalMillis, 4000)
        XCTAssertEqual(response.items?.count, 1)
        XCTAssertEqual(response.items?.first?.id, "msg-1")
        XCTAssertEqual(response.items?.first?.snippet?.displayMessage, "Hello!")
        XCTAssertEqual(response.items?.first?.authorDetails?.displayName, "TestUser")
    }

    func testDecode_emptyItems() throws {
        let json = """
        {
            "kind": "youtube#liveChatMessageListResponse",
            "nextPageToken": "token",
            "pollingIntervalMillis": 5000,
            "items": []
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(YouTubeLiveChatMessagesResponse.self, from: json)

        XCTAssertEqual(response.items?.count, 0)
        XCTAssertEqual(response.pollingIntervalMillis, 5000)
    }

    func testDecode_superChatMessage() throws {
        let json = """
        {
            "kind": "youtube#liveChatMessageListResponse",
            "items": [
                {
                    "id": "sc-msg-1",
                    "snippet": {
                        "type": "superChatEvent",
                        "displayMessage": "Great stream!",
                        "superChatDetails": {
                            "amountMicros": "5000000",
                            "currency": "USD",
                            "amountDisplayString": "$5.00",
                            "tier": 2,
                            "userComment": "Great stream!"
                        }
                    },
                    "authorDetails": {
                        "displayName": "SuperFan",
                        "isChatOwner": false,
                        "isChatModerator": false,
                        "isChatSponsor": true
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(YouTubeLiveChatMessagesResponse.self, from: json)

        let item = response.items?.first
        XCTAssertEqual(item?.id, "sc-msg-1")
        XCTAssertEqual(item?.snippet?.superChatDetails?.amountDisplayString, "$5.00")
        XCTAssertEqual(item?.snippet?.superChatDetails?.tier, 2)
    }
}

// MARK: - Mock LiveChatService Tests

final class MockYouTubeLiveChatServiceTests: XCTestCase {

    func testMockService_startPolling() async throws {
        let mockService = MockYouTubeLiveChatService()

        try await mockService.startPolling(broadcastId: "broadcast-1", accessToken: "token")

        XCTAssertTrue(mockService.isPolling)
        XCTAssertEqual(mockService.startPollingCallCount, 1)
        XCTAssertEqual(mockService.startPollingBroadcastIds.first, "broadcast-1")
    }

    func testMockService_stopPolling() async throws {
        let mockService = MockYouTubeLiveChatService()
        try await mockService.startPolling(broadcastId: "broadcast-1", accessToken: "token")

        mockService.stopPolling()

        XCTAssertFalse(mockService.isPolling)
        XCTAssertEqual(mockService.stopPollingCallCount, 1)
    }

    func testMockService_simulateNewMessages() {
        let mockService = MockYouTubeLiveChatService()
        let expectation = XCTestExpectation(description: "Messages received")

        var received: [LiveChatMessage] = []
        mockService.onNewMessages = { messages in
            received = messages
            expectation.fulfill()
        }

        let testMessages = [
            LiveChatMessage(id: "1", authorName: "User1", message: "Hello")
        ]
        mockService.simulateNewMessages(testMessages)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.authorName, "User1")
    }

    func testMockService_startPollingWithError() async {
        let mockService = MockYouTubeLiveChatService()
        mockService.startPollingError = YouTubeAPIError.invalidResponse("no chat")

        do {
            try await mockService.startPolling(broadcastId: "broadcast-1", accessToken: "token")
            XCTFail("Expected error")
        } catch {
            XCTAssertFalse(mockService.isPolling)
        }
    }
}
