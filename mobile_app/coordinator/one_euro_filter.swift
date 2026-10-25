import Foundation

final class OneEuroFilter {
    private var valueFilter = LowPassFilter()
    private var derivativeFilter = LowPassFilter()
    private var previousValue: Float?
    private var previousTimestamp: Double?

    private let minCutoff: Float
    private let beta: Float
    private let derivativeCutoff: Float

    init(minCutoff: Float = 3.0, beta: Float = 30.0, derivativeCutoff: Float = 2.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.derivativeCutoff = derivativeCutoff
    }

    func filter(value: Float, timestamp: Double) -> Float {
        guard let previousValue = previousValue, let previousTimestamp = previousTimestamp else {
            self.previousValue = value
            self.previousTimestamp = timestamp
            return value
        }

        let dt = Float(max(timestamp - previousTimestamp, 1e-6))
        let derivative = (value - previousValue) / dt
        let smoothedDerivative = derivativeFilter.filtered(value: derivative, alpha: Self.alpha(cutoff: derivativeCutoff, dt: dt))
        let cutoff = minCutoff + beta * abs(smoothedDerivative)
        let filtered = valueFilter.filtered(value: value, alpha: Self.alpha(cutoff: cutoff, dt: dt))

        self.previousValue = value
        self.previousTimestamp = timestamp
        return filtered
    }

    func reset() {
        valueFilter = LowPassFilter()
        derivativeFilter = LowPassFilter()
        previousValue = nil
        previousTimestamp = nil
    }

    private static func alpha(cutoff: Float, dt: Float) -> Float {
        let tau = 1 / (2 * Float.pi * cutoff)
        return 1 / (1 + tau / dt)
    }
}

private struct LowPassFilter {
    private var filteredValue: Float?

    mutating func filtered(value: Float, alpha: Float) -> Float {
        if let previous = filteredValue {
            filteredValue = alpha * value + (1 - alpha) * previous
        } else {
            filteredValue = value
        }
        return filteredValue!
    }
}
