import SwiftUI

// MARK: - Settings window (tabbed)

struct SettingsView: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
                .environmentObject(vm)

            AudioTab()
                .tabItem { Label("Audio", systemImage: "speaker.wave.2") }
                .environmentObject(vm)

            DiagnosticsView()
                .tabItem { Label("Diagnostics", systemImage: "waveform.path.ecg") }
                .environmentObject(vm)
        }
        .frame(minWidth: 480, minHeight: 380)
        .padding(20)
    }
}

// MARK: - General tab

private struct GeneralTab: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        Form {
            // ── App behaviour ───────────────────────────────────────────────
            Section("Behaviour") {
                Toggle("Enable MoanBar", isOn: $vm.settings.isEnabled)

                HStack(spacing: 12) {
                    ModeCard(
                        icon: "speaker.wave.2.fill",
                        title: "Only Sound",
                        selected: !vm.settings.overlayEnabled
                    ) { vm.settings.overlayEnabled = false }

                    ModeCard(
                        icon: "figure.wave",
                        title: "Sound with Live2D",
                        selected: vm.settings.overlayEnabled
                    ) { vm.settings.overlayEnabled = true }
                }
                .disabled(!vm.settings.isEnabled)

                Toggle("Mock mode (no hardware required)", isOn: $vm.settings.mockMode)

                HStack {
                    Toggle("Launch at login", isOn: $vm.settings.launchAtLogin)
                        .disabled(true)
                    Text("(coming soon)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // ── Detection ───────────────────────────────────────────────────
            Section("Detection") {
                LabeledSlider(
                    label: "Sensitivity",
                    value: $vm.settings.sensitivity,
                    range: 0.3...5.0,
                    step: 0.05,
                    format: "%.2f g",
                    helpText: "Lower = more sensitive. Default 1.5 g."
                )

                LabeledSlider(
                    label: "Cooldown",
                    value: $vm.settings.cooldown,
                    range: 0.1...2.0,
                    step: 0.05,
                    format: "%.2f s",
                    helpText: "Minimum time between slap events."
                )
            }

            // ── Session ─────────────────────────────────────────────────────
            Section("Session") {
                HStack {
                    Text("Slaps: \(vm.slapCount)")
                    Spacer()
                    Button("Reset") { vm.resetCounter() }
                }

                HStack {
                    Button("Test Slap") { vm.testSlap() }
                    Button("Test Overlay") { vm.testOverlay() }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Audio tab

private struct AudioTab: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        Form {
            Section("Playback") {
                Toggle("Enable sound", isOn: $vm.settings.soundEnabled)

                LabeledSlider(
                    label: "Min volume",
                    value: $vm.settings.minVolume,
                    range: 0.0...1.0,
                    step: 0.05,
                    format: "%.0f %%",
                    formatMultiplier: 100
                )

                LabeledSlider(
                    label: "Max volume",
                    value: $vm.settings.maxVolume,
                    range: 0.0...1.0,
                    step: 0.05,
                    format: "%.0f %%",
                    formatMultiplier: 100
                )
            }

            Section("Test") {
                Button("Play test sound") { vm.testSlap() }
            }

            Section("Assets") {
                HStack {
                    Text("Clips loaded")
                    Spacer()
                    Text("\(vm.settings.soundEnabled ? "—" : "0")")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Mode card button

struct ModeCard: View {
    let icon: String
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                Text(title)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .cornerRadius(10)
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reusable slider row

private struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    var formatMultiplier: Double = 1.0
    var helpText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: format, value * formatMultiplier))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
            if let help = helpText {
                Text(help)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
