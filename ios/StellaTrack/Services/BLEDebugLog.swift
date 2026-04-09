import Foundation
import Combine
import os

@MainActor
final class BLEDebugLog: ObservableObject {
    static let shared = BLEDebugLog()

    @Published private(set) var entries: [Entry] = []

    struct Entry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: Level
        let message: String

        enum Level: String {
            case info = "ℹ️"
            case success = "✅"
            case warning = "⚠️"
            case error = "❌"
        }

        var formatted: String {
            let tf = Self.timeFormatter
            return "\(tf.string(from: timestamp)) \(level.rawValue) \(message)"
        }

        private static let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss.SSS"
            return f
        }()
    }

    private let osLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "StellaTrack", category: "StellaBLE")

    func log(_ message: String, level: Entry.Level = .info) {
        let entry = Entry(timestamp: Date(), level: level, message: message)
        entries.append(entry)
        if entries.count > 200 { entries.removeFirst(entries.count - 200) }

        switch level {
        case .info, .success: osLog.info("\(message)")
        case .warning: osLog.warning("\(message)")
        case .error: osLog.error("\(message)")
        }
    }

    func clear() {
        entries.removeAll()
    }
}
