import Foundation
import Combine
import CoreMotion

// MARK: - Real hardware sensor provider

/// Attempts to use the Apple Silicon internal accelerometer via CoreMotion.
///
/// CoreMotion's CMMotionManager on macOS (13+) may expose the internal IMU on
/// Apple Silicon laptops. The `isAccelerometerAvailable` property gates this.
///
/// If CoreMotion returns unavailable (common on older or desktop Macs), the
/// AppViewModel will automatically fall back to MockSensorProvider.
///
/// --- Future / alternative hardware path ---
/// An IOKit HID path targeting the Apple Motion Group (AMG) or LIS3DH device
/// can replace this implementation. To do so:
///
/// 1. Enumerate HID devices:
///    IOHIDManagerCreate → IOHIDManagerSetDeviceMatchingMultiple with matching
///    dict for Usage Page 0x000F (Sensor), Usage 0x0073 (3D Accelerometer).
/// 2. Open the manager with kIOHIDManagerOptionNone.
/// 3. Register IOHIDManagerRegisterInputReportCallback to receive raw reports.
/// 4. Parse x/y/z from the HID report bytes per the device descriptor.
///
/// NOTE: This IOKit path requires no special entitlements for direct-distribution
/// apps but is undocumented and may break across OS updates. Isolate it behind
/// this same SensorProvider protocol so the rest of the app is unaffected.
///
/// TODO: Implement IOKit HID path as a fallback when CoreMotion unavailable.
final class SPUSensorProvider: SensorProvider {

    private let motionManager = CMMotionManager()
    private let subject = PassthroughSubject<SensorSample, Never>()

    /// 100 Hz — sufficient for slap detection; higher rates increase CPU load.
    private let updateInterval: TimeInterval = 1.0 / 100.0

    var isAvailable: Bool {
        motionManager.isAccelerometerAvailable
    }

    var samplePublisher: AnyPublisher<SensorSample, Never> {
        subject.eraseToAnyPublisher()
    }

    func start() {
        guard isAvailable else {
            debugLog("SPUSensorProvider: accelerometer unavailable on this Mac", category: "sensor")
            return
        }
        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let data = data, error == nil else {
                if let error = error {
                    debugLog("SPUSensorProvider error: \(error)", category: "sensor")
                }
                return
            }
            let sample = SensorSample(
                x: data.acceleration.x,
                y: data.acceleration.y,
                z: data.acceleration.z,
                timestamp: data.timestamp
            )
            self?.subject.send(sample)
        }
        debugLog("SPUSensorProvider: started at \(Int(1/updateInterval)) Hz", category: "sensor")
    }

    func stop() {
        motionManager.stopAccelerometerUpdates()
        debugLog("SPUSensorProvider: stopped", category: "sensor")
    }
}
