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

    // Scale factor: RMS → g-units.
    // Typical ambient RMS ≈ 0.002; hard slap ≈ 0.04–0.10.
    // At scale 80: slap RMS 0.04 → 3.2 "g", comfortably above the 1.5 g default threshold.
    private let rmsScale: Double = 80.0

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

        // Map to synthetic sensor sample.
        // x = 0, z = –1 (gravity constant) so the detector's gravity filter
        // zeroes out those axes and only the dynamic Y component drives magnitude.
        subject.send(SensorSample(
            x: 0,
            y: rms * rmsScale,
            z: -1.0,
            timestamp: ProcessInfo.processInfo.systemUptime
        ))
    }
}
