import Foundation
import AVFoundation
import Combine

// MARK: - Microphone-based impact sensor

/// Detects physical impacts on the MacBook chassis via the built-in microphone.
///
/// A hard tap produces a distinct acoustic transient that the mic picks up
/// as a sudden RMS amplitude spike. This spike is mapped to a SensorSample
/// with a proportional Y-axis value; the SlapDetector's gravity-removal
/// pipeline tracks the ambient noise floor via its low-pass filter and fires
/// a SlapEvent when the dynamic component exceeds the threshold.
///
/// This is the primary sensor path on MacBook Air (Apple Silicon) where the
/// hardware accelerometer is not accessible through public APIs.
final class MicrophoneSensorProvider: SensorProvider {

    private let subject = PassthroughSubject<SensorSample, Never>()
    private let engine  = AVAudioEngine()

    // Scale factor: attack delta → g-units.
    // A slap produces a delta of ~0.04 in one buffer; at scale 80 that is 3.2 "g".
    private let rmsScale: Double = 80.0

    // Exponential smoother that tracks the short-term RMS envelope.
    // alpha = 0.15 → time constant ≈ 75 ms at 86 Hz buffer rate.
    // Speech rises gradually so the smoother keeps up; a slap outruns it in one frame.
    private var smoothedRMS: Double = 0
    private let smoothAlpha: Double = 0.15

    var isAvailable: Bool { true }   // microphone is always present on MacBook

    var samplePublisher: AnyPublisher<SensorSample, Never> {
        subject.eraseToAnyPublisher()
    }

    // MARK: - SensorProvider

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startEngine()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async { self?.startEngine() }
                } else {
                    debugLog("MicrophoneSensorProvider: microphone permission denied",
                             category: "sensor")
                }
            }
        default:
            debugLog("MicrophoneSensorProvider: microphone access restricted or denied",
                     category: "sensor")
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        debugLog("MicrophoneSensorProvider: stopped", category: "sensor")
    }

    // MARK: - Private

    private func startEngine() {
        let input  = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        // bufferSize 512 → ~86 Hz at 44 100 Hz, low enough latency for slap detection
        input.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buf, _ in
            self?.processTap(buf)
        }

        do {
            try engine.start()
            debugLog("MicrophoneSensorProvider: started (\(Int(format.sampleRate)) Hz)",
                     category: "sensor")
        } catch {
            debugLog("MicrophoneSensorProvider: engine start failed — \(error)",
                     category: "sensor")
        }
    }

    private func processTap(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }

        // RMS of channel 0
        var sum: Float = 0
        let ch = data[0]
        for i in 0..<n { sum += ch[i] * ch[i] }
        let rms = Double(sqrt(sum / Float(n)))

        // Attack = how much RMS rose above the short-term envelope this frame.
        // For speech, the envelope tracks the voice so delta stays small (< 0.01).
        // For a physical slap, RMS jumps from ~0.002 to ~0.05 in one frame;
        // the smoother hasn't caught up yet, so delta ≈ 0.048 → ~3.8 g.
        let attack = max(0, rms - smoothedRMS)
        smoothedRMS = smoothAlpha * rms + (1 - smoothAlpha) * smoothedRMS

        subject.send(SensorSample(
            x: 0,
            y: attack * rmsScale,
            z: -1.0,
            timestamp: ProcessInfo.processInfo.systemUptime
        ))
    }
}
