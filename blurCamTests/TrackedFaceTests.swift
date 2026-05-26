import XCTest
@testable import blurCam

/// Tests for TrackedFace hysteresis logic, blur-by-default principle,
/// and the fixes for false unblur on unregistered faces.
final class TrackedFaceTests: XCTestCase {

    // MARK: - Initial State

    func testInitialState_IsNotRegistered() {
        let face = TrackedFace(trackID: 0)
        XCTAssertFalse(face.isRegistered)
    }

    func testInitialState_FrameCountIsZero() {
        let face = TrackedFace(trackID: 0)
        XCTAssertEqual(face.frameCount, 0)
    }

    func testInitialState_AverageSimilarityIsZero() {
        let face = TrackedFace(trackID: 0)
        XCTAssertEqual(face.averageSimilarity, 0.0, accuracy: 0.001)
    }

    // MARK: - Blur-by-Default: Initial Blur Period

    func testBlurByDefault_AlwaysBlursDuringInitialPeriod() {
        let face = TrackedFace(trackID: 0, enter: 0.45, exit: 0.30, window: 15, initialBlurFrames: 10)

        // Even with perfect similarity (1.0), should still blur during initial frames
        for i in 1...10 {
            let shouldBlur = face.update(similarity: 1.0)
            XCTAssertTrue(shouldBlur, "Frame \(i): should blur during initial period even with high similarity")
            XCTAssertFalse(face.isRegistered, "Frame \(i): should not be registered during initial period")
        }
    }

    func testBlurByDefault_TransitionsAfterInitialPeriod() {
        let face = TrackedFace(trackID: 0, enter: 0.45, exit: 0.30, window: 15, initialBlurFrames: 5)

        // Fill initial period with high similarity
        for _ in 1...5 {
            _ = face.update(similarity: 1.0)
        }
        XCTAssertFalse(face.isRegistered, "Still in initial period")

        // After initial period, high average should eventually trigger registration
        let shouldBlur = face.update(similarity: 1.0)
        XCTAssertFalse(shouldBlur, "After initial period with high average, should not blur")
        XCTAssertTrue(face.isRegistered, "Should be registered now")
    }

    func testBlurByDefault_NilSimilarityAlwaysBlurs() {
        let face = TrackedFace(trackID: 0, enter: 0.45, exit: 0.30, window: 15, initialBlurFrames: 3)

        // Fill initial period
        for _ in 1...3 {
            _ = face.update(similarity: nil)
        }

        // After initial period, nil similarity maps to 0, which should keep blurring
        for _ in 1...20 {
            let shouldBlur = face.update(similarity: nil)
            XCTAssertTrue(shouldBlur, "Nil similarity should always result in blur")
        }
    }

    // MARK: - Hysteresis: Enter Threshold (Unblur)

    func testHysteresis_RequiresSufficientHistoryToEnter() {
        // With window=15 and minHistory=5, need at least 5 samples before entering
        let face = TrackedFace(trackID: 0, enter: 0.45, exit: 0.30, window: 15, initialBlurFrames: 0)

        // First 4 frames with high similarity -- not enough history yet
        for i in 1...4 {
            let shouldBlur = face.update(similarity: 1.0)
            XCTAssertTrue(shouldBlur, "Frame \(i): not enough history to enter registered state")
        }

        // 5th frame should allow entry
        let shouldBlur = face.update(similarity: 1.0)
        XCTAssertFalse(shouldBlur, "Frame 5: enough history with high average, should enter registered")
    }

    func testHysteresis_DoesNotEnterWithLowSimilarity() {
        let face = TrackedFace(trackID: 0, enter: 0.45, exit: 0.30, window: 15, initialBlurFrames: 0)

        // Feed similarity values below enter threshold
        for _ in 1...20 {
            let shouldBlur = face.update(similarity: 0.3)
            XCTAssertTrue(shouldBlur, "Low similarity should not trigger registration")
        }
        XCTAssertFalse(face.isRegistered)
    }

    func testHysteresis_SpikeDoesNotCauseRegistration() {
        // Simulate a false positive spike scenario:
        // Most frames: low similarity (unregistered person)
        // Occasional spikes: high similarity (FaceNet noise)
        let face = TrackedFace(trackID: 0, enter: 0.45, exit: 0.30, window: 15, initialBlurFrames: 0)

        // Establish baseline: 12 frames of low similarity
        for _ in 1...12 {
            _ = face.update(similarity: 0.1)
        }

        // Spike: 3 frames of high similarity (FaceNet false positive)
        for _ in 1...3 {
            let shouldBlur = face.update(similarity: 0.8)
            XCTAssertTrue(shouldBlur, "Spike should not overcome the window average")
        }

        XCTAssertFalse(face.isRegistered, "Spikes should not cause false registration")

        // Verify: average is still below enter threshold
        XCTAssertLessThan(face.averageSimilarity, 0.45)
    }

    // MARK: - Hysteresis: Exit Threshold (Re-blur)

    func testHysteresis_ExitThresholdIsLenient() {
        let face = TrackedFace(trackID: 0, enter: 0.45, exit: 0.30, window: 15, initialBlurFrames: 0)

        // Get to registered state
        for _ in 1...10 {
            _ = face.update(similarity: 0.6)
        }
        XCTAssertTrue(face.isRegistered)

        // Slight drop should NOT cause exit (asymmetric thresholds protect against flicker)
        for _ in 1...5 {
            _ = face.update(similarity: 0.35)
        }
        XCTAssertTrue(face.isRegistered, "Slight drop should not cause exit due to lenient threshold")

        // Sustained low similarity should eventually cause exit
        for _ in 1...15 {
            _ = face.update(similarity: 0.1)
        }
        XCTAssertFalse(face.isRegistered, "Sustained low similarity should cause exit")
    }

    // MARK: - Window Size Behavior

    func testWindowSize_OldDataScrollsOut() {
        let face = TrackedFace(trackID: 0, enter: 0.45, exit: 0.30, window: 5, initialBlurFrames: 0)

        // Fill window with high similarity
        for _ in 1...5 {
            _ = face.update(similarity: 0.6)
        }
        XCTAssertTrue(face.isRegistered)

        // Replace entire window with low similarity
        for _ in 1...5 {
            _ = face.update(similarity: 0.0)
        }
        XCTAssertFalse(face.isRegistered, "Old data should scroll out of window")
    }

    // MARK: - Miss Count / Track Removal

    func testMarkMissed_RemovesAfterThreshold() {
        let face = TrackedFace(trackID: 0)

        // Should not be removed for first 8 misses
        for i in 1...8 {
            XCTAssertFalse(face.markMissed(), "Miss \(i): should not remove yet")
        }

        // 9th miss should trigger removal
        XCTAssertTrue(face.markMissed(), "Miss 9: should trigger removal")
    }

    func testResetMissCount_PreventsRemoval() {
        let face = TrackedFace(trackID: 0)

        // Accumulate some misses
        for _ in 1...7 {
            _ = face.markMissed()
        }

        // Reset
        face.resetMissCount()

        // Should need full 9 misses again
        for _ in 1...8 {
            XCTAssertFalse(face.markMissed())
        }
        XCTAssertTrue(face.markMissed())
    }

    func testUpdate_ResetsMissCount() {
        let face = TrackedFace(trackID: 0)

        // Accumulate misses
        for _ in 1...7 {
            _ = face.markMissed()
        }

        // Update resets miss count
        _ = face.update(similarity: 0.5)

        // Verify: need 9 more misses for removal
        for _ in 1...8 {
            XCTAssertFalse(face.markMissed())
        }
        XCTAssertTrue(face.markMissed())
    }

    // MARK: - Realistic Scenario Tests

    func testScenario_UnregisteredFaceStaysBlurred() {
        // Simulates an unregistered person standing still in front of camera
        // FaceNet produces noisy similarity around 0.1-0.3 with occasional spikes to 0.4+
        let face = TrackedFace(trackID: 0, enter: 0.45, exit: 0.30, window: 15, initialBlurFrames: 10)

        // Typical similarity values for an unregistered face (with noise)
        let similarities: [Float] = [
            0.10, 0.15, 0.20, 0.12, 0.18, // initial blur period
            0.25, 0.30, 0.15, 0.22, 0.28, // still in initial blur period
            0.19, 0.42, 0.15, 0.20, 0.13, // spike at frame 12, but should not unblur
            0.45, 0.20, 0.18, 0.22, 0.16, // spike at frame 16, but window average stays low
            0.12, 0.15, 0.20, 0.25, 0.18, // normal
        ]

        for (i, sim) in similarities.enumerated() {
            let shouldBlur = face.update(similarity: sim)
            XCTAssertTrue(shouldBlur, "Frame \(i+1): unregistered face should ALWAYS be blurred, sim=\(sim)")
        }
    }

    func testScenario_RegisteredFaceEventuallyUnblurred() {
        // Simulates a registered person: FaceNet similarity around 0.43-0.59
        let face = TrackedFace(trackID: 0, enter: 0.45, exit: 0.30, window: 15, initialBlurFrames: 10)

        // During initial blur period (10 frames), always blurred
        for i in 1...10 {
            let shouldBlur = face.update(similarity: 0.55)
            XCTAssertTrue(shouldBlur, "Frame \(i): should blur during initial period")
        }

        // After initial period, with sustained high similarity, should eventually unblur
        var unblurred = false
        for i in 11...25 {
            let shouldBlur = face.update(similarity: 0.55)
            if !shouldBlur {
                unblurred = true
                break
            }
        }
        XCTAssertTrue(unblurred, "Registered face should eventually be unblurred")
        XCTAssertTrue(face.isRegistered)
    }

    func testScenario_RegisteredFaceWithNoise() {
        // Simulates registered person with noisy similarity (some frames below threshold)
        let face = TrackedFace(trackID: 0, enter: 0.45, exit: 0.30, window: 15, initialBlurFrames: 5)

        // Initial blur period
        for _ in 1...5 {
            _ = face.update(similarity: 0.50)
        }

        // Build up enough history to register
        for _ in 1...10 {
            _ = face.update(similarity: 0.50)
        }
        XCTAssertTrue(face.isRegistered, "Should be registered with average ~0.50")

        // Noise: a few low frames should not cause exit (exit threshold = 0.30)
        _ = face.update(similarity: 0.20)
        _ = face.update(similarity: 0.25)
        _ = face.update(similarity: 0.30)
        XCTAssertTrue(face.isRegistered, "A few low frames should not cause exit")
    }
}

// MARK: - FaceTracker Tests

final class FaceTrackerTests: XCTestCase {

    // MARK: - Basic Assignment

    func testAssign_CreatesNewTracksForNewBoxes() {
        let tracker = FaceTracker()
        let boxes = [
            CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
            CGRect(x: 0.6, y: 0.6, width: 0.2, height: 0.2)
        ]

        let assignments = tracker.assign(boxes: boxes)
        XCTAssertEqual(assignments.count, 2)

        let trackIDs = Set(assignments.map { $0.face.trackID })
        XCTAssertEqual(trackIDs.count, 2, "Each face should get a unique track ID")
    }

    func testAssign_MaintainsTrackIDsForOverlappingBoxes() {
        let tracker = FaceTracker()

        // Frame 1
        let boxes1 = [CGRect(x: 0.3, y: 0.3, width: 0.3, height: 0.3)]
        let assignments1 = tracker.assign(boxes: boxes1)
        let trackID1 = assignments1[0].face.trackID

        // Frame 2: slightly moved box
        let boxes2 = [CGRect(x: 0.32, y: 0.32, width: 0.3, height: 0.3)]
        let assignments2 = tracker.assign(boxes: boxes2)
        let trackID2 = assignments2[0].face.trackID

        XCTAssertEqual(trackID1, trackID2, "Overlapping boxes should maintain the same track ID")
    }

    // MARK: - updateSimilarities

    func testUpdateSimilarities_InjectsSimilarityToMatchingTrack() {
        let tracker = FaceTracker()

        // Create a track
        let box = CGRect(x: 0.3, y: 0.3, width: 0.3, height: 0.3)
        let assignments = tracker.assign(boxes: [box])
        let trackedFace = assignments[0].face

        // Inject similarity with matching box
        // Need to go past initial blur period first
        // The update via updateSimilarities increments frameCount
        for _ in 1...15 {
            tracker.updateSimilarities(recognitionResults: [(box: box, similarity: 0.6)])
        }

        XCTAssertTrue(trackedFace.isRegistered, "Should be registered after sustained high similarity")
    }

    func testUpdateSimilarities_DoesNotCreateNewTracks() {
        let tracker = FaceTracker()

        // Create one track
        let box1 = CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2)
        _ = tracker.assign(boxes: [box1])

        // Inject similarity for a non-overlapping box (should be silently ignored)
        let nonOverlappingBox = CGRect(x: 0.8, y: 0.8, width: 0.1, height: 0.1)
        tracker.updateSimilarities(recognitionResults: [(box: nonOverlappingBox, similarity: 1.0)])

        // Only the original track should exist
        let assignments = tracker.assign(boxes: [box1])
        // We should still have just 1 tracked face with the original track ID
        let matchedFaces = assignments.filter { FaceTracker.iou($0.box, box1) > 0.3 }
        XCTAssertEqual(matchedFaces.count, 1, "updateSimilarities should not create new tracks")
    }

    func testUpdateSimilarities_DoesNotUpdateTrackPosition() {
        let tracker = FaceTracker()

        // Create a track at position A
        let boxA = CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.3)
        let assignments1 = tracker.assign(boxes: [boxA])
        let trackID = assignments1[0].face.trackID

        // Inject similarity with a slightly different but overlapping box
        let boxB = CGRect(x: 0.15, y: 0.15, width: 0.3, height: 0.3)
        tracker.updateSimilarities(recognitionResults: [(box: boxB, similarity: 0.5)])

        // The track position should still match boxA (not boxB)
        // Verify by assigning a box near A -- should match the same track
        let assignments2 = tracker.assign(boxes: [boxA])
        XCTAssertEqual(assignments2[0].face.trackID, trackID, "Track position should not change from updateSimilarities")
    }

    // MARK: - IoU

    func testIoU_IdenticalBoxes() {
        let box = CGRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)
        XCTAssertEqual(FaceTracker.iou(box, box), 1.0, accuracy: 0.001)
    }

    func testIoU_NoOverlap() {
        let a = CGRect(x: 0.0, y: 0.0, width: 0.1, height: 0.1)
        let b = CGRect(x: 0.5, y: 0.5, width: 0.1, height: 0.1)
        XCTAssertEqual(FaceTracker.iou(a, b), 0.0, accuracy: 0.001)
    }
}

// MARK: - DetectedFace Similarity Property Tests

final class DetectedFaceSimilarityTests: XCTestCase {

    func testDetectedFace_DefaultSimilarityIsZero() {
        let face = DetectedFace(
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            isRegistered: false
        )
        XCTAssertEqual(face.similarity, 0.0, accuracy: 0.001)
    }

    func testDetectedFace_CustomSimilarity() {
        let face = DetectedFace(
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            isRegistered: true,
            similarity: 0.75
        )
        XCTAssertEqual(face.similarity, 0.75, accuracy: 0.001)
    }

    func testDetectedFace_SimilarityIncludedInEquatable() {
        let id = UUID()
        let face1 = DetectedFace(
            id: id,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            isRegistered: true,
            similarity: 0.5
        )
        let face2 = DetectedFace(
            id: id,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            isRegistered: true,
            similarity: 0.8
        )
        XCTAssertNotEqual(face1, face2, "Different similarity values should make faces not equal")
    }
}
