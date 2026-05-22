import Foundation

/// Error types for face repository operations
enum FaceRepositoryError: LocalizedError, Equatable {
    case directoryCreationFailed(String)
    case imageSaveFailed(String)
    case registrationSaveFailed(String)
    case deleteFailed(String)
    case invalidData
    case faceNotFound

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let message):
            return "顔データディレクトリの作成に失敗しました: \(message)"
        case .imageSaveFailed(let message):
            return "顔画像の保存に失敗しました: \(message)"
        case .registrationSaveFailed(let message):
            return "顔登録データの保存に失敗しました: \(message)"
        case .deleteFailed(let message):
            return "顔データの削除に失敗しました: \(message)"
        case .invalidData:
            return "無効な顔データです"
        case .faceNotFound:
            return "指定された顔データが見つかりません"
        }
    }
}

/// Concrete implementation of FaceRepositoryProtocol using FileManager.
/// Stores face data in the app's Application Support directory.
/// Data is stored locally only and never transmitted externally.
/// Supports multiple face registrations stored in a single JSON array file.
final class FaceRepository: FaceRepositoryProtocol {

    // MARK: - Constants

    private static let directoryName = "FaceData"
    private static let registrationFileName = "registration.json"
    private static let registrationsFileName = "registrations.json"

    // MARK: - Properties

    private let fileManager: FileManager
    private let baseDirectory: URL

    // MARK: - Initialization

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        // Use Application Support directory for app data
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.baseDirectory = appSupport.appendingPathComponent(Self.directoryName, isDirectory: true)
    }

    /// Initializer for testing that allows custom base directory
    init(fileManager: FileManager = .default, baseDirectory: URL) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
    }

    // MARK: - FaceRepositoryProtocol

    func hasFaceRegistered() -> Bool {
        let registrations = loadAllRegistrations()
        return !registrations.isEmpty
    }

    @discardableResult
    func saveFace(_ imageData: Data) throws -> FaceRegistration {
        guard !imageData.isEmpty else {
            throw FaceRepositoryError.invalidData
        }

        // Ensure directory exists
        try ensureDirectoryExists()

        // Generate unique file name for the image
        let imageFileName = UUID().uuidString + ".jpg"
        let imageURL = baseDirectory.appendingPathComponent(imageFileName)

        // Save image data
        do {
            try imageData.write(to: imageURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw FaceRepositoryError.imageSaveFailed(error.localizedDescription)
        }

        // Create registration and add to list
        let registration = FaceRegistration(imageFileName: imageFileName)
        var registrations = loadAllRegistrations()
        registrations.append(registration)
        try saveRegistrations(registrations)

        // Also maintain backward-compatible single registration file
        // (first registration is written as the legacy format)
        if registrations.count == 1 {
            try saveLegacyRegistration(registration)
        }

        return registration
    }

    func loadRegistration() -> FaceRegistration? {
        // Try loading from the new multi-face file first
        let registrations = loadAllRegistrations()
        if let first = registrations.first {
            return first
        }

        // Fall back to legacy single registration file
        return loadLegacyRegistration()
    }

    func loadAllRegistrations() -> [FaceRegistration] {
        let registrationsURL = baseDirectory.appendingPathComponent(Self.registrationsFileName)

        if fileManager.fileExists(atPath: registrationsURL.path) {
            guard let data = try? Data(contentsOf: registrationsURL),
                  let registrations = try? JSONDecoder().decode([FaceRegistration].self, from: data) else {
                return []
            }
            return registrations
        }

        // Fall back to legacy single registration
        if let legacy = loadLegacyRegistration() {
            return [legacy]
        }

        return []
    }

    func loadFaceImage(for registration: FaceRegistration) -> Data? {
        let imageURL = baseDirectory.appendingPathComponent(registration.imageFileName)

        guard fileManager.fileExists(atPath: imageURL.path) else {
            return nil
        }

        return try? Data(contentsOf: imageURL)
    }

    func deleteFace(id: UUID) throws {
        var registrations = loadAllRegistrations()
        guard let index = registrations.firstIndex(where: { $0.id == id }) else {
            throw FaceRepositoryError.faceNotFound
        }

        let registration = registrations[index]

        // Remove the image file
        let imageURL = baseDirectory.appendingPathComponent(registration.imageFileName)
        if fileManager.fileExists(atPath: imageURL.path) {
            do {
                try fileManager.removeItem(at: imageURL)
            } catch {
                throw FaceRepositoryError.deleteFailed(error.localizedDescription)
            }
        }

        // Remove from registrations list
        registrations.remove(at: index)

        if registrations.isEmpty {
            // If no more registrations, clean up everything
            try deleteAll()
        } else {
            // Save updated registrations
            try saveRegistrations(registrations)
        }
    }

    func deleteAll() throws {
        guard fileManager.fileExists(atPath: baseDirectory.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: baseDirectory)
        } catch {
            throw FaceRepositoryError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    private func ensureDirectoryExists() throws {
        guard !fileManager.fileExists(atPath: baseDirectory.path) else {
            return
        }

        do {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        } catch {
            throw FaceRepositoryError.directoryCreationFailed(error.localizedDescription)
        }
    }

    private func saveRegistrations(_ registrations: [FaceRegistration]) throws {
        try ensureDirectoryExists()
        let registrationsURL = baseDirectory.appendingPathComponent(Self.registrationsFileName)

        do {
            let data = try JSONEncoder().encode(registrations)
            try data.write(to: registrationsURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw FaceRepositoryError.registrationSaveFailed(error.localizedDescription)
        }
    }

    // MARK: - Legacy Support

    private func saveLegacyRegistration(_ registration: FaceRegistration) throws {
        let registrationURL = baseDirectory.appendingPathComponent(Self.registrationFileName)

        do {
            let data = try JSONEncoder().encode(registration)
            try data.write(to: registrationURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw FaceRepositoryError.registrationSaveFailed(error.localizedDescription)
        }
    }

    private func loadLegacyRegistration() -> FaceRegistration? {
        let registrationURL = baseDirectory.appendingPathComponent(Self.registrationFileName)

        guard fileManager.fileExists(atPath: registrationURL.path) else {
            return nil
        }

        guard let data = try? Data(contentsOf: registrationURL) else {
            return nil
        }

        return try? JSONDecoder().decode(FaceRegistration.self, from: data)
    }
}
