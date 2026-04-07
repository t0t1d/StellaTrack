import XCTest
import Combine
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
}
