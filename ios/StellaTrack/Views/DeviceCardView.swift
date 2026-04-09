import SwiftUI

struct DeviceCardView: View {
    @ObservedObject var device: TrackedDevice

    private var alertColor: Color {
        guard device.alertEngine.settings.alertEnabled else { return .gray }
        switch device.alertEngine.currentLevel {
        case .safe: return .green
        case .warning: return .yellow
        case .alert: return .red
        }
    }

    private var statusText: String {
        switch device.connectionStatus {
        case .disconnected: return "Disconnected"
        case .searching: return "Searching..."
        case .connected: return "Connected"
        case .ranging:
            if device.lastSeen != nil {
                return String(format: "%.1f m away", device.alertEngine.latestDistance)
            }
            return "Connected (BLE)"
        }
    }

    private var connectionIcon: (name: String, color: Color)? {
        guard !device.isMock else { return nil }
        switch device.connectionStatus {
        case .disconnected: return ("bolt.slash.fill", .red)
        case .searching: return ("antenna.radiowaves.left.and.right", .orange)
        case .connected: return ("link", .blue)
        case .ranging: return ("dot.radiowaves.right", .green)
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(alertColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: device.icon)
                    .font(.title2)
                    .foregroundColor(alertColor)
                if !device.alertEngine.settings.alertEnabled {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.gray)
                        .padding(3)
                        .background(.ultraThinMaterial, in: Circle())
                        .offset(x: 16, y: 16)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                HStack(spacing: 4) {
                    if let icon = connectionIcon {
                        Image(systemName: icon.name)
                            .font(.caption)
                            .foregroundStyle(icon.color)
                    }
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                BatteryIndicatorView(level: device.batteryLevel)
                if let lastSeen = device.lastSeen {
                    Text(lastSeen, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
