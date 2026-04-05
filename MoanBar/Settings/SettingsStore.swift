import Foundation
import Combine

// MARK: - Persistent settings

/// All user preferences backed by UserDefaults.
/// Uses @Published so SwiftUI views and Combine chains react immediately.
final class SettingsStore: ObservableObject {

    // MARK: - Behaviour toggles

    @Published var isEnabled: Bool {
        didSet { save(isEnabled, for: .isEnabled) }
    }
    @Published var soundEnabled: Bool {
        didSet { save(soundEnabled, for: .soundEnabled) }
    }
    @Published var overlayEnabled: Bool {
        didSet { save(overlayEnabled, for: .overlayEnabled) }
    }
    @Published var mockMode: Bool {
        didSet { save(mockMode, for: .mockMode) }
    }
    @Published var launchAtLogin: Bool {
        didSet { save(launchAtLogin, for: .launchAtLogin) }
    }

    // MARK: - Detection

    /// Threshold in g units. Exposed to the Sensitivity slider.
    @Published var sensitivity: Double {
        didSet { save(sensitivity, for: .sensitivity) }
    }
    /// Minimum seconds between triggered events.
    @Published var cooldown: Double {
        didSet { save(cooldown, for: .cooldown) }
    }

    // MARK: - Volume

    @Published var minVolume: Double {
        didSet { save(minVolume, for: .minVolume) }
    }
    @Published var maxVolume: Double {
        didSet { save(maxVolume, for: .maxVolume) }
    }

    // MARK: - Init

    init() {
        let d = UserDefaults.standard
        isEnabled     = d.optionalBool(Key.isEnabled.rawValue)    ?? true
        soundEnabled  = d.optionalBool(Key.soundEnabled.rawValue) ?? true
        overlayEnabled = d.optionalBool(Key.overlayEnabled.rawValue) ?? true
        mockMode      = d.optionalBool(Key.mockMode.rawValue)     ?? false
        launchAtLogin = d.optionalBool(Key.launchAtLogin.rawValue) ?? false
        sensitivity   = d.optionalDouble(Key.sensitivity.rawValue) ?? 1.5
        cooldown      = d.optionalDouble(Key.cooldown.rawValue)    ?? 0.15
        minVolume     = d.optionalDouble(Key.minVolume.rawValue)   ?? 0.10
        maxVolume     = d.optionalDouble(Key.maxVolume.rawValue)   ?? 0.90
    }

    // MARK: - Private

    private enum Key: String {
        case isEnabled      = "mb.isEnabled"
        case soundEnabled   = "mb.soundEnabled"
        case overlayEnabled = "mb.overlayEnabled"
        case mockMode       = "mb.mockMode"
        case launchAtLogin  = "mb.launchAtLogin"
        case sensitivity    = "mb.sensitivity"
        case cooldown       = "mb.cooldown"
        case minVolume      = "mb.minVolume"
        case maxVolume      = "mb.maxVolume"
    }

    private func save(_ value: some Any, for key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
}

// MARK: - UserDefaults helpers

private extension UserDefaults {
    func optionalBool(_ key: String) -> Bool? {
        object(forKey: key) as? Bool
    }
    func optionalDouble(_ key: String) -> Double? {
        object(forKey: key) as? Double
    }
    func optionalString(_ key: String) -> String? {
        object(forKey: key) as? String
    }
}
