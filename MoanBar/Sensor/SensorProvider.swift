import Foundation
import Combine

// MARK: - Data types

/// A single accelerometer reading.
struct SensorSample: Sendable {
    let x: Double       // in g (gravity units)
    let y: Double
    let z: Double
    let timestamp: TimeInterval
}

// MARK: - Protocol

/// Abstraction over the physical or simulated accelerometer source.
/// Swap implementations without touching any other layer.
protocol SensorProvider: AnyObject {
    /// True when the underlying hardware or simulation is reachable.
    var isAvailable: Bool { get }

    /// Continuous stream of raw accelerometer samples.
    var samplePublisher: AnyPublisher<SensorSample, Never> { get }

    func start()
    func stop()
}
