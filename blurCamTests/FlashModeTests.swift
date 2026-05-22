import XCTest
@testable import blurCam

final class FlashModeTests: XCTestCase {

    // MARK: - Icon Name Tests

    func testIconName_Off() {
        XCTAssertEqual(FlashMode.off.iconName, "bolt.slash.fill")
    }

    func testIconName_Auto() {
        XCTAssertEqual(FlashMode.auto.iconName, "bolt.badge.automatic.fill")
    }

    func testIconName_On() {
        XCTAssertEqual(FlashMode.on.iconName, "bolt.fill")
    }

    // MARK: - Next Mode Cycle Tests

    func testNext_OffToAuto() {
        XCTAssertEqual(FlashMode.off.next, .auto)
    }

    func testNext_AutoToOn() {
        XCTAssertEqual(FlashMode.auto.next, .on)
    }

    func testNext_OnToOff() {
        XCTAssertEqual(FlashMode.on.next, .off)
    }

    func testNext_FullCycle() {
        var mode: FlashMode = .off
        mode = mode.next // auto
        XCTAssertEqual(mode, .auto)
        mode = mode.next // on
        XCTAssertEqual(mode, .on)
        mode = mode.next // off
        XCTAssertEqual(mode, .off)
    }

    // MARK: - Accessibility Label Tests

    func testAccessibilityLabel_Off() {
        XCTAssertEqual(FlashMode.off.accessibilityLabel, "フラッシュオフ")
    }

    func testAccessibilityLabel_Auto() {
        XCTAssertEqual(FlashMode.auto.accessibilityLabel, "フラッシュ自動")
    }

    func testAccessibilityLabel_On() {
        XCTAssertEqual(FlashMode.on.accessibilityLabel, "フラッシュオン")
    }

    // MARK: - Raw Value Tests

    func testRawValue_Off() {
        XCTAssertEqual(FlashMode.off.rawValue, "off")
    }

    func testRawValue_Auto() {
        XCTAssertEqual(FlashMode.auto.rawValue, "auto")
    }

    func testRawValue_On() {
        XCTAssertEqual(FlashMode.on.rawValue, "on")
    }

    // MARK: - Equatable Tests

    func testEquatable() {
        XCTAssertEqual(FlashMode.off, FlashMode.off)
        XCTAssertEqual(FlashMode.auto, FlashMode.auto)
        XCTAssertEqual(FlashMode.on, FlashMode.on)
        XCTAssertNotEqual(FlashMode.off, FlashMode.on)
        XCTAssertNotEqual(FlashMode.auto, FlashMode.off)
    }

    // MARK: - CaseIterable Tests

    func testAllCases() {
        XCTAssertEqual(FlashMode.allCases.count, 3)
        XCTAssertTrue(FlashMode.allCases.contains(.off))
        XCTAssertTrue(FlashMode.allCases.contains(.auto))
        XCTAssertTrue(FlashMode.allCases.contains(.on))
    }
}
