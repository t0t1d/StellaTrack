import XCTest
import Combine
import CoreBluetooth
@testable import StellaTrack

@MainActor
final class DeviceManagerTests: XCTestCase {
    var manager: DeviceManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        UserDefaults.standard.removeObject(forKey: "savedDevices")
        manager = DeviceManager()
        cancellables = []
    }

    func testInitiallyEmpty() {
        XCTAssertTrue(manager.devices.isEmpty)
    }

    func testAddMockDevice() {
        manager.addMockDevice(name: "Child 1")
        XCTAssertEqual(manager.devices.count, 1)
        XCTAssertEqual(manager.devices.first?.name, "Child 1")
    }

    func testRemoveDevice() {
        manager.addMockDevice(name: "Child 1")
        let id = manager.devices.first!.id
        manager.removeDevice(id: id)
        XCTAssertTrue(manager.devices.isEmpty)
    }

    func testDeviceHasAlertEngine() {
        manager.addMockDevice(name: "Child 1")
        let device = manager.devices.first!
        XCTAssertEqual(device.alertEngine.currentLevel, .safe)
    }

    func testDeviceHasDistanceHistory() {
        manager.addMockDevice(name: "Child 1")
        let device = manager.devices.first!
        XCTAssertTrue(device.distanceHistory.readings(for: .thirtyMinutes).isEmpty)
    }

    // MARK: - Stella Device Tests

    func testAddStellaDeviceWithProvider() {
        let mockPeripheral = MockPeripheral(identifier: UUID(), name: "Stella-1")
        let mockCentral = MockCentralManager()
        let provider = StellaDistanceProvider(peripheral: mockPeripheral, centralManager: mockCentral)

        manager.addStellaDevice(name: "Stella-1", provider: provider)

        XCTAssertEqual(manager.devices.count, 1)
        XCTAssertEqual(manager.devices.first?.name, "Stella-1")
        XCTAssertFalse(manager.devices.first?.isMock ?? true)
    }

    func testSaveNowPersistsPeripheralIdentifier() {
        let peripheralID = UUID()
        let mockPeripheral = MockPeripheral(identifier: peripheralID, name: "Stella-Persist")
        let mockCentral = MockCentralManager()
        let provider = StellaDistanceProvider(peripheral: mockPeripheral, centralManager: mockCentral)

        manager.addStellaDevice(name: "Stella-Persist", provider: provider)
        manager.saveNow()

        let records = manager.persistenceService.load()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.peripheralIdentifier, peripheralID.uuidString)
    }

    func testSaveNowMockDeviceHasNilPeripheralIdentifier() {
        manager.addMockDevice(name: "Mock-1")
        manager.saveNow()

        let records = manager.persistenceService.load()
        XCTAssertEqual(records.count, 1)
        XCTAssertNil(records.first?.peripheralIdentifier)
    }

    // MARK: - Auto-Reconnect

    func testRestoreCreatesStubForStellaWithoutCentral() {
        let peripheralID = UUID()
        let record = DeviceRecord(
            id: UUID(),
            name: "Stella-Saved",
            icon: "tag.fill",
            alertEnabled: true,
            thresholdDistance: 10.0,
            persistenceDuration: 5.0,
            alertDuration: nil,
            isMock: false,
            mockLatitude: nil,
            mockLongitude: nil,
            peripheralIdentifier: peripheralID.uuidString
        )
        manager.persistenceService.save([record])

        let restoredManager = DeviceManager()
        XCTAssertEqual(restoredManager.devices.count, 1)
        XCTAssertEqual(restoredManager.devices.first?.name, "Stella-Saved")
        XCTAssertTrue(restoredManager.devices.first?.provider is StubDistanceProvider)
    }

    func testRestoreCreatesStellaProviderWhenCentralProvided() {
        let peripheralID = UUID()
        let record = DeviceRecord(
            id: UUID(),
            name: "Stella-Reconnect",
            icon: "tag.fill",
            alertEnabled: true,
            thresholdDistance: 10.0,
            persistenceDuration: 5.0,
            alertDuration: nil,
            isMock: false,
            mockLatitude: nil,
            mockLongitude: nil,
            peripheralIdentifier: peripheralID.uuidString
        )
        manager.persistenceService.save([record])

        let mockCentral = MockCentralManager()
        mockCentral.fakeState = .poweredOn
        let restoredManager = DeviceManager(centralManager: mockCentral)

        XCTAssertEqual(restoredManager.devices.count, 1)
        XCTAssertTrue(restoredManager.devices.first?.provider is StellaDistanceProvider)
        XCTAssertTrue(mockCentral.connectCalled)
    }
}
