import Foundation
import Combine

// MARK: - Output types

/// Emitted once per confirmed slap after debounce/hysteresis.
struct SlapEvent: Sendable {
    let timestamp: TimeInterval
    /// Normalised 0…1, derived from peak dynamic acceleration.
    let intensity: Double
    /// Raw peak magnitude in g units, before clamping.
    let rawMagnitude: Double
}

/// Live snapshot for the Diagnostics UI. Published at sensor rate.
struct DiagnosticsSnapshot: Sendable {
    var rawX: Double = 0
    var rawY: Double = 0
    var rawZ: Double = 0
    /// Magnitude of the gravity-removed dynamic acceleration vector.
    var filteredMagnitude: Double = 0
    var threshold: Double = 0
    /// True while the detector is inside an active impact window.
    var hitDetected: Bool = false
}

// MARK: - Detector

/// Signal-processing pipeline that turns a raw accelerometer stream into
/// discrete SlapEvents with an estimated intensity.
///
/// Pipeline stages:
///   1. Low-pass filter  → tracks slow-changing gravity vector
///   2. Gravity removal  → subtracts gravity to isolate dynamic acceleration
///   3. Magnitude        → scalar magnitude of dynamic vector
///   4. Threshold gate   → magnitude > threshold opens an impact window
///   5. Peak tracker     → records highest magnitude during the window
///   6. Hysteresis close → window closes when magnitude falls below 50 % of threshold
///   7. Cooldown         → suppresses re-triggers for N seconds after an event
///
/// All mutable state lives here; the class is NOT thread-safe — call
/// `processSample(_:)` from a single thread (main).
final class SlapDetector {

    // MARK: - Tunable parameters (bound to Settings sliders)

    /// Threshold in g units. Lower = more sensitive.
    var threshold: Double = 1.5

    /// Minimum seconds between two consecutive events.
    var cooldownSeconds: Double = 0.4

    /// Dynamic-acceleration magnitude that maps to intensity = 1.0.
    var maxIntensityG: Double = 4.0

    // MARK: - Publishers

    private let eventSubject = PassthroughSubject<SlapEvent, Never>()
    private let diagnosticsSubject = CurrentValueSubject<DiagnosticsSnapshot, Never>(DiagnosticsSnapshot())

    var eventPublisher: AnyPublisher<SlapEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    var diagnosticsPublisher: AnyPublisher<DiagnosticsSnapshot, Never> {
        diagnosticsSubject.eraseToAnyPublisher()
    }

    // MARK: - Low-pass filter state (gravity estimate)

    /// High alpha = slow adaptation = good gravity tracking but slow response.
    private let gravityAlpha: Double = 0.97

    private var gx: Double = 0
    private var gy: Double = 0
    private var gz: Double = -1.0

    // MARK: - Impact window state

    private var lastHitTime: TimeInterval = 0
    private var inWindow: Bool = false
    private var peakMagnitude: Double = 0

    // MARK: - Public API

    func processSample(_ sample: SensorSample) {
        // --- Stage 1: update gravity estimate ---
        gx = gravityAlpha * gx + (1 - gravityAlpha) * sample.x
        gy = gravityAlpha * gy + (1 - gravityAlpha) * sample.y
        gz = gravityAlpha * gz + (1 - gravityAlpha) * sample.z

        // --- Stage 2: remove gravity ---
        let dx = sample.x - gx
        let dy = sample.y - gy
        let dz = sample.z - gz

        // --- Stage 3: magnitude ---
        let mag = (dx*dx + dy*dy + dz*dz).squareRoot()

        let now = sample.timestamp
        let timeSinceLast = now - lastHitTime
        var hitActive = false

        // --- Stages 4–7: threshold / peak / hysteresis / cooldown ---
        if mag > threshold && timeSinceLast > cooldownSeconds {
            if !inWindow {
                inWindow = true
                peakMagnitude = mag
            } else {
                peakMagnitude = max(peakMagnitude, mag)
            }
            hitActive = true
        } else if inWindow {
            if mag < threshold * 0.5 {
                // Hysteresis: signal settled — fire the event now
                let intensity = min(peakMagnitude / maxIntensityG, 1.0)
                let event = SlapEvent(
                    timestamp: now,
                    intensity: intensity,
                    rawMagnitude: peakMagnitude
                )
                eventSubject.send(event)
                debugLog(
                    "SlapDetector: SLAP peak=\(String(format:"%.3f", peakMagnitude))g intensity=\(String(format:"%.2f", intensity))",
                    category: "detection"
                )
                lastHitTime = now
                inWindow = false
                peakMagnitude = 0
            } else {
                // Still above hysteresis floor — keep accumulating peak
                hitActive = true
            }
        }

        // --- Diagnostics snapshot ---
        let snap = DiagnosticsSnapshot(
            rawX: sample.x,
            rawY: sample.y,
            rawZ: sample.z,
            filteredMagnitude: mag,
            threshold: threshold,
            hitDetected: hitActive
        )
        diagnosticsSubject.send(snap)
    }

    /// Resets gravity filter and debounce state. Call when sensor is restarted.
    func reset() {
        gx = 0; gy = 0; gz = -1.0
        lastHitTime = 0
        inWindow = false
        peakMagnitude = 0
    }
}
