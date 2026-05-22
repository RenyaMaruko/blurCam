import Foundation
import UIKit

/// Represents a captured media item (photo or video) for preview display
struct MediaItem: Equatable, Identifiable {
    let id: String
    /// The type of media
    let mediaType: MediaType
    /// Thumbnail image for display in the camera UI
    let thumbnail: UIImage?
    /// URL for video playback (nil for photos)
    let videoURL: URL?
    /// Full-resolution image data for photo preview (nil for videos)
    let fullImage: UIImage?

    enum MediaType: Equatable {
        case photo
        case video
    }

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.id == rhs.id && lhs.mediaType == rhs.mediaType
    }
}
