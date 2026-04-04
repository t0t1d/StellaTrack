import Foundation

struct DiscoveredStella: Identifiable {
    let id: UUID
    let name: String
    let rssi: Int
    let peripheralIdentifier: UUID
}
