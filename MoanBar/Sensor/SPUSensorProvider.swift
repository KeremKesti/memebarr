import Foundation
import Combine

// MARK: - Real hardware sensor provider

/// Hardware accelerometer provider for Apple Silicon MacBooks.
///
/// CMMotionManager is iOS-only and unavailable on macOS, so the real sensor
/// path must go through IOKit HID directly.
///
/// --- IOKit HID implementation path (TODO) ---
/// 1. Import IOKit
/// 2. Create an IOHIDManager: IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone)
/// 3. Set device matching for Usage Page 0x000F (Sensor), Usage 0x0073 (3D Accelerometer)
/// 4. Open manager and register IOHIDManagerRegisterInputReportCallback
/// 5. Parse x/y/z floats from the HID report bytes
/// 6. Publish samples through `subject`
///
/// Until that is implemented, this provider reports isAvailable = false and
/// the AppViewModel automatically falls back to MockSensorProvider.
final class SPUSensorProvider: SensorProvider {

    private let subject = PassthroughSubject<SensorSample, Never>()

    var isAvailable: Bool {
        // TODO: Return true once IOKit HID path is implemented and the
        // AMG/LIS3DH device is confirmed present on this machine.
        return false
    }

    var samplePublisher: AnyPublisher<SensorSample, Never> {
        subject.eraseToAnyPublisher()
    }

    func start() {
        debugLog("SPUSensorProvider: hardware path not yet implemented — use Mock Mode", category: "sensor")
    }

    func stop() {}
}
