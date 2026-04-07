import Foundation

struct DeviceRecord: Codable, Identifiable {
    let id: UUID
    var name: String
    var icon: String
    var alertEnabled: Bool
    var thresholdDistance: Double
    var persistenceDuration: TimeInterval
    var alertDuration: Double?
    var isMock: Bool
    var mockLatitude: Double?
    var mockLongitude: Double?
}

@MainActor
final class PersistenceService {
    private static let savedDevicesKey = "savedDevices"

    func save(_ records: [DeviceRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: Self.savedDevicesKey)
    }

    func load() -> [DeviceRecord] {
        guard let data = UserDefaults.standard.data(forKey: Self.savedDevicesKey) else {
            return []
        }
        return (try? JSONDecoder().decode([DeviceRecord].self, from: data)) ?? []
    }
}
