import Foundation
import UIKit
@testable import blurCam

/// Mock implementation of PhotoRepositoryProtocol for testing
final class MockPhotoRepository: PhotoRepositoryProtocol, @unchecked Sendable {

    // MARK: - Configurable Behavior

    var savePhotoError: Error?
    var savedPhotoData: [Data] = []
    var saveVideoError: Error?
    var savedVideoURLs: [URL] = []
    var latestMediaItem: MediaItem?
    var fullImage: UIImage?
    var videoURL: URL?

    // MARK: - Call Tracking

    var savePhotoCallCount = 0
    var saveVideoCallCount = 0
    var fetchLatestMediaCallCount = 0
    var fetchFullImageCallCount = 0
    var fetchFullImageIdentifiers: [String] = []
    var fetchVideoURLCallCount = 0
    var fetchVideoURLIdentifiers: [String] = []

    // MARK: - PhotoRepositoryProtocol

    func savePhoto(_ imageData: Data) async throws {
        savePhotoCallCount += 1
        if let error = savePhotoError {
            throw error
        }
        savedPhotoData.append(imageData)
    }

    func saveVideo(_ videoURL: URL) async throws {
        saveVideoCallCount += 1
        if let error = saveVideoError {
            throw error
        }
        savedVideoURLs.append(videoURL)
    }

    func fetchLatestMedia() async -> MediaItem? {
        fetchLatestMediaCallCount += 1
        return latestMediaItem
    }

    func fetchFullImage(for identifier: String) async -> UIImage? {
        fetchFullImageCallCount += 1
        fetchFullImageIdentifiers.append(identifier)
        return fullImage
    }

    func fetchVideoURL(for identifier: String) async -> URL? {
        fetchVideoURLCallCount += 1
        fetchVideoURLIdentifiers.append(identifier)
        return videoURL
    }
}
