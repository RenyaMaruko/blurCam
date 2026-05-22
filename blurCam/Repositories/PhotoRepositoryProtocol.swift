import Foundation
import UIKit

/// Protocol abstracting photo and video storage operations.
/// Allows swapping implementations for testing or future changes.
protocol PhotoRepositoryProtocol: Sendable {
    /// Saves the given image data to the photo library.
    /// - Parameter imageData: JPEG/HEIF image data to save
    func savePhoto(_ imageData: Data) async throws

    /// Saves the given video file to the photo library.
    /// - Parameter videoURL: Local file URL of the video to save
    func saveVideo(_ videoURL: URL) async throws

    /// Fetches the most recently captured media item from the photo library.
    /// - Returns: The latest MediaItem, or nil if the library is empty or inaccessible
    func fetchLatestMedia() async -> MediaItem?

    /// Fetches the full-resolution image for a photo asset by its local identifier.
    /// - Parameter identifier: The PHAsset local identifier
    /// - Returns: The full-resolution UIImage, or nil if not found
    func fetchFullImage(for identifier: String) async -> UIImage?

    /// Fetches the video URL for a video asset by its local identifier.
    /// - Parameter identifier: The PHAsset local identifier
    /// - Returns: The video URL, or nil if not found
    func fetchVideoURL(for identifier: String) async -> URL?
}
