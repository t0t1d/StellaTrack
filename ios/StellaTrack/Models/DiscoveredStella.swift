import Foundation
import CoreBluetooth

struct DiscoveredStella: Identifiable {
    let id: UUID
    let name: String
    var rssi: Int
    let peripheralIdentifier: UUID
    let peripheral: CBPeripheral?
}
