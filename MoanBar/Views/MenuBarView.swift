import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // ── Status bar ──────────────────────────────────────────────────
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)

            Divider()

            // ── Session counter ─────────────────────────────────────────────
            HStack {
                Text("Slaps this session")
                    .font(.callout)
                Spacer()
                Text("\(vm.slapCount)")
                    .font(.callout.monospacedDigit().weight(.semibold))
            }
            .padding(.horizontal, 4)

            Button("Reset counter") { vm.resetCounter() }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Divider()

            // ── Character picker ────────────────────────────────────────────
            HStack(spacing: 8) {
                ModeCard(
                    icon: "figure.wave",
                    title: "Anime Girl",
                    selected: vm.settings.character == "Girl"
                ) { vm.settings.character = "Girl" }

                ModeCard(
                    icon: "pawprint.fill",
                    title: "Cat",
                    selected: vm.settings.character == "Cat"
                ) { vm.settings.character = "Cat" }
            }
            .padding(.horizontal, 4)
            .disabled(!vm.settings.isEnabled)

            Divider()

            // ── Mode picker ─────────────────────────────────────────────────
            HStack(spacing: 8) {
                ModeCard(
                    icon: "speaker.wave.2.fill",
                    title: "Only Sound",
                    selected: !vm.settings.overlayEnabled
                ) { vm.settings.overlayEnabled = false }

                ModeCard(
                    icon: "photo.fill",
                    title: "Sound with Image",
                    selected: vm.settings.overlayEnabled
                ) { vm.settings.overlayEnabled = true }
            }
            .padding(.horizontal, 4)
            .disabled(!vm.settings.isEnabled)

            Divider()

            // ── Quick actions ───────────────────────────────────────────────
            MenuRowButton(label: "Test slap", icon: "hand.tap") {
                vm.testSlap()
            }
            MenuRowButton(label: "Test overlay", icon: "photo.on.rectangle") {
                vm.testOverlay()
            }

            Divider()

            MenuRowButton(label: "Settings…", icon: "gearshape") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            MenuRowButton(label: "Quit MoanBar", icon: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(10)
        .frame(width: 230)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        guard vm.settings.isEnabled else { return .gray }
        if vm.usingMockMode { return .orange }
        return vm.sensorAvailable ? .green : .red
    }

    private var statusLabel: String {
        guard vm.settings.isEnabled else { return "Disabled" }
        if vm.usingMockMode { return "Mock mode" }
        return vm.sensorAvailable ? "Active" : "Sensor unavailable"
    }
}

// MARK: - Reusable row button

private struct MenuRowButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}
