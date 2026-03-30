import Foundation
import Combine
import AppKit

// MARK: - Central coordinator

/// Owns all subsystems and wires them together via Combine.
/// All @Published mutations must reach this object on the main thread.
final class AppViewModel: ObservableObject {

    // MARK: - Exposed state

    let settings = SettingsStore()

    @Published var diagnostics = DiagnosticsSnapshot()
    @Published var slapCount: Int = 0
    @Published var sensorAvailable: Bool = false
    @Published var usingMockMode: Bool = false

    // MARK: - Subsystems

    private let detector = SlapDetector()
    private let audioEngine = AudioEngine()
    private let overlayEngine = OverlayEngine()

    // Concrete provider — replaced when mockMode toggles
    private var sensorProvider: SensorProvider?
    private(set) var mockProvider: MockSensorProvider?  // exposed for UI-triggered slaps

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        loadAssets()
        setupSensor()
        bindSettings()
    }

    // MARK: - Assets

    private func loadAssets() {
        let base = Bundle.main.resourceURL

        if let soundsURL = base?.appendingPathComponent("Sounds") {
            audioEngine.loadClips(from: soundsURL)
        }
        if let imagesURL = base?.appendingPathComponent("Images") {
            overlayEngine.loadImages(from: imagesURL)
        }
    }

    // MARK: - Sensor setup

    private func setupSensor() {
        let real = SPUSensorProvider()
        let useMock = settings.mockMode || !real.isAvailable

        if useMock {
            usingMockMode = true
            sensorAvailable = settings.mockMode   // available in mock mode, "unavailable" if forced
            let mock = MockSensorProvider()
            mockProvider = mock
            sensorProvider = mock
        } else {
            usingMockMode = false
            sensorAvailable = true
            mockProvider = nil
            sensorProvider = real
        }

        guard let provider = sensorProvider else { return }

        // Pipe sensor samples → detector
        provider.samplePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sample in
                guard self?.settings.isEnabled == true else { return }
                self?.detector.processSample(sample)
            }
            .store(in: &cancellables)

        // Pipe diagnostics → UI
        detector.diagnosticsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snap in
                self?.diagnostics = snap
            }
            .store(in: &cancellables)

        // Pipe slap events → audio + overlay
        detector.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleSlap(event)
            }
            .store(in: &cancellables)

        if settings.isEnabled {
            provider.start()
        }
    }

    // MARK: - Settings → subsystem bindings

    private func bindSettings() {
        settings.$sensitivity
            .sink { [weak self] val in self?.detector.threshold = val }
            .store(in: &cancellables)

        settings.$cooldown
            .sink { [weak self] val in self?.detector.cooldownSeconds = val }
            .store(in: &cancellables)

        settings.$minVolume
            .sink { [weak self] val in self?.audioEngine.minVolume = Float(val) }
            .store(in: &cancellables)

        settings.$maxVolume
            .sink { [weak self] val in self?.audioEngine.maxVolume = Float(val) }
            .store(in: &cancellables)

        settings.$isEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                if enabled { self?.sensorProvider?.start() }
                else       { self?.sensorProvider?.stop() }
            }
            .store(in: &cancellables)

        // Rebuild sensor stack when mock mode changes
        settings.$mockMode
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.restartSensorStack()
            }
            .store(in: &cancellables)
    }

    private func restartSensorStack() {
        sensorProvider?.stop()
        detector.reset()
        cancellables.removeAll()
        // Slight defer so any in-flight Combine events drain first
        DispatchQueue.main.async { [weak self] in
            self?.setupSensor()
            self?.bindSettings()
        }
    }

    // MARK: - Event handling

    private func handleSlap(_ event: SlapEvent) {
        slapCount += 1
        if settings.soundEnabled   { audioEngine.play(intensity: event.intensity) }
        if settings.overlayEnabled { overlayEngine.show() }
        logger.info("Slap #\(self.slapCount) intensity=\(String(format:"%.2f", event.intensity))")
    }

    // MARK: - Actions (called from UI)

    /// Runs the same pipeline as a real hit. Volume ≈ 70 % intensity.
    func testSlap() {
        let synthetic = SlapEvent(
            timestamp: ProcessInfo.processInfo.systemUptime,
            intensity: 0.70,
            rawMagnitude: 2.0
        )
        handleSlap(synthetic)
    }

    func testOverlay() {
        overlayEngine.show()
    }

    func resetCounter() {
        slapCount = 0
    }

    /// Injects a synthetic hit through the real detector (mock mode only).
    func simulateMockSlap(intensity: Double = 2.5) {
        mockProvider?.simulateSlap(intensity: intensity)
    }
}
