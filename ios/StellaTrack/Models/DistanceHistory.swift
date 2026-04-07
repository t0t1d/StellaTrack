import Foundation
import simd

enum ChartTimeWindow: Double, CaseIterable, Sendable {
    case thirtyMinutes = 1800
    case twoHours = 7200
    case twentyFourHours = 86400

    var label: String {
        switch self {
        case .thirtyMinutes: return "30m"
        case .twoHours: return "2h"
        case .twentyFourHours: return "24h"
        }
    }
}

struct HistoryPoint: Sendable {
    let distance: Double
    let direction: simd_float3?
    let timestamp: Date
}

@MainActor
class DistanceHistory {
    /// 24h at one sample per 10s — bounds memory while matching max chart window.
    private static let maxStoredPoints = 8640

    private var points: [HistoryPoint] = []

    func add(distance: Double, direction: simd_float3?, at timestamp: Date) {
        points.append(HistoryPoint(distance: distance, direction: direction, timestamp: timestamp))
        pruneOlderThan(hours: 24, relativeTo: Date())
        if points.count > Self.maxStoredPoints {
            points = Array(points.suffix(Self.maxStoredPoints))
        }
    }

    func readings(for window: ChartTimeWindow, relativeTo now: Date = Date()) -> [HistoryPoint] {
        let cutoff = now.addingTimeInterval(-window.rawValue)
        return points.filter { $0.timestamp >= cutoff }
    }

    func downsampledReadings(for window: ChartTimeWindow, maxPoints: Int = 500, relativeTo now: Date = Date()) -> [HistoryPoint] {
        let filtered = readings(for: window, relativeTo: now)
        guard filtered.count > maxPoints else { return filtered }
        let step = Double(filtered.count) / Double(maxPoints)
        return stride(from: 0, to: Double(filtered.count), by: step).map { filtered[Int($0)] }
    }

    func pruneOlderThan(hours: Int, relativeTo now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-Double(hours) * 3600)
        points.removeAll { $0.timestamp < cutoff }
    }
}
