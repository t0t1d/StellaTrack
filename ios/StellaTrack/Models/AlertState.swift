import Foundation

enum AlertLevel: String, Equatable, Sendable {
    case safe
    case warning
    case alert
}

struct AlertEvent: Equatable, Sendable {
    let level: AlertLevel
    let distance: Double
    let timestamp: Date
}

struct AlertSettings: Equatable, Sendable, Codable {
    var thresholdDistance: Double
    var persistenceDuration: TimeInterval
    var alertEnabled: Bool
    var alertDuration: TimeInterval

    nonisolated static let `default` = AlertSettings(thresholdDistance: 10.0, persistenceDuration: 5.0, alertEnabled: false, alertDuration: .infinity)

    static let durationOptions: [(label: String, value: TimeInterval)] = [
        ("5 min", 300),
        ("15 min", 900),
        ("30 min", 1800),
        ("1 hr", 3600),
        ("3 hr", 10800),
        ("6 hr", 21600),
        ("∞", .infinity)
    ]

    static let escalateOptions: [TimeInterval] = [5, 10, 15, 30]
}
