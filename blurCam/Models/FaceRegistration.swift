import Foundation

/// Represents a registered face with its associated data.
/// Stored locally on the device using Codable serialization.
struct FaceRegistration: Codable, Equatable {
    /// Unique identifier for this registration
    let id: UUID

    /// Date when the face was registered
    let registeredAt: Date

    /// File name of the stored face image (relative to the face data directory)
    let imageFileName: String

    /// Creates a new face registration
    init(id: UUID = UUID(), registeredAt: Date = Date(), imageFileName: String) {
        self.id = id
        self.registeredAt = registeredAt
        self.imageFileName = imageFileName
    }
}
