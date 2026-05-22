import Foundation
@testable import blurCam

/// Mock implementation of FaceRepositoryProtocol for testing
final class MockFaceRepository: FaceRepositoryProtocol, @unchecked Sendable {

    // MARK: - Configurable State

    var hasRegisteredFace: Bool = false
    var registration: FaceRegistration?
    var registrations: [FaceRegistration] = []
    var faceImageData: Data?
    var faceImageDataMap: [UUID: Data] = [:]
    var saveFaceError: Error?
    var deleteError: Error?
    var deleteFaceError: Error?

    // MARK: - Call Tracking

    var hasFaceRegisteredCallCount = 0
    var saveFaceCallCount = 0
    var loadRegistrationCallCount = 0
    var loadAllRegistrationsCallCount = 0
    var loadFaceImageCallCount = 0
    var deleteAllCallCount = 0
    var deleteFaceCallCount = 0
    var deletedFaceIds: [UUID] = []
    var savedImageData: [Data] = []

    // MARK: - FaceRepositoryProtocol

    func hasFaceRegistered() -> Bool {
        hasFaceRegisteredCallCount += 1
        return hasRegisteredFace
    }

    @discardableResult
    func saveFace(_ imageData: Data) throws -> FaceRegistration {
        saveFaceCallCount += 1
        if let error = saveFaceError {
            throw error
        }
        savedImageData.append(imageData)
        let reg = FaceRegistration(imageFileName: "test-face-\(saveFaceCallCount).jpg")
        hasRegisteredFace = true
        registration = reg
        registrations.append(reg)
        faceImageDataMap[reg.id] = imageData
        return reg
    }

    func loadRegistration() -> FaceRegistration? {
        loadRegistrationCallCount += 1
        return registrations.first ?? registration
    }

    func loadAllRegistrations() -> [FaceRegistration] {
        loadAllRegistrationsCallCount += 1
        return registrations
    }

    func loadFaceImage(for registration: FaceRegistration) -> Data? {
        loadFaceImageCallCount += 1
        return faceImageDataMap[registration.id] ?? faceImageData
    }

    func deleteFace(id: UUID) throws {
        deleteFaceCallCount += 1
        deletedFaceIds.append(id)
        if let error = deleteFaceError {
            throw error
        }
        registrations.removeAll { $0.id == id }
        faceImageDataMap.removeValue(forKey: id)
        if registrations.isEmpty {
            hasRegisteredFace = false
            registration = nil
        } else {
            registration = registrations.first
        }
    }

    func deleteAll() throws {
        deleteAllCallCount += 1
        if let error = deleteError {
            throw error
        }
        hasRegisteredFace = false
        registration = nil
        registrations = []
        faceImageData = nil
        faceImageDataMap = [:]
    }
}
