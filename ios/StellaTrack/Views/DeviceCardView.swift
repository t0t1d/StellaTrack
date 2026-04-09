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

    // MARK: - Effective state

    private var isRangingWithDistance: Bool {
        device.connectionStatus == .ranging && device.lastSeen != nil && device.alertEngine.latestDistance > 0
    }

    private var isBLEOnly: Bool {
        (device.connectionStatus == .connected || device.connectionStatus == .ranging) && !isRangingWithDistance
    }

    // MARK: - Middle column content

    private var distanceText: String {
        if isRangingWithDistance {
            return String(format: "%.1f m", device.alertEngine.latestDistance)
        }
        if isBLEOnly {
            return "Distance not available"
        }
        switch device.connectionStatus {
        case .searching: return "Reconnecting..."
        case .disconnected: return "Disconnected"
        default: return ""
        }
    }

    private var distanceColor: Color {
        if isRangingWithDistance { return .primary }
        if isBLEOnly { return .orange }
        return .secondary
    }

    // MARK: - Right column: signal icon

    private var signalIcon: (name: String, color: Color) {
        if isBLEOnly {
            return ("exclamationmark.triangle.fill", .orange)
        }
        switch device.connectionStatus {
        case .searching:
            return ("antenna.radiowaves.left.and.right", .orange)
        default:
            return ("wifi.slash", .secondary)
        }
    }

    /// More bars = closer distance
    private var signalWaveVariant: Int {
        guard isRangingWithDistance else { return 0 }
        let dist = device.alertEngine.latestDistance
        if dist < 2 { return 3 }
        if dist < 5 { return 2 }
        return 1
    }

    // MARK: - Relative time

    private static func relativeTimeText(from lastSeen: Date?, now: Date) -> String? {
        guard let lastSeen else { return nil }
        let elapsed = now.timeIntervalSince(lastSeen)
        if elapsed < 60 { return "just now" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m ago" }
        if elapsed < 86400 { return "\(Int(elapsed / 3600))h ago" }
        return "\(Int(elapsed / 86400))d ago"
    }

    private var showsRelativeTime: Bool {
        !isRangingWithDistance && !isBLEOnly
    }

    // MARK: - Body

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
                Text(distanceText)
                    .font(.subheadline)
                    .foregroundStyle(distanceColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                BatteryIndicatorView(level: device.batteryLevel)

                signalView

                if showsRelativeTime {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        if let timeText = Self.relativeTimeText(from: device.lastSeen, now: context.date) {
                            Text(timeText)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var signalView: some View {
        if device.isMock {
            EmptyView()
        } else if isRangingWithDistance {
            signalBars
                .frame(height: 12)
        } else {
            Image(systemName: signalIcon.name)
                .font(.caption)
                .foregroundStyle(signalIcon.color)
        }
    }

    /// 3 ascending bars; filled bars indicate proximity
    private var signalBars: some View {
        let bars = signalWaveVariant
        return HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < bars ? Color.green : Color.secondary.opacity(0.3))
                    .frame(width: 3, height: CGFloat(4 + i * 4))
            }
        }
    }
}
