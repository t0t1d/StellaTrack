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

    // MARK: - Persistence

    private static var storageDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DistanceHistory", isDirectory: true)
    }

    private static func fileURL(for deviceID: UUID) -> URL {
        storageDirectory.appendingPathComponent("\(deviceID.uuidString).bin")
    }

    func save(for deviceID: UUID) {
        let dir = Self.storageDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        pruneOlderThan(hours: 24)
        var records: [PersistedPoint] = []
        records.reserveCapacity(points.count)
        for p in points {
            records.append(PersistedPoint(
                distance: p.distance,
                dx: p.direction?.x ?? .nan,
                dy: p.direction?.y ?? .nan,
                dz: p.direction?.z ?? .nan,
                timestamp: p.timestamp.timeIntervalSince1970
            ))
        }
        let data = records.withUnsafeBufferPointer { Data(buffer: $0) }
        try? data.write(to: Self.fileURL(for: deviceID), options: .atomic)
    }

    func loadFromDisk(for deviceID: UUID) {
        let url = Self.fileURL(for: deviceID)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return }

        let stride = MemoryLayout<PersistedPoint>.stride
        guard data.count % stride == 0 else { return }
        let count = data.count / stride

        let loaded: [PersistedPoint] = data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return [] }
            return Array(UnsafeBufferPointer(start: base.assumingMemoryBound(to: PersistedPoint.self), count: count))
        }

        let now = Date()
        let cutoff = now.timeIntervalSince1970 - 86400
        points = loaded.compactMap { p in
            guard p.timestamp >= cutoff else { return nil }
            let dir: simd_float3? = p.dx.isNaN ? nil : simd_float3(p.dx, p.dy, p.dz)
            return HistoryPoint(distance: p.distance, direction: dir, timestamp: Date(timeIntervalSince1970: p.timestamp))
        }
    }

    static func deleteFile(for deviceID: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: deviceID))
    }
}

private struct PersistedPoint {
    let distance: Double
    let dx: Float
    let dy: Float
    let dz: Float
    let timestamp: TimeInterval
}
