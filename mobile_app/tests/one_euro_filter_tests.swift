import XCTest
@testable import MobileMouse

final class OneEuroFilterTests: XCTestCase {

    private let frameInterval = 1.0 / 60.0

    private func feedRamp(velocity: Float, frames: Int) -> (lastInput: Float, lastOutput: Float) {
        let filter = OneEuroFilter()
        var input: Float = 0
        var output: Float = 0
        for frame in 0..<frames {
            input += velocity * Float(frameInterval)
            output = filter.filter(value: input, timestamp: Double(frame) * frameInterval)
        }
        return (input, output)
    }

    func testFirstValuePassesThroughUnfiltered() {
        let filter = OneEuroFilter()
        XCTAssertEqual(filter.filter(value: 0.137, timestamp: 10.0), 0.137)
    }

    func testConstantSignalProducesNoFurtherOutputChange() {
        let filter = OneEuroFilter()
        var outputs: [Float] = []
        for frame in 0..<31 {
            outputs.append(filter.filter(value: 0.25, timestamp: Double(frame) * frameInterval))
        }
        XCTAssertEqual(abs(outputs[30] - outputs[29]), 0, accuracy: 1e-6)
    }

    func testRampOutputIsMonotonicAndTracksInput() {
        let filter = OneEuroFilter()
        var input: Float = 0
        var output: Float = 0
        var outputs: [Float] = []
        for frame in 0..<120 {
            input += 0.3 * Float(frameInterval)
            output = filter.filter(value: input, timestamp: Double(frame) * frameInterval)
            outputs.append(output)
        }
        XCTAssertTrue(outputs == outputs.sorted(), "filtered ramp should be monotonic")
        XCTAssertLessThan(output, input, "first-order low-pass must lag a ramp")
        XCTAssertGreaterThan(output, input * 0.9, "ramp should be tracked closely at speed")
    }

    func testFastMotionHasLessTimeLagThanSlowMotion() {
        let slow = feedRamp(velocity: 0.05, frames: 120)
        let fast = feedRamp(velocity: 0.5, frames: 120)

        let slowTimeLag = (slow.lastInput - slow.lastOutput) / 0.05
        let fastTimeLag = (fast.lastInput - fast.lastOutput) / 0.5

        XCTAssertGreaterThan(slowTimeLag, 0)
        XCTAssertGreaterThan(fastTimeLag, 0)
        XCTAssertLessThan(fastTimeLag, slowTimeLag, "velocity-adaptive cutoff must reduce lag at speed")
    }

    func testAlternatingJitterIsAttenuated() {
        let filter = OneEuroFilter()
        let jitter: Float = 0.001
        var outputs: [Float] = []
        for frame in 0..<40 {
            let value = frame % 2 == 0 ? jitter : -jitter
            outputs.append(filter.filter(value: value, timestamp: Double(frame) * frameInterval))
        }

        for frame in 20..<40 {
            let change = abs(outputs[frame] - outputs[frame - 1])
            XCTAssertLessThan(change, 0.5 * 2 * jitter, "per-frame jitter must be smoothed at rest")
        }
    }

    func testResetRestoresPassThroughBehavior() {
        let filter = OneEuroFilter()
        for frame in 0..<10 {
            _ = filter.filter(value: Float(frame) * 0.01, timestamp: Double(frame) * frameInterval)
        }
        filter.reset()
        XCTAssertEqual(filter.filter(value: -0.42, timestamp: 100.0), -0.42)
    }
}
