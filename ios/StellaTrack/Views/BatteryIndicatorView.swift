import SwiftUI

struct BatteryIndicatorView: View {
    let level: Double?

    private var iconName: String {
        guard let level else { return "battery.0" }
        switch level {
        case 75...: return "battery.100"
        case 50..<75: return "battery.75"
        case 25..<50: return "battery.50"
        case 1..<25: return "battery.25"
        default: return "battery.0"
        }
    }

    private var tintColor: Color {
        guard let level else { return .secondary }
        return level < 20 ? .red : .primary
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .foregroundColor(tintColor)
            if let level {
                Text("\(Int(level))%")
                    .font(.caption2)
                    .foregroundColor(tintColor)
            } else {
                Text("--")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
