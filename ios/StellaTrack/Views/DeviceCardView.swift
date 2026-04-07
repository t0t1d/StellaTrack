import SwiftUI

struct DeviceCardView: View {
    @ObservedObject var device: TrackedDevice

    private var alertColor: Color {
        switch device.alertEngine.currentLevel {
        case .safe: return .green
        case .warning: return .yellow
        case .alert: return .red
        }
    }

    private var statusText: String {
        switch device.provider.currentConnectionStatus {
        case .disconnected: return "Disconnected"
        case .searching: return "Searching..."
        case .connected: return "Connected"
        case .ranging:
            return String(format: "%.1f m away", device.alertEngine.latestDistance)
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
                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
