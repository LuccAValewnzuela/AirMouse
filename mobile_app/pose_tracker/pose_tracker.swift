import ARKit
import simd
import os

final class PoseTracker: NSObject, ARSessionDelegate {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: PoseTracker.self))
    private let session = ARSession()

    private(set) var position: SIMD3<Float>?
    private(set) var displacement: SIMD3<Float>?

    var onDisplacement: ((SIMD3<Float>) -> Void)?
    var onTrackingStateChanged: ((Bool) -> Void)?

    override init() {
        super.init()
        session.delegate = self
    }

    func start() {
        guard ARWorldTrackingConfiguration.isSupported else {
            Self.logger.error("This device does not support world tracking")
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        session.run(configuration)
    }

    func stop() {
        session.pause()
    }

    func resetReference() {
        displacement = nil
        position = nil
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        guard frame.camera.trackingState == .normal else { return }

        let transform = frame.camera.transform

        let currentPosition = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )

        if !self.validPosition(currentPosition) { return }

        guard let previousPosition = position else {
            self.position = currentPosition
            self.displacement = SIMD3<Float>.zero
            return
        }

        let delta = currentPosition - previousPosition

        if simd_length(delta) > 0.1 {
            self.position = currentPosition
            self.displacement = SIMD3<Float>.zero
            return
        }

        let rotation = simd_float3x3(
            SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
            SIMD3<Float>(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
            SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        )
        let deltaLocal = rotation.transpose * delta

        self.displacement = deltaLocal
        self.position = currentPosition
        self.onDisplacement?(deltaLocal)
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let isNormal = camera.trackingState == .normal
        if !isNormal { self.position = nil }
        self.onTrackingStateChanged?(isNormal)
    }

    func validPosition(_ position: SIMD3<Float>) -> Bool {
        return all(position .== position) && all(position .< .infinity) && all(position .> -.infinity)
    }
}