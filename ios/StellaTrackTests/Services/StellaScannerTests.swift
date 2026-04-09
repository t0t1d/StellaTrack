import XCTest
import Combine
import CoreBluetooth
@testable import StellaTrack

@MainActor
final class StellaScannerTests: XCTestCase {
    var scanner: StellaScanner!
    var mockCentral: MockCentralManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        mockCentral = MockCentralManager()
        scanner = StellaScanner(centralManager: mockCentral)
        cancellables = []
    }

    func testInitialStateIsIdle() {
        XCTAssertEqual(scanner.scanningState, .idle)
        XCTAssertTrue(scanner.discoveredDevices.isEmpty)
    }

    func testStartScanWhenPoweredOn() {
        mockCentral.fakeState = .poweredOn
        scanner.handleBluetoothStateUpdate()

        scanner.startScan()

        XCTAssertEqual(scanner.scanningState, .scanning)
        XCTAssertTrue(mockCentral.isScanning)
        XCTAssertEqual(mockCentral.lastScanServiceUUIDs, StellaConstants.scanServiceUUIDs)
    }

    func testStartScanWhenPoweredOffSetsWaitingState() {
        mockCentral.fakeState = .poweredOff
        scanner.handleBluetoothStateUpdate()

        scanner.startScan()

        XCTAssertEqual(scanner.scanningState, .waitingForBluetooth)
        XCTAssertFalse(mockCentral.isScanning)
    }

    func testAutoStartsScanWhenBluetoothPowersOn() {
        mockCentral.fakeState = .poweredOff
        scanner.handleBluetoothStateUpdate()
        scanner.startScan()
        XCTAssertEqual(scanner.scanningState, .waitingForBluetooth)

        mockCentral.fakeState = .poweredOn
        scanner.handleBluetoothStateUpdate()

        XCTAssertEqual(scanner.scanningState, .scanning)
        XCTAssertTrue(mockCentral.isScanning)
    }

    func testStopScan() {
        mockCentral.fakeState = .poweredOn
        scanner.handleBluetoothStateUpdate()
        scanner.startScan()

        scanner.stopScan()

        XCTAssertEqual(scanner.scanningState, .stopped)
        XCTAssertTrue(mockCentral.didStopScan)
    }

    func testDiscoverPeripheralAddsDevice() {
        mockCentral.fakeState = .poweredOn
        scanner.handleBluetoothStateUpdate()
        scanner.startScan()

        let peripheralID = UUID()
        scanner.handleDiscoveredPeripheral(
            identifier: peripheralID,
            name: "Stella-TEST",
            rssi: -55,
            peripheral: nil
        )

        XCTAssertEqual(scanner.discoveredDevices.count, 1)
        XCTAssertEqual(scanner.discoveredDevices.first?.name, "Stella-TEST")
        XCTAssertEqual(scanner.discoveredDevices.first?.rssi, -55)
        XCTAssertEqual(scanner.discoveredDevices.first?.peripheralIdentifier, peripheralID)
    }

    func testDiscoverSamePeripheralUpdatesRSSI() {
        mockCentral.fakeState = .poweredOn
        scanner.handleBluetoothStateUpdate()
        scanner.startScan()

        let peripheralID = UUID()
        scanner.handleDiscoveredPeripheral(
            identifier: peripheralID,
            name: "Stella-TEST",
            rssi: -55,
            peripheral: nil
        )
        scanner.handleDiscoveredPeripheral(
            identifier: peripheralID,
            name: "Stella-TEST",
            rssi: -40,
            peripheral: nil
        )

        XCTAssertEqual(scanner.discoveredDevices.count, 1)
        XCTAssertEqual(scanner.discoveredDevices.first?.rssi, -40)
    }

    func testStartScanClearsPreviousDevices() {
        mockCentral.fakeState = .poweredOn
        scanner.handleBluetoothStateUpdate()
        scanner.startScan()

        scanner.handleDiscoveredPeripheral(
            identifier: UUID(),
            name: "Stella-1",
            rssi: -50,
            peripheral: nil
        )
        XCTAssertEqual(scanner.discoveredDevices.count, 1)

        scanner.startScan()
        XCTAssertTrue(scanner.discoveredDevices.isEmpty)
    }
}

// MARK: - Mock Central Manager

@MainActor
final class MockCentralManager: CentralManaging {
    var fakeState: CBManagerState = .unknown
    var state: CBManagerState { fakeState }

    private(set) var isScanning = false
    private(set) var didStopScan = false
    private(set) var lastScanServiceUUIDs: [CBUUID]?
    var connectCalled = false
    var connectPeripheralCalled = false
    var cancelConnectionCalled = false

    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) {
        isScanning = true
        lastScanServiceUUIDs = serviceUUIDs
    }

    func stopScan() {
        isScanning = false
        didStopScan = true
    }

    func connect(_ peripheral: CBPeripheral, options: [String: Any]?) {
        connectCalled = true
    }

    func cancelPeripheralConnection(_ peripheral: CBPeripheral) {
        cancelConnectionCalled = true
    }

    func connectPeripheral(identifier: UUID, options: [String: Any]?) {
        connectCalled = true
        connectPeripheralCalled = true
    }

    func cancelPeripheralConnection(identifier: UUID) {
        cancelConnectionCalled = true
    }
}
