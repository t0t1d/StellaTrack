import XCTest
import Combine
import CoreBluetooth
import simd
@testable import StellaTrack

@MainActor
final class StellaDistanceProviderTests: XCTestCase {
    var provider: StellaDistanceProvider!
    var mockPeripheral: MockPeripheral!
    var mockCentral: MockCentralManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        mockPeripheral = MockPeripheral(identifier: UUID(), name: "TestStella")
        mockCentral = MockCentralManager()
        mockCentral.fakeState = .poweredOn
        provider = StellaDistanceProvider(
            peripheral: mockPeripheral,
            centralManager: mockCentral
        )
        cancellables = []
    }

    // MARK: - Initial State

    func testInitialStatusIsDisconnected() {
        XCTAssertEqual(provider.currentConnectionStatus, .disconnected)
    }

    func testPeripheralIdentifierExposed() {
        XCTAssertEqual(provider.peripheralIdentifier, mockPeripheral.identifier)
    }

    // MARK: - Start / Stop

    func testStartConnectsPeripheral() {
        provider.start()

        XCTAssertTrue(mockCentral.connectCalled)
        XCTAssertEqual(provider.currentConnectionStatus, .searching)
    }

    func testStartIsIdempotent() {
        provider.start()
        mockCentral.connectCalled = false

        provider.start()

        XCTAssertFalse(mockCentral.connectCalled, "Second start() should not connect again")
    }

    func testStopDisconnectsPeripheral() {
        provider.start()
        provider.stop()

        XCTAssertTrue(mockCentral.cancelConnectionCalled)
        XCTAssertEqual(provider.currentConnectionStatus, .disconnected)
    }

    // MARK: - Connection State Machine

    func testDidConnectTransitionsToConnected() {
        provider.start()
        provider.handleDidConnect()

        XCTAssertEqual(provider.currentConnectionStatus, .connected)
        XCTAssertTrue(mockPeripheral.discoverServicesCalled)
        XCTAssertEqual(mockPeripheral.lastDiscoveredServiceUUIDs, StellaConstants.allServiceUUIDs)
    }

    func testDidConnectSetsPeripheralDelegate() {
        provider.start()
        provider.handleDidConnect()

        XCTAssertTrue(mockPeripheral.setDelegateCalled, "handleDidConnect must set peripheral delegate for GATT callbacks")
    }

    func testDidConnectResetsTxSubscriptionFlag() {
        provider.start()
        provider.handleDidConnect()

        provider.handleNICharacteristicsDiscovered(
            rxCharID: StellaConstants.rxCharUUID,
            txCharID: StellaConstants.txCharUUID
        )
        provider.handleTxSubscriptionConfirmed()

        // Simulate reconnect
        provider.handleDidConnect()
        provider.handleNICharacteristicsDiscovered(
            rxCharID: StellaConstants.rxCharUUID,
            txCharID: StellaConstants.txCharUUID
        )
        provider.handleAllServicesReady()
        XCTAssertNil(mockPeripheral.lastWrittenData, "0x0A should not be sent — TX subscription not confirmed after reconnect")
    }

    func testDidFailToConnectTransitionsToDisconnected() {
        provider.start()
        provider.handleDidFailToConnect(error: NSError(domain: "test", code: -1))

        XCTAssertEqual(provider.currentConnectionStatus, .disconnected)
    }

    func testDidDisconnectTransitionsToSearchingForReconnect() {
        provider.start()
        provider.handleDidConnect()
        provider.handleDidDisconnect(error: nil)

        XCTAssertEqual(provider.currentConnectionStatus, .searching)
    }

    func testDidDisconnectAfterStopDoesNotReconnect() {
        provider.start()
        provider.handleDidConnect()
        provider.stop()
        mockCentral.connectCalled = false

        provider.handleDidDisconnect(error: nil)

        XCTAssertFalse(mockCentral.connectCalled)
        XCTAssertEqual(provider.currentConnectionStatus, .disconnected)
    }

    // MARK: - Play/Stop Sound

    func testPlaySoundWritesCommand() {
        provider.start()
        provider.handleDidConnect()
        simulateCharacteristicDiscovery()

        provider.playSound()

        let written = mockPeripheral.lastWrittenData
        XCTAssertNotNil(written)
        XCTAssertEqual([UInt8](written!), [0x01, 3])
    }

    func testStopSoundWritesCommand() {
        provider.start()
        provider.handleDidConnect()
        simulateCharacteristicDiscovery()

        provider.stopSound()

        let written = mockPeripheral.lastWrittenData
        XCTAssertNotNil(written)
        XCTAssertEqual([UInt8](written!), [0x02, 0])
    }

    // MARK: - Battery

    func testBatteryUpdatePublishes() {
        provider.start()
        provider.handleDidConnect()
        simulateCharacteristicDiscovery()

        let expectation = expectation(description: "battery published")
        var receivedBattery: Double?

        provider.batteryLevelPublisher
            .dropFirst()
            .sink { level in
                receivedBattery = level
                expectation.fulfill()
            }
            .store(in: &cancellables)

        provider.handleBatteryUpdate(level: 85)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedBattery, 85)
    }

    // MARK: - Distance Reading

    func testDistanceReadingPublishes() {
        let expectation = expectation(description: "distance published")
        var receivedReading: DistanceReading?

        provider.distancePublisher
            .sink { reading in
                receivedReading = reading
                expectation.fulfill()
            }
            .store(in: &cancellables)

        let dir = simd_float3(0, 0, 1)
        provider.handleRangingUpdate(distance: 2.5, direction: dir)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedReading)
        XCTAssertEqual(receivedReading?.distance, 2.5)
        XCTAssertEqual(receivedReading?.direction, dir)
        XCTAssertTrue(receivedReading?.isValid ?? false)
    }

    func testRangingUpdateSetsStatusToRanging() {
        provider.start()
        provider.handleDidConnect()
        provider.handleRangingUpdate(distance: 1.0, direction: nil)

        XCTAssertEqual(provider.currentConnectionStatus, .ranging)
    }

    // MARK: - BLE-Only Mode (no NUS chars)

    func testBLEOnlyModeWhenNUSCharsMissing() {
        provider.start()
        provider.handleDidConnect()

        provider.handleCustomCharacteristicsDiscovered(
            commandCharID: StellaConstants.commandUUID,
            batteryCharID: StellaConstants.batteryLevelUUID
        )
        provider.handleAllServicesReady()

        XCTAssertEqual(provider.currentConnectionStatus, .ranging, "Should fall back to BLE-only when NUS chars not found")
        XCTAssertNil(mockPeripheral.lastWrittenData)
    }

    // MARK: - NI Protocol

    func testNICharDiscoverySubscribesToTXButDoesNotSendInit() {
        provider.start()
        provider.handleDidConnect()

        provider.handleNICharacteristicsDiscovered(
            rxCharID: StellaConstants.rxCharUUID,
            txCharID: StellaConstants.txCharUUID
        )

        XCTAssertTrue(mockPeripheral.notifyEnabledCharIDs.contains(StellaConstants.txCharUUID))
        XCTAssertNil(mockPeripheral.lastWrittenData, "Init command should not be sent until all services are ready and TX subscribed")
    }

    func testAllServicesReadyDoesNotSendInitWithoutTxSubscription() {
        provider.start()
        provider.handleDidConnect()

        provider.handleNICharacteristicsDiscovered(
            rxCharID: StellaConstants.rxCharUUID,
            txCharID: StellaConstants.txCharUUID
        )
        provider.handleAllServicesReady()

        XCTAssertNil(mockPeripheral.lastWrittenData, "0x0A should NOT be sent until TX subscription is confirmed")
    }

    func testSendsInitWhenNUSFoundAndTxConfirmed() {
        provider.start()
        provider.handleDidConnect()

        provider.handleNICharacteristicsDiscovered(
            rxCharID: StellaConstants.rxCharUUID,
            txCharID: StellaConstants.txCharUUID
        )
        provider.handleTxSubscriptionConfirmed()
        provider.handleAllServicesReady()

        XCTAssertEqual(mockPeripheral.lastWrittenCharacteristicID, StellaConstants.rxCharUUID)
        XCTAssertEqual([UInt8](mockPeripheral.lastWrittenData!), [StellaConstants.NICommand.initializeIOS.rawValue])
    }

    func testSendsInitWithOnlyNUSServiceDiscovered() {
        provider.start()
        provider.handleDidConnect()

        provider.handleNICharacteristicsDiscovered(
            rxCharID: StellaConstants.rxCharUUID,
            txCharID: StellaConstants.txCharUUID
        )
        provider.handleTxSubscriptionConfirmed()
        provider.handleAllServicesReady()

        XCTAssertEqual([UInt8](mockPeripheral.lastWrittenData!), [StellaConstants.NICommand.initializeIOS.rawValue],
                        "NI handshake should start with only NUS service — NI accessory service is NOT required")
    }

    func testTxSubscriptionAfterAllServicesReadySendsInit() {
        provider.start()
        provider.handleDidConnect()

        provider.handleNICharacteristicsDiscovered(
            rxCharID: StellaConstants.rxCharUUID,
            txCharID: StellaConstants.txCharUUID
        )
        provider.handleAllServicesReady()
        XCTAssertNil(mockPeripheral.lastWrittenData, "Should wait for TX subscription")

        provider.handleTxSubscriptionConfirmed()

        XCTAssertEqual(mockPeripheral.lastWrittenCharacteristicID, StellaConstants.rxCharUUID)
        XCTAssertEqual([UInt8](mockPeripheral.lastWrittenData!), [StellaConstants.NICommand.initializeIOS.rawValue])
    }

    // MARK: - TX Subscription Failure

    func testTxSubscriptionFailureFallsToBLEOnly() {
        provider.start()
        provider.handleDidConnect()

        provider.handleNICharacteristicsDiscovered(
            rxCharID: StellaConstants.rxCharUUID,
            txCharID: StellaConstants.txCharUUID
        )

        provider.handleTxSubscriptionFailed(error: NSError(domain: "CBATTError", code: 14))

        XCTAssertNil(mockPeripheral.lastWrittenData, "Should not send 0x0A after TX failure")
        XCTAssertEqual(provider.currentConnectionStatus, .ranging, "Should fall back to BLE-only on TX failure")
    }

    // MARK: - UWB Start/Stop Signals

    func testUWBDidStartTransitionsToRanging() {
        provider.start()
        provider.handleDidConnect()
        XCTAssertEqual(provider.currentConnectionStatus, .connected)

        provider.handleUWBDidStart()

        XCTAssertEqual(provider.currentConnectionStatus, .ranging,
                       "0x02 (uwbDidStart) from firmware should transition to .ranging")
    }

    func testUWBDidStopDoesNotTransitionToDisconnected() {
        provider.start()
        provider.handleDidConnect()
        provider.handleUWBDidStart()
        XCTAssertEqual(provider.currentConnectionStatus, .ranging)

        provider.handleUWBDidStop()

        XCTAssertNotEqual(provider.currentConnectionStatus, .disconnected,
                          "UWB stop should not disconnect — BLE is still active")
    }

    func testRangingUpdateFromNISessionTransitionsToRanging() {
        provider.start()
        provider.handleDidConnect()
        XCTAssertEqual(provider.currentConnectionStatus, .connected)

        provider.handleRangingUpdate(distance: 0.75, direction: simd_float3(0, 0, 1))

        XCTAssertEqual(provider.currentConnectionStatus, .ranging,
                       "First NINearbyObject with valid distance should transition to .ranging")
    }

    // MARK: - NISession Invalidation

    func testSendFreshInitCommandWritesInitializeIOS() {
        provider.start()
        provider.handleDidConnect()

        provider.handleNICharacteristicsDiscovered(
            rxCharID: StellaConstants.rxCharUUID,
            txCharID: StellaConstants.txCharUUID
        )
        provider.handleTxSubscriptionConfirmed()
        provider.handleAllServicesReady()

        mockPeripheral.lastWrittenData = nil
        mockPeripheral.lastWrittenCharacteristicID = nil

        provider.sendFreshInitCommand()

        XCTAssertEqual(mockPeripheral.lastWrittenCharacteristicID, StellaConstants.rxCharUUID)
        XCTAssertEqual([UInt8](mockPeripheral.lastWrittenData!), [StellaConstants.NICommand.initializeIOS.rawValue])
    }

    func testSendFreshInitCommandNoOpWhenRxCharMissing() {
        provider.start()
        provider.handleDidConnect()

        provider.sendFreshInitCommand()

        XCTAssertNil(mockPeripheral.lastWrittenData, "Should not send init when RX char is nil")
    }

    // MARK: - Connection Status Publisher

    func testConnectionStatusPublisherEmits() {
        let expectation = expectation(description: "status emitted")
        var statuses: [ConnectionStatus] = []

        provider.connectionStatusPublisher
            .sink { status in
                statuses.append(status)
                if statuses.count == 3 { expectation.fulfill() }
            }
            .store(in: &cancellables)

        provider.start()
        provider.handleDidConnect()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(statuses, [.disconnected, .searching, .connected])
    }

    // MARK: - Helpers

    private func simulateCharacteristicDiscovery() {
        provider.handleCustomCharacteristicsDiscovered(
            commandCharID: StellaConstants.commandUUID,
            batteryCharID: StellaConstants.batteryLevelUUID
        )
        provider.handleNICharacteristicsDiscovered(
            rxCharID: StellaConstants.rxCharUUID,
            txCharID: StellaConstants.txCharUUID
        )
    }
}

// MARK: - Mock Peripheral

@MainActor
final class MockPeripheral: PeripheralManaging {
    let identifier: UUID
    let name: String?

    private(set) var setDelegateCalled = false
    private(set) var discoverServicesCalled = false
    private(set) var lastDiscoveredServiceUUIDs: [CBUUID]?
    var lastWrittenData: Data?
    var lastWrittenCharacteristicID: CBUUID?
    private(set) var notifyEnabledCharIDs: Set<CBUUID> = []

    init(identifier: UUID, name: String?) {
        self.identifier = identifier
        self.name = name
    }

    func setPeripheralDelegate(_ delegate: CBPeripheralDelegate) {
        setDelegateCalled = true
    }

    func discoverServices(_ serviceUUIDs: [CBUUID]?) {
        discoverServicesCalled = true
        lastDiscoveredServiceUUIDs = serviceUUIDs
    }

    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for serviceID: CBUUID) {}

    func setNotifyValue(_ enabled: Bool, for characteristicID: CBUUID) {
        if enabled {
            notifyEnabledCharIDs.insert(characteristicID)
        } else {
            notifyEnabledCharIDs.remove(characteristicID)
        }
    }

    func readValue(for characteristicID: CBUUID) {}

    func writeValue(_ data: Data, for characteristicID: CBUUID, type: CBCharacteristicWriteType) {
        lastWrittenData = data
        lastWrittenCharacteristicID = characteristicID
    }
}
