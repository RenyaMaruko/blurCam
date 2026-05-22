import Foundation
import SwiftUI

/// ViewModel responsible for managing the settings screen state.
/// Handles face management (list, add, delete) and blur intensity settings.
@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    /// All registered faces with their thumbnail image data
    @Published private(set) var registeredFaces: [FaceEntry] = []

    /// Current blur intensity setting
    @Published var blurIntensity: BlurIntensity = .medium {
        didSet {
            blurSettingsRepository.saveBlurIntensity(blurIntensity)
            onBlurIntensityChanged?(blurIntensity)
        }
    }

    /// Whether a confirmation dialog for face deletion is shown
    @Published var showDeleteConfirmation: Bool = false

    /// The face entry pending deletion (used with confirmation dialog)
    @Published var faceToDelete: FaceEntry?

    /// Error message to display
    @Published private(set) var errorMessage: String?

    /// Whether the face addition flow is active
    @Published var isAddingFace: Bool = false

    /// Whether all faces have been deleted (triggers return to onboarding)
    @Published private(set) var allFacesDeleted: Bool = false

    // MARK: - Callbacks

    /// Called when blur intensity changes, so the camera can update
    var onBlurIntensityChanged: ((BlurIntensity) -> Void)?

    /// Called when faces change (added or deleted), so the camera can reload face data
    var onFacesChanged: (() -> Void)?

    // MARK: - Dependencies

    private let faceRepository: FaceRepositoryProtocol
    private let blurSettingsRepository: BlurSettingsRepositoryProtocol

    // MARK: - Initialization

    init(
        faceRepository: FaceRepositoryProtocol = FaceRepository(),
        blurSettingsRepository: BlurSettingsRepositoryProtocol = BlurSettingsRepository()
    ) {
        self.faceRepository = faceRepository
        self.blurSettingsRepository = blurSettingsRepository

        // Load saved blur intensity
        if let savedIntensity = blurSettingsRepository.loadBlurIntensity() {
            // Use _blurIntensity to avoid triggering didSet during init
            _blurIntensity = Published(wrappedValue: savedIntensity)
        }

        loadFaces()
    }

    // MARK: - Public Methods

    /// Reloads the list of registered faces from the repository
    func loadFaces() {
        let registrations = faceRepository.loadAllRegistrations()
        registeredFaces = registrations.map { registration in
            let imageData = faceRepository.loadFaceImage(for: registration)
            return FaceEntry(
                id: registration.id,
                registeredAt: registration.registeredAt,
                imageFileName: registration.imageFileName,
                thumbnailData: imageData
            )
        }
    }

    /// Initiates face deletion by showing a confirmation dialog
    func requestDeleteFace(_ face: FaceEntry) {
        faceToDelete = face
        showDeleteConfirmation = true
    }

    /// Confirms deletion of the pending face
    func confirmDeleteFace() {
        guard let face = faceToDelete else { return }

        do {
            try faceRepository.deleteFace(id: face.id)
            loadFaces()
            errorMessage = nil
            onFacesChanged?()

            if registeredFaces.isEmpty {
                allFacesDeleted = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        faceToDelete = nil
        showDeleteConfirmation = false
    }

    /// Cancels the pending face deletion
    func cancelDeleteFace() {
        faceToDelete = nil
        showDeleteConfirmation = false
    }

    /// Called when a new face has been successfully added via the capture flow
    func onFaceAdded() {
        isAddingFace = false
        loadFaces()
        onFacesChanged?()
    }

    /// Starts the face addition flow
    func startAddingFace() {
        isAddingFace = true
    }

    /// The slider value for the blur intensity (0.0 to 1.0 mapped to low/medium/high)
    var blurSliderValue: Double {
        get {
            Double(blurIntensity.rawValue) / Double(BlurIntensity.allCases.count - 1)
        }
        set {
            let index = Int(round(newValue * Double(BlurIntensity.allCases.count - 1)))
            let clampedIndex = max(0, min(BlurIntensity.allCases.count - 1, index))
            blurIntensity = BlurIntensity.allCases[clampedIndex]
        }
    }
}

// MARK: - Supporting Types

/// Represents a registered face entry for display in the settings screen
struct FaceEntry: Identifiable, Equatable {
    let id: UUID
    let registeredAt: Date
    let imageFileName: String
    let thumbnailData: Data?

    static func == (lhs: FaceEntry, rhs: FaceEntry) -> Bool {
        lhs.id == rhs.id
    }
}
