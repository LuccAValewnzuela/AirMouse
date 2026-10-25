import Foundation
import simd
import Combine

final class AppCoordinator: ObservableObject {
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var isTracking = false
    @Published private(set) var trackingLost = false
    @Published private(set) var debugDisplacement = SIMD2<Float>.zero

    private let poseTracker = PoseTracker()
    private let webSocketClient = WebSocketClient()
    private let filterQueue = DispatchQueue(label: "coordinator.filter", qos: .userInteractive)

    private var horizontalFilter = OneEuroFilter()
    private var verticalFilter = OneEuroFilter()
    private var position = SIMD2<Float>.zero
    private var filteredPosition = SIMD2<Float>.zero
    private var lastDebugUpdate: CFAbsoluteTime = 0
    private var connected = false

    private static let deadband: Float = 0.00005
    private static let debugInterval: CFAbsoluteTime = 0.1

    private var sensitivity: Float = 4000

    init() {
        webSocketClient.onStateChange = { [weak self] state in self?.handleStateChange(state) }
        poseTracker.onDisplacement = { [weak self] delta in self?.handleDisplacement(delta) }
        poseTracker.onTrackingStateChanged = { [weak self] isNormal in DispatchQueue.main.async{ self?.trackingLost = !isNormal }}
    }

    private func handleStateChange(_ state: ConnectionState) {
        connectionState = state
        filterQueue.async { self.connected = state == .connected }
        if state == .connected {
            sendSensitivity()
        }
    }

    func setSensitivity(_ value: Float) {
        sensitivity = value
        sendSensitivity()
    }

    private func sendSensitivity() {
        guard connectionState == .connected else { return }
        if let json = MessageBuilder.sensitivity(value: sensitivity) {
            webSocketClient.sendText(json)
        }
    }

    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        poseTracker.start()
    }

    func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        poseTracker.stop()
        resetMotionState()
    }

    private func handleDisplacement(_ delta: SIMD3<Float>) {
        filterQueue.async {
            self.position += SIMD2<Float>(-delta.y, delta.x)

            let timestamp = CFAbsoluteTimeGetCurrent()
            let filtered = SIMD2<Float>(
                self.horizontalFilter.filter(value: self.position.x, timestamp: timestamp),
                self.verticalFilter.filter(value: self.position.y, timestamp: timestamp)
            )

            var move = filtered - self.filteredPosition
            self.filteredPosition = filtered

            move.x = abs(move.x) >= Self.deadband ? move.x : 0
            move.y = abs(move.y) >= Self.deadband ? move.y : 0
            guard move.x != 0 || move.y != 0 else { return }

            self.publishDebugIfNeeded(move)

            guard self.connected else { return }
            if let json = MessageBuilder.move(dx: move.x, dy: move.y) {
                self.webSocketClient.sendText(json)
            }
        }
    }

    private func publishDebugIfNeeded(_ move: SIMD2<Float>) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastDebugUpdate >= Self.debugInterval else { return }
        lastDebugUpdate = now
        DispatchQueue.main.async { self.debugDisplacement = move }
    }

    func press(_ button: ButtonOptions) {
        sendButton(button, isDown: true)
    }

    func release(_ button: ButtonOptions) {
        sendButton(button, isDown: false)
    }

    private func sendButton(_ button: ButtonOptions, isDown: Bool) {
        guard connectionState == .connected else { return }
        if let json = MessageBuilder.button(button, isDown: isDown) {
            webSocketClient.sendText(json)
        }
    }

    func connect() {
        webSocketClient.connect()
    }

    func disconnect() {
        webSocketClient.disconnect()
    }

    func resetReference() {
        poseTracker.resetReference()
        resetMotionState()
    }

    private func resetMotionState() {
        filterQueue.async {
            self.horizontalFilter.reset()
            self.verticalFilter.reset()
            self.position = SIMD2<Float>.zero
            self.filteredPosition = SIMD2<Float>.zero
        }
    }
}
