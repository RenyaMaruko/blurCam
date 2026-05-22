import Foundation
import SwiftUI

/// ViewModel responsible for managing the settings screen state.
/// Handles face management (list, add, delete) and blur intensity settings.
@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Registered face groups (each person = 1 group with multiple photos)
    @Published private(set) var registeredFaces: [FaceGroupEntry] = []

    /// Current blur intensity setting
    @Published var blurIntensity: BlurIntensity = .medium {
        didSet {
            blurSettingsRepository.saveBlurIntensity(blurIntensity)
            onBlurIntensityChanged?(blurIntensity)
        }
    }

    /// Whether a confirmation dialog for face deletion is shown
    @Published var showDeleteConfirmation: Bool = false

    /// The face group pending deletion (used with confirmation dialog)
    @Published var faceToDelete: FaceGroupEntry?

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

    /// Reloads the list of registered faces, grouped by person
    func loadFaces() {
        let registrations = faceRepository.loadAllRegistrations()

        // Group by groupId
        var groups: [UUID: [FaceRegistration]] = [:]
        for reg in registrations {
            groups[reg.groupId, default: []].append(reg)
        }

        registeredFaces = groups.map { (groupId, regs) in
            // Use the first registration's image as thumbnail
            let firstReg = regs.sorted { $0.registeredAt < $1.registeredAt }.first!
            let thumbnailData = faceRepository.loadFaceImage(for: firstReg)
            return FaceGroupEntry(
                groupId: groupId,
                registrationIds: regs.map { $0.id },
                registeredAt: firstReg.registeredAt,
                photoCount: regs.count,
                thumbnailData: thumbnailData
            )
        }.sorted { $0.registeredAt < $1.registeredAt }
    }

    /// Initiates face group deletion by showing a confirmation dialog
    func requestDeleteFace(_ face: FaceGroupEntry) {
        faceToDelete = face
        showDeleteConfirmation = true
    }

    /// Confirms deletion of the pending face group (all photos of that person)
    func confirmDeleteFace() {
        guard let face = faceToDelete else { return }

        do {
            for regId in face.registrationIds {
                try faceRepository.deleteFace(id: regId)
            }
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

/// Represents a group of registered face photos (one person) for display in settings
struct FaceGroupEntry: Identifiable, Equatable {
    let groupId: UUID
    let registrationIds: [UUID]
    let registeredAt: Date
    let photoCount: Int
    let thumbnailData: Data?

    var id: UUID { groupId }

    static func == (lhs: FaceGroupEntry, rhs: FaceGroupEntry) -> Bool {
        lhs.groupId == rhs.groupId
    }
}
