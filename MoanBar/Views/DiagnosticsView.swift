import SwiftUI

// MARK: - Live diagnostics panel

struct DiagnosticsView: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                sensorStatusBanner

                Divider()

                Group {
                    sectionHeader("Raw Accelerometer")
                    DiagRow(label: "X", value: String(format: "%+.4f g", vm.diagnostics.rawX))
                    DiagRow(label: "Y", value: String(format: "%+.4f g", vm.diagnostics.rawY))
                    DiagRow(label: "Z", value: String(format: "%+.4f g", vm.diagnostics.rawZ))
                }

                Divider()

                Group {
                    sectionHeader("Detection")
                    DiagRow(label: "Dynamic magnitude",
                            value: String(format: "%.4f g", vm.diagnostics.filteredMagnitude))
                    DiagRow(label: "Threshold",
                            value: String(format: "%.2f g", vm.diagnostics.threshold))

                    // Hit indicator — glows when in an impact window
                    HStack(spacing: 8) {
                        Circle()
                            .fill(vm.diagnostics.hitDetected ? Color.orange : Color.secondary.opacity(0.25))
                            .frame(width: 12, height: 12)
                            .animation(.easeInOut(duration: 0.1), value: vm.diagnostics.hitDetected)
                        Text("Impact window")
                            .foregroundStyle(vm.diagnostics.hitDetected ? .orange : .secondary)
                            .fontWeight(vm.diagnostics.hitDetected ? .semibold : .regular)
                    }
                }

                Divider()

                Group {
                    sectionHeader("Session")
                    DiagRow(label: "Total slaps", value: "\(vm.slapCount)")
                    DiagRow(label: "Sensor", value: vm.sensorAvailable ? "available" : "unavailable")
                    DiagRow(label: "Mode", value: vm.usingMockMode ? "mock" : "hardware")
                }

                if vm.usingMockMode {
                    Divider()
                    Button("Simulate slap") {
                        vm.simulateMockSlap(intensity: 2.5)
                    }
                    Text("Injects a synthetic spike through the full detection pipeline.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }
            .padding()
        }
        .font(.system(.body, design: .monospaced))
        .frame(minWidth: 340, minHeight: 300)
    }

    // MARK: - Sub-views

    private var sensorStatusBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: vm.sensorAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(vm.sensorAvailable ? .green : .red)
                .font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                Text(vm.usingMockMode ? "Mock Mode Active" :
                     (vm.sensorAvailable ? "Hardware Sensor Active" : "Sensor Unavailable"))
                    .fontWeight(.semibold)
                if !vm.sensorAvailable && !vm.usingMockMode {
                    Text("CoreMotion accelerometer not found on this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

// MARK: - Reusable row

private struct DiagRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
    }
}
