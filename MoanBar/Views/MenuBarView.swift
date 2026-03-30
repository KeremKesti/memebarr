import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.openSettings) private var openSettings

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

            // ── Quick actions ───────────────────────────────────────────────
            MenuRowButton(label: "Test slap", icon: "hand.tap") {
                vm.testSlap()
            }
            MenuRowButton(label: "Test overlay", icon: "photo.on.rectangle") {
                vm.testOverlay()
            }

            Divider()

            MenuRowButton(label: "Settings…", icon: "gearshape") {
                openSettings()
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
