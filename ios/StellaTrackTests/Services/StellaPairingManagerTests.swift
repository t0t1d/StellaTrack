import XCTest
import Combine
import CoreBluetooth
@testable import StellaTrack

@MainActor
final class StellaPairingManagerTests: XCTestCase {
    var pairingManager: StellaPairingManager!
    var mockCentral: MockCentralManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        mockCentral = MockCentralManager()
        mockCentral.fakeState = .poweredOn
        pairingManager = StellaPairingManager(centralManager: mockCentral)
        cancellables = []
    }

    func testInitialStateIsIdle() {
        XCTAssertEqual(pairingManager.pairingState, .idle)
    }

    func testPairTransitionsToConnecting() {
        let stella = makeStella()

        pairingManager.pair(stella: stella)

        XCTAssertEqual(pairingManager.pairingState, .connecting)
        XCTAssertTrue(mockCentral.connectCalled)
    }

    func testDidConnectTransitionsToConfiguringUWB() {
        let stella = makeStella()
        pairingManager.pair(stella: stella)

        pairingManager.handleDidConnect()

        XCTAssertEqual(pairingManager.pairingState, .configuringUWB)
    }

    func testDidFailToConnectTransitionsToFailed() {
        let stella = makeStella()
        pairingManager.pair(stella: stella)

        pairingManager.handleDidFailToConnect(
            error: NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection refused"])
        )

        if case .failed(let message) = pairingManager.pairingState {
            XCTAssertTrue(message.contains("Connection refused"))
        } else {
            XCTFail("Expected failed state")
        }
    }

    func testRangingStartedTransitionsToPaired() {
        let stella = makeStella()
        pairingManager.pair(stella: stella)
        pairingManager.handleDidConnect()

        pairingManager.handleRangingStarted()

        XCTAssertEqual(pairingManager.pairingState, .paired)
    }

    func testPairedProviderIsExposed() {
        let stella = makeStella()
        pairingManager.pair(stella: stella)
        pairingManager.handleDidConnect()
        pairingManager.handleRangingStarted()

        XCTAssertNotNil(pairingManager.pairedProvider)
    }

    func testResetClearsState() {
        let stella = makeStella()
        pairingManager.pair(stella: stella)
        pairingManager.handleDidConnect()
        pairingManager.handleRangingStarted()

        pairingManager.reset()

        XCTAssertEqual(pairingManager.pairingState, .idle)
        XCTAssertNil(pairingManager.pairedProvider)
    }

    func testDisconnectDuringConnectingTransitionsToFailed() {
        let stella = makeStella()
        pairingManager.pair(stella: stella)

        pairingManager.handleDidDisconnect(error: nil)

        if case .failed = pairingManager.pairingState {
            // expected
        } else {
            XCTFail("Expected failed state")
        }
    }

    func testDisconnectDuringUWBSetupRetriesConnection() {
        let stella = makeStella()
        pairingManager.pair(stella: stella)
        pairingManager.handleDidConnect()
        XCTAssertEqual(pairingManager.pairingState, .configuringUWB)

        mockCentral.connectCalled = false
        pairingManager.handleDidDisconnect(
            error: NSError(domain: "CBError", code: 6, userInfo: [NSLocalizedDescriptionKey: "The connection has timed out unexpectedly."])
        )

        XCTAssertEqual(pairingManager.pairingState, .connecting,
                       "Should retry connection, not fail, when BLE drops during UWB setup")
        XCTAssertTrue(mockCentral.connectPeripheralCalled,
                      "Should attempt to reconnect via peripheral identifier")
    }

    func testDisconnectDuringUWBSetupFailsAfterMaxRetries() {
        let stella = makeStella()
        pairingManager.pair(stella: stella)

        // maxUWBRetries is 3, so we get 3 retries (disconnect 1, 2, 3 → retry each time)
        // On the 4th disconnect, uwbRetryCount == 3 which is not < 3, so it fails
        for i in 1...4 {
            pairingManager.handleDidConnect()
            XCTAssertEqual(pairingManager.pairingState, .configuringUWB)
            pairingManager.handleDidDisconnect(error: NSError(domain: "CBError", code: 6))
            if i <= 3 {
                XCTAssertEqual(pairingManager.pairingState, .connecting, "Disconnect \(i) should retry")
            }
        }

        if case .failed = pairingManager.pairingState {
            // expected after exhausting retries
        } else {
            XCTFail("Expected failed state after max retries, got \(pairingManager.pairingState)")
        }
    }

    func testHandleDidConnectCreatesProviderWithPeripheralIdentifier() {
        let peripheralID = UUID()
        let stella = DiscoveredStella(
            id: peripheralID,
            name: "Stella-Real",
            rssi: -50,
            peripheralIdentifier: peripheralID,
            peripheral: nil
        )
        pairingManager.pair(stella: stella)

        let mockPeriph = MockPeripheral(identifier: peripheralID, name: "Stella-Real")
        pairingManager.handleDidConnect(peripheral: mockPeriph)

        XCTAssertEqual(pairingManager.pairingState, .configuringUWB)
        XCTAssertNotNil(pairingManager.pairedProvider)
        XCTAssertEqual(pairingManager.pairedProvider?.peripheralIdentifier, peripheralID)
        XCTAssertTrue(mockPeriph.discoverServicesCalled)
    }

    // MARK: - Helpers

    private func makeStella() -> DiscoveredStella {
        DiscoveredStella(
            id: UUID(),
            name: "TestStella",
            rssi: -55,
            peripheralIdentifier: UUID(),
            peripheral: nil
        )
    }
}
