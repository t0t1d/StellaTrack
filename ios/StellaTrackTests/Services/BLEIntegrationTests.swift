import XCTest
import Combine
import CoreBluetooth
@testable import StellaTrack

@MainActor
final class BLEIntegrationTests: XCTestCase {
    var mockCentral: MockCentralManager!
    var scanner: StellaScanner!
    var pairingManager: StellaPairingManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        mockCentral = MockCentralManager()
        mockCentral.fakeState = .poweredOn
        scanner = StellaScanner(centralManager: mockCentral)
        pairingManager = StellaPairingManager(centralManager: mockCentral)
        cancellables = []
    }

    func testScannerExposesItscentral() {
        XCTAssertTrue(scanner.central === mockCentral)
    }

    func testPairingManagerCreatedFromScannerCentral() {
        let pm = StellaPairingManager(centralManager: scanner.central)
        XCTAssertNotNil(pm)
        XCTAssertEqual(pm.pairingState, .idle)
    }

    func testFullScanPairFlow() {
        scanner.handleBluetoothStateUpdate()
        scanner.startScan()

        let peripheralID = UUID()
        scanner.handleDiscoveredPeripheral(
            identifier: peripheralID,
            name: "Stella-Flow",
            rssi: -50,
            peripheral: nil
        )

        let stella = scanner.discoveredDevices.first!
        pairingManager.pair(stella: stella)

        XCTAssertEqual(pairingManager.pairingState, .connecting)
        XCTAssertTrue(mockCentral.connectCalled)

        pairingManager.handleDidConnect()
        XCTAssertEqual(pairingManager.pairingState, .configuringUWB)
        XCTAssertNotNil(pairingManager.pairedProvider)

        pairingManager.handleRangingStarted()
        XCTAssertEqual(pairingManager.pairingState, .paired)
    }

    func testPairedProviderHasCorrectPeripheralIdentifier() {
        scanner.handleBluetoothStateUpdate()
        scanner.startScan()

        let peripheralID = UUID()
        scanner.handleDiscoveredPeripheral(
            identifier: peripheralID,
            name: "Stella-ID",
            rssi: -60,
            peripheral: nil
        )

        let stella = scanner.discoveredDevices.first!
        pairingManager.pair(stella: stella)
        pairingManager.handleDidConnect()

        XCTAssertEqual(pairingManager.pairedProvider?.peripheralIdentifier, peripheralID)
    }

    func testScannerForwardsConnectToConnectionDelegate() {
        scanner.connectionDelegate = pairingManager

        let peripheralID = UUID()
        scanner.handleDiscoveredPeripheral(
            identifier: peripheralID,
            name: "Stella-Delegate",
            rssi: -50,
            peripheral: nil
        )

        let stella = scanner.discoveredDevices.first!
        pairingManager.pair(stella: stella)

        scanner.handlePeripheralConnected(identifier: peripheralID)

        XCTAssertEqual(pairingManager.pairingState, .configuringUWB)
    }

    func testScannerForwardsDisconnectToConnectionDelegate() {
        scanner.connectionDelegate = pairingManager

        let peripheralID = UUID()
        scanner.handleDiscoveredPeripheral(
            identifier: peripheralID,
            name: "Stella-Disc",
            rssi: -50,
            peripheral: nil
        )

        let stella = scanner.discoveredDevices.first!
        pairingManager.pair(stella: stella)

        scanner.handlePeripheralConnectionFailed(identifier: peripheralID, error: NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Timeout"]))

        if case .failed = pairingManager.pairingState {
            // expected
        } else {
            XCTFail("Expected failed state, got \(pairingManager.pairingState)")
        }
    }
}
