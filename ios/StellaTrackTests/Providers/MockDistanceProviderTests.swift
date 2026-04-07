import XCTest
import Combine
@testable import StellaTrack

final class MockDistanceProviderTests: XCTestCase {
    var provider: MockDistanceProvider!
    var cancellables: Set<AnyCancellable>!

    @MainActor
    override func setUp() {
        provider = MockDistanceProvider()
        cancellables = []
    }

    @MainActor
    func testInitialConnectionStatus() {
        XCTAssertEqual(provider.currentConnectionStatus, .disconnected)
    }

    @MainActor
    func testStartChangesStatusToRanging() {
        let expectation = expectation(description: "status becomes ranging")
        provider.connectionStatusPublisher
            .dropFirst()
            .first(where: { $0 == .ranging })
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        provider.start()
        wait(for: [expectation], timeout: 2.0)
    }

    @MainActor
    func testStopResetsToDisconnected() {
        provider.start()
        provider.stop()
        XCTAssertEqual(provider.currentConnectionStatus, .disconnected)
    }

    @MainActor
    func testSetDistanceEmitsReading() {
        let expectation = expectation(description: "distance emitted")
        provider.start()
        provider.distancePublisher
            .first(where: { $0.distance == 5.0 })
            .sink { reading in
                XCTAssertEqual(reading.distance, 5.0)
                XCTAssertTrue(reading.isValid)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        provider.setDistance(5.0)
        wait(for: [expectation], timeout: 2.0)
    }

    @MainActor
    func testSimulateDisconnectSendsInvalidReading() {
        let expectation = expectation(description: "invalid reading emitted")
        provider.start()
        provider.distancePublisher
            .first(where: { !$0.isValid })
            .sink { reading in
                XCTAssertFalse(reading.isValid)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        provider.simulateDisconnect()
        wait(for: [expectation], timeout: 2.0)
    }

    @MainActor
    func testSimulateDisconnectChangesStatusToDisconnected() {
        provider.start()

        let expectation = expectation(description: "status becomes disconnected")
        provider.connectionStatusPublisher
            .first(where: { $0 == .disconnected })
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        provider.simulateDisconnect()
        wait(for: [expectation], timeout: 2.0)
    }

    @MainActor
    func testInitialBatteryLevelIsNil() {
        var received: Double?
        provider.batteryLevelPublisher
            .first()
            .sink { received = $0 }
            .store(in: &cancellables)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertNil(received)
    }

    @MainActor
    func testSetBatteryLevelEmitsValue() {
        let expectation = expectation(description: "battery emitted")
        provider.batteryLevelPublisher
            .compactMap { $0 }
            .first()
            .sink { level in
                XCTAssertEqual(level, 75.0)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        provider.setBatteryLevel(75.0)
        wait(for: [expectation], timeout: 2.0)
    }

    @MainActor
    func testPlaySoundRecordsCall() {
        provider.playSound()
        XCTAssertEqual(provider.playSoundCallCount, 1)
    }
}
