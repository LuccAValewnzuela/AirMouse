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
    private var flushTimer: Timer?

    private static let flushInterval: TimeInterval = 1.0 / 30.0
    private static let deadband: Float = 0.001

    init() {
        webSocketClient.onStateChange = { [weak self] state in self?.connectionState = state }
        poseTracker.onDisplacement = { [weak self] delta in self?.accumulate(delta) }
        poseTracker.onTrackingStateChanged = { [weak self] isNormal in DispatchQueue.main.async{ self?.trackingLost = !isNormal }}
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
        }
    }

    private func accumulate(_ delta: SIMD3<Float>) {
        accumulatorQueue.async {
            self.pendingMove += SIMD2<Float>(delta.x, -delta.z)
        }
    }

    private func flushPendingMove() {
        guard connectionState == .connected else { return }
        let snapshot: SIMD2<Float> = accumulatorQueue.sync {
            defer { pendingMove = .zero }
            return pendingMove
        }
        guard simd_length(snapshot) >= deadband else { return }
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
            self.pendingMove = .zero
        }
    }
}