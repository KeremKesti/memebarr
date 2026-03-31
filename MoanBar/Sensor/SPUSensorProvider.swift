import Foundation
import IOKit.hid
import Combine

// MARK: - HID Sensor page constants (HID Usage Tables v1.5, page 0x0020)

private let kHIDPageSensor:   UInt32 = 0x0020  // Sensor Usage Page
private let kHIDUsageAccel3D: UInt32 = 0x0073  // Motion: Accelerometer 3D
private let kHIDUsageAccelX:  UInt32 = 0x0453  // Sensor Data: Acceleration X Axis
private let kHIDUsageAccelY:  UInt32 = 0x0454  // Sensor Data: Acceleration Y Axis
private let kHIDUsageAccelZ:  UInt32 = 0x0455  // Sensor Data: Acceleration Z Axis

// MARK: - Real hardware sensor provider

/// Reads the MacBook's built-in 3-axis accelerometer via IOKit HID.
///
/// The accelerometer appears on HID Usage Page 0x0020 (Sensor),
/// Usage 0x0073 (Motion: Accelerometer 3D). Each axis arrives as a
/// separate IOHIDValue; we accumulate X and Y then emit a SensorSample
/// on every Z update (~50–100 Hz depending on the hardware).
///
/// Physical scale (kIOHIDValueScaleTypePhysical = 1) gives values in g units,
/// which is what SlapDetector's gravity-removal pipeline expects.
final class SPUSensorProvider: SensorProvider {

    private let subject = PassthroughSubject<SensorSample, Never>()
    private var manager: IOHIDManager?

    // Partial-axis accumulator: hold X and Y until Z completes the triplet.
    private var pendingX: Double = 0
    private var pendingY: Double = 0

    // Probe hardware once (lazily) and cache the result so AppViewModel's
    // isAvailable check doesn't re-open an IOHIDManager on every call.
    private lazy var _available: Bool = probeHardware()

    var isAvailable: Bool { _available }

    var samplePublisher: AnyPublisher<SensorSample, Never> {
        subject.eraseToAnyPublisher()
    }

    // MARK: - SensorProvider

    func start() {
        guard manager == nil else { return }

        let mgr = IOHIDManagerCreate(kCFAllocatorDefault,
                                     IOOptionBits(kIOHIDOptionsTypeNone))

        IOHIDManagerSetDeviceMatching(mgr, [
            kIOHIDDeviceUsagePageKey as String: kHIDPageSensor,
            kIOHIDDeviceUsageKey as String:     kHIDUsageAccel3D
        ] as CFDictionary)

        // C callback bridges to handleValue(_:) via an Unmanaged self pointer.
        IOHIDManagerRegisterInputValueCallback(mgr, { ctx, _, _, value in
            guard let ctx else { return }
            Unmanaged<SPUSensorProvider>.fromOpaque(ctx)
                .takeUnretainedValue()
                .handleValue(value)
        }, Unmanaged.passUnretained(self).toOpaque())

        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetMain(),
                                        CFRunLoopMode.defaultMode.rawValue)

        let ret = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        guard ret == kIOReturnSuccess else {
            debugLog("SPUSensorProvider: open failed (0x\(String(ret, radix: 16)))",
                     category: "sensor")
            return
        }

        manager = mgr
        debugLog("SPUSensorProvider: hardware sensor started", category: "sensor")
    }

    func stop() {
        guard let mgr = manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(mgr, CFRunLoopGetMain(),
                                          CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = nil
        debugLog("SPUSensorProvider: stopped", category: "sensor")
    }

    // MARK: - Private

    private func handleValue(_ value: IOHIDValue) {
        let el   = IOHIDValueGetElement(value)
        guard IOHIDElementGetUsagePage(el) == kHIDPageSensor else { return }

        let usage = IOHIDElementGetUsage(el)
        // Scale type 1 = kIOHIDValueScaleTypePhysical → values in g units.
        let scaled = IOHIDValueGetScaledValue(value, IOHIDValueScaleType(1))

        switch usage {
        case kHIDUsageAccelX:
            pendingX = scaled
        case kHIDUsageAccelY:
            pendingY = scaled
        case kHIDUsageAccelZ:
            subject.send(SensorSample(
                x: pendingX,
                y: pendingY,
                z: scaled,
                timestamp: ProcessInfo.processInfo.systemUptime
            ))
        default:
            break
        }
    }

    /// Opens a throw-away IOHIDManager to test whether any accelerometer
    /// device matching the sensor page is present on this machine.
    private func probeHardware() -> Bool {
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault,
                                     IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(mgr, [
            kIOHIDDeviceUsagePageKey as String: kHIDPageSensor,
            kIOHIDDeviceUsageKey as String:     kHIDUsageAccel3D
        ] as CFDictionary)
        IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        let devices: CFSet? = IOHIDManagerCopyDevices(mgr)
        IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        let found = devices.map { CFSetGetCount($0) > 0 } ?? false
        debugLog("SPUSensorProvider: hardware probe → \(found)", category: "sensor")
        return found
    }
}
