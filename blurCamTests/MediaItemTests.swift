import UIKit
import XCTest
@testable import blurCam

final class MediaItemTests: XCTestCase {

    // MARK: - Initialization Tests

    func testPhotoItem_Initialization() {
        let thumbnail = UIImage()
        let item = MediaItem(
            id: "photo-123",
            mediaType: .photo,
            thumbnail: thumbnail,
            videoURL: nil,
            fullImage: nil
        )

        XCTAssertEqual(item.id, "photo-123")
        XCTAssertEqual(item.mediaType, .photo)
        XCTAssertNotNil(item.thumbnail)
        XCTAssertNil(item.videoURL)
        XCTAssertNil(item.fullImage)
    }

    func testVideoItem_Initialization() {
        let thumbnail = UIImage()
        let videoURL = URL(fileURLWithPath: "/tmp/test.mp4")
        let item = MediaItem(
            id: "video-456",
            mediaType: .video,
            thumbnail: thumbnail,
            videoURL: videoURL,
            fullImage: nil
        )

        XCTAssertEqual(item.id, "video-456")
        XCTAssertEqual(item.mediaType, .video)
        XCTAssertNotNil(item.thumbnail)
        XCTAssertEqual(item.videoURL, videoURL)
        XCTAssertNil(item.fullImage)
    }

    // MARK: - Equatable Tests

    func testEquatable_SameId_AreEqual() {
        let item1 = MediaItem(
            id: "same-id",
            mediaType: .photo,
            thumbnail: nil,
            videoURL: nil,
            fullImage: nil
        )
        let item2 = MediaItem(
            id: "same-id",
            mediaType: .photo,
            thumbnail: UIImage(),
            videoURL: nil,
            fullImage: nil
        )

        XCTAssertEqual(item1, item2)
    }

    func testEquatable_DifferentId_AreNotEqual() {
        let item1 = MediaItem(
            id: "id-1",
            mediaType: .photo,
            thumbnail: nil,
            videoURL: nil,
            fullImage: nil
        )
        let item2 = MediaItem(
            id: "id-2",
            mediaType: .photo,
            thumbnail: nil,
            videoURL: nil,
            fullImage: nil
        )

        XCTAssertNotEqual(item1, item2)
    }

    func testEquatable_DifferentMediaType_AreNotEqual() {
        let item1 = MediaItem(
            id: "same-id",
            mediaType: .photo,
            thumbnail: nil,
            videoURL: nil,
            fullImage: nil
        )
        let item2 = MediaItem(
            id: "same-id",
            mediaType: .video,
            thumbnail: nil,
            videoURL: nil,
            fullImage: nil
        )

        XCTAssertNotEqual(item1, item2)
    }

    // MARK: - Identifiable Tests

    func testIdentifiable_Id() {
        let item = MediaItem(
            id: "test-id",
            mediaType: .photo,
            thumbnail: nil,
            videoURL: nil,
            fullImage: nil
        )

        XCTAssertEqual(item.id, "test-id")
    }

    // MARK: - MediaType Tests

    func testMediaType_Photo() {
        XCTAssertEqual(MediaItem.MediaType.photo, .photo)
    }

    func testMediaType_Video() {
        XCTAssertEqual(MediaItem.MediaType.video, .video)
    }

    func testMediaType_Equatable() {
        XCTAssertNotEqual(MediaItem.MediaType.photo, MediaItem.MediaType.video)
    }
}
