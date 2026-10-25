import XCTest
@testable import MobileMouse

final class MessageBuilderTests: XCTestCase {

    private func decode(_ json: String) throws -> [String: Any] {
        let data = try XCTUnwrap(json.data(using: .utf8))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func assertMove(_ json: String, dx: Double, dy: Double) throws {
        let dict = try decode(json)
        XCTAssertEqual(dict["type"] as? String, "move")
        let encodedDX = try XCTUnwrap(dict["dx"] as? Double)
        let encodedDY = try XCTUnwrap(dict["dy"] as? Double)
        XCTAssertEqual(encodedDX, dx, accuracy: 1e-6)
        XCTAssertEqual(encodedDY, dy, accuracy: 1e-6)
    }

    private func assertButton(_ json: String, type: String, button: String) throws {
        let dict = try decode(json)
        XCTAssertEqual(dict["type"] as? String, type)
        XCTAssertEqual(dict["button"] as? String, button)
    }

    private func assertSensitivity(_ json: String, value: Double) throws {
        let dict = try decode(json)
        XCTAssertEqual(dict["type"] as? String, "sensitivity")
        let encodedValue = try XCTUnwrap(dict["value"] as? Double)
        XCTAssertEqual(encodedValue, value, accuracy: 1e-6)
    }

    func testMoveEncodesTypeAndValues() throws {
        let json = try XCTUnwrap(MessageBuilder.move(dx: 0.05, dy: -0.03))
        try assertMove(json, dx: 0.05, dy: -0.03)
    }

    func testMoveClampsLargeValues() throws {
        let json = try XCTUnwrap(MessageBuilder.move(dx: 5.0, dy: 3.0))
        try assertMove(json, dx: 0.2, dy: 0.2)
    }

    func testMoveClampsLargeNegativeValues() throws {
        let json = try XCTUnwrap(MessageBuilder.move(dx: -5.0, dy: -3.0))
        try assertMove(json, dx: -0.2, dy: -0.2)
    }

    func testMoveKeepsSmallValuesUnclamped() throws {
        let json = try XCTUnwrap(MessageBuilder.move(dx: 0.03, dy: -0.03))
        try assertMove(json, dx: 0.03, dy: -0.03)
    }

    func testMoveBoundaryValuesPassThrough() throws {
        let json = try XCTUnwrap(MessageBuilder.move(dx: 0.2, dy: -0.2))
        try assertMove(json, dx: 0.2, dy: -0.2)
    }

    func testButtonLeftDown() throws {
        let json = try XCTUnwrap(MessageBuilder.button(.left, isDown: true))
        try assertButton(json, type: "button_down", button: "left")
    }

    func testButtonRightDown() throws {
        let json = try XCTUnwrap(MessageBuilder.button(.right, isDown: true))
        try assertButton(json, type: "button_down", button: "right")
    }

    func testButtonLeftUp() throws {
        let json = try XCTUnwrap(MessageBuilder.button(.left, isDown: false))
        try assertButton(json, type: "button_up", button: "left")
    }

    func testButtonRightUp() throws {
        let json = try XCTUnwrap(MessageBuilder.button(.right, isDown: false))
        try assertButton(json, type: "button_up", button: "right")
    }

    func testSensitivityEncodesTypeAndValue() throws {
        let json = try XCTUnwrap(MessageBuilder.sensitivity(value: 4000))
        try assertSensitivity(json, value: 4000)
    }

    func testSensitivityEncodesFractionalValue() throws {
        let json = try XCTUnwrap(MessageBuilder.sensitivity(value: 2450.5))
        try assertSensitivity(json, value: 2450.5)
    }
}
