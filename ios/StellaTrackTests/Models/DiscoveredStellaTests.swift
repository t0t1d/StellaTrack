import XCTest
import CoreBluetooth
@testable import StellaTrack

final class DiscoveredStellaTests: XCTestCase {

    func testCreationWithAllFields() {
        let id = UUID()
        let peripheralID = UUID()

        var stella = DiscoveredStella(
            id: id,
            name: "Stella-ABC",
            rssi: -65,
            peripheralIdentifier: peripheralID,
            peripheral: nil
        )

        XCTAssertEqual(stella.id, id)
        XCTAssertEqual(stella.name, "Stella-ABC")
        XCTAssertEqual(stella.rssi, -65)
        XCTAssertEqual(stella.peripheralIdentifier, peripheralID)
        XCTAssertNil(stella.peripheral)
    }

    func testRSSIIsMutable() {
        let id = UUID()
        var stella = DiscoveredStella(
            id: id,
            name: "Stella-XYZ",
            rssi: -70,
            peripheralIdentifier: UUID(),
            peripheral: nil
        )

        stella.rssi = -55
        XCTAssertEqual(stella.rssi, -55)
    }
}
