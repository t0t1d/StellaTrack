import SwiftUI

struct DeviceSummaryStrip: View {
    @ObservedObject var device: TrackedDevice
    let onShowDetail: () -> Void

    private var alertColor: Color {
        switch device.alertEngine.currentLevel {
        case .safe: return .green
        case .warning: return .yellow
        case .alert: return .red
        }
    }

    private var distanceText: String {
        String(format: "%.1f m away", device.alertEngine.latestDistance)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(alertColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "figure.child")
                        .font(.title3)
                        .foregroundStyle(alertColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(distanceText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                BatteryIndicatorView(level: device.batteryLevel)
            }

            Button(action: onShowDetail) {
                Text("Show Detail")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
