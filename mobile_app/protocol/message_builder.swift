import Foundation

enum ButtonOptions: String, Codable { case left, right }

struct MoveMessage: Encodable {
    let type = "move"
    let dx: Float
    let dy: Float
}

struct ButtonMessage: Encodable {
    let type: String
    let button: ButtonOptions
}

enum MessageBuilder {
    static let moveLimit: Float = 0.2

    static func move(dx: Float, dy: Float) -> String? {
        let message = MoveMessage(
            dx: min(max(dx, -moveLimit), moveLimit),
            dy: min(max(dy, -moveLimit), moveLimit)
        )
        return encode(message)
    }

    static func button(_ button: ButtonOptions, isDown buttonDown: Bool) -> String? {
        let message = ButtonMessage(
            type: buttonDown ? "button_down" : "button_up",
            button: button
        )
        return encode(message)
    }

    private static func encode(_ message: some Encodable) -> String? {
        guard let data = try? JSONEncoder().encode(message) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

