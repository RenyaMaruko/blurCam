import Foundation

/// Protocol abstracting face registration data access.
/// Allows swapping implementations for testing or future changes.
/// All data operations are local-only; no external network calls are made.
protocol FaceRepositoryProtocol: Sendable {
    /// Returns whether at least one face has been registered
    func hasFaceRegistered() -> Bool

    /// Saves face image data and creates a registration record.
    /// - Parameter imageData: The JPEG image data of the captured face
    /// - Returns: The created FaceRegistration record
    /// - Throws: FaceRepositoryError if saving fails
    @discardableResult
    func saveFace(_ imageData: Data) throws -> FaceRegistration

    /// Loads the current face registration, if one exists (first registered face)
    func loadRegistration() -> FaceRegistration?

    /// Loads all face registrations
    func loadAllRegistrations() -> [FaceRegistration]

    /// Loads the face image data for the given registration
    /// - Parameter registration: The face registration whose image to load
    /// - Returns: The image data, or nil if not found
    func loadFaceImage(for registration: FaceRegistration) -> Data?

    /// Deletes a specific face registration by its ID
    /// - Parameter id: The UUID of the face registration to delete
    /// - Throws: FaceRepositoryError if deletion fails
    func deleteFace(id: UUID) throws

    /// Deletes all face registration data (registration record + image)
    func deleteAll() throws
}
