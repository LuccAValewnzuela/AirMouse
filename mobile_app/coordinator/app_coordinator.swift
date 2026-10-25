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
    private let accumulatorQueue = DispatchQueue(label: "coordinator.accumulator")
    private var pendingMove = SIMD2<Float>.zero
    private var carriedMove = SIMD2<Float>.zero
    private var flushTimer: Timer?

    private static let flushInterval: TimeInterval = 1.0 / 60.0
    private static let frameEpsilon: Float = 0.0003
    private static let movementThreshold: Float = 0.002

    private var sensitivity: Float = 4000

    init() {
        webSocketClient.onStateChange = { [weak self] state in self?.handleStateChange(state) }
        poseTracker.onDisplacement = { [weak self] delta in self?.accumulate(delta) }
        poseTracker.onTrackingStateChanged = { [weak self] isNormal in DispatchQueue.main.async{ self?.trackingLost = !isNormal }}
    }

    private func handleStateChange(_ state: ConnectionState) {
        connectionState = state
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
        flushTimer = Timer.scheduledTimer(withTimeInterval: Self.flushInterval, repeats: true) { [weak self] _ in
            self?.flushPendingMove()
        }
        RunLoop.current.add(flushTimer!, forMode: .common)
    }

    func stopTracking() {
        guard isTracking else { return }
        flushTimer?.invalidate()
        flushTimer = nil
        isTracking = false
        poseTracker.stop()
        accumulatorQueue.async {
            self.pendingMove = SIMD2<Float>.zero
            self.carriedMove = SIMD2<Float>.zero
        }
    }

    private func accumulate(_ delta: SIMD3<Float>) {
        accumulatorQueue.async {
            let gatedX = abs(delta.x) >= Self.frameEpsilon ? delta.x : 0
            let gatedY = abs(delta.y) >= Self.frameEpsilon ? delta.y : 0
            guard gatedX != 0 || gatedY != 0 else { return }

            self.carriedMove += SIMD2<Float>(-gatedY, gatedX)

            let excessX = self.excess(over: self.carriedMove.x)
            let excessY = self.excess(over: self.carriedMove.y)
            guard excessX != 0 || excessY != 0 else { return }

            self.carriedMove -= SIMD2<Float>(excessX, excessY)
            self.pendingMove += SIMD2<Float>(excessX, excessY)
        }
    }

    private func excess(over value: Float) -> Float {
        guard abs(value) >= Self.movementThreshold else { return 0 }
        return value - copysign(Self.movementThreshold, value)
    }

    private func flushPendingMove() {
        guard connectionState == .connected else { return }
        let snapshot: SIMD2<Float> = accumulatorQueue.sync {
            defer { pendingMove = .zero }
            return pendingMove
        }
        guard simd_length(snapshot) > 0 else { return }
        debugDisplacement = snapshot
        if let json = MessageBuilder.move(dx: snapshot.x, dy: snapshot.y) {
            webSocketClient.sendText(json)
        }
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
        accumulatorQueue.async{
            self.pendingMove = SIMD2<Float>.zero
            self.carriedMove = SIMD2<Float>.zero
        }
    }
}