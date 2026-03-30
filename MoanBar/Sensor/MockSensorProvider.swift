import Foundation
import Combine

// MARK: - Mock / development sensor

/// Always available; generates a quiet idle noise stream and lets you inject
/// arbitrary slap events programmatically. Used when hardware is unavailable
/// or the user enables Mock Mode in Settings.
final class MockSensorProvider: SensorProvider {

    private let subject = PassthroughSubject<SensorSample, Never>()
    private var timer: Timer?

    // Idle simulation phase for the sine wave noise floor
    private var phase: Double = 0

    var isAvailable: Bool { true }

    var samplePublisher: AnyPublisher<SensorSample, Never> {
        subject.eraseToAnyPublisher()
    }

    func start() {
        guard timer == nil else { return }
        // ~50 Hz idle tick — low enough to avoid wasting CPU in test mode
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 50.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        debugLog("MockSensorProvider: started", category: "sensor")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        debugLog("MockSensorProvider: stopped", category: "sensor")
    }

    /// Inject a synthetic impact. Call from UI (Test Slap / Simulate Slap).
    /// - Parameter intensity: Dynamic-acceleration magnitude in g units. Values
    ///   above the detector threshold trigger a SlapEvent. Default ≈ 2.5 g.
    func simulateSlap(intensity: Double = 2.5) {
        let t = ProcessInfo.processInfo.systemUptime
        // Deliver a single spike that the detector will see as an impact.
        let spike = SensorSample(x: 0, y: intensity, z: -1.0, timestamp: t)
        subject.send(spike)
        // Follow up with a decay to let the hysteresis band close cleanly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            let decay = SensorSample(x: 0, y: 0.1, z: -1.0,
                                     timestamp: ProcessInfo.processInfo.systemUptime)
            self?.subject.send(decay)
        }
        debugLog("MockSensorProvider: simulated slap intensity=\(intensity)", category: "sensor")
    }

    // MARK: - Private

    private func tick() {
        phase += 0.12
        let noise = Double.random(in: -0.008...0.008)
        let sample = SensorSample(
            x: noise,
            y: noise + sin(phase) * 0.004,
            z: -1.0 + noise,   // approximate gravity on Z axis
            timestamp: ProcessInfo.processInfo.systemUptime
        )
        subject.send(sample)
    }
}
