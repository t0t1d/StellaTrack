import XCTest
@testable import StellaTrack

@MainActor
final class PersistenceServiceTests: XCTestCase {
    let testKey = "savedDevices"
    var service: PersistenceService!

    override func setUp() {
        UserDefaults.standard.removeObject(forKey: testKey)
        service = PersistenceService()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: testKey)
    }

    func testRoundTripWithPeripheralIdentifier() {
        let id = UUID()
        let peripheralIDString = UUID().uuidString
        let record = DeviceRecord(
            id: id,
            name: "Stella",
            icon: "tag.fill",
            alertEnabled: true,
            thresholdDistance: 10.0,
            persistenceDuration: 5.0,
            alertDuration: nil,
            isMock: false,
            mockLatitude: nil,
            mockLongitude: nil,
            peripheralIdentifier: peripheralIDString
        )

        service.save([record])
        let loaded = service.load()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, id)
        XCTAssertEqual(loaded.first?.peripheralIdentifier, peripheralIDString)
    }

    func testRoundTripWithNilPeripheralIdentifier() {
        let record = DeviceRecord(
            id: UUID(),
            name: "Mock Child",
            icon: "figure.child",
            alertEnabled: false,
            thresholdDistance: 15.0,
            persistenceDuration: 3.0,
            alertDuration: nil,
            isMock: true,
            mockLatitude: 1.0,
            mockLongitude: 2.0,
            peripheralIdentifier: nil
        )

        service.save([record])
        let loaded = service.load()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertNil(loaded.first?.peripheralIdentifier)
    }

    func testBackwardCompatibilityDecodesLegacyRecords() {
        let legacyJSON = """
        [{"id":"11111111-1111-1111-1111-111111111111","name":"Old Device","icon":"tag.fill","alertEnabled":true,"thresholdDistance":10,"persistenceDuration":5,"isMock":false}]
        """
        UserDefaults.standard.set(legacyJSON.data(using: .utf8), forKey: testKey)

        let loaded = service.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Old Device")
        XCTAssertNil(loaded.first?.peripheralIdentifier)
    }
}
