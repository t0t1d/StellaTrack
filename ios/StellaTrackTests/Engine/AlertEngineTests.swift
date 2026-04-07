import XCTest
import Combine
@testable import StellaTrack

@MainActor
final class AlertEngineTests: XCTestCase {
    var engine: AlertEngine!
    var mockProvider: MockDistanceProvider!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        mockProvider = MockDistanceProvider()
        engine = AlertEngine(
            provider: mockProvider,
            settings: AlertSettings(thresholdDistance: 10.0, persistenceDuration: 2.0, alertEnabled: true, alertDuration: .infinity)
        )
        cancellables = []
        mockProvider.start()
    }

    func testInitialStateIsSafe() {
        XCTAssertEqual(engine.currentLevel, .safe)
    }

    func testDistanceBelowThresholdStaysSafe() {
        mockProvider.setDistance(5.0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(engine.currentLevel, .safe)
    }

    func testDistanceAboveThresholdBecomesWarning() {
        mockProvider.setDistance(15.0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(engine.currentLevel, .warning)
    }

    func testSustainedDistanceBecomesAlert() {
        let expectation = expectation(description: "becomes alert")
        engine.alertLevelPublisher
            .first(where: { $0 == .alert })
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        mockProvider.setDistance(15.0)
        wait(for: [expectation], timeout: 4.0)
    }

    func testReturnBelowThresholdResetsToSafe() {
        mockProvider.setDistance(15.0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(engine.currentLevel, .warning)

        mockProvider.setDistance(5.0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(engine.currentLevel, .safe)
    }

    func testBriefCrossingDoesNotTriggerAlert() {
        mockProvider.setDistance(15.0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        mockProvider.setDistance(5.0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(engine.currentLevel, .safe)
    }

    func testAlertResetsToSafeWhenDistanceDrops() {
        let alertExpectation = expectation(description: "becomes alert")
        engine.alertLevelPublisher
            .first(where: { $0 == .alert })
            .sink { _ in alertExpectation.fulfill() }
            .store(in: &cancellables)

        mockProvider.setDistance(15.0)
        wait(for: [alertExpectation], timeout: 4.0)

        mockProvider.setDistance(5.0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(engine.currentLevel, .safe)
    }

    func testLatestDistanceUpdatesOnReading() {
        mockProvider.setDistance(7.5)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(engine.latestDistance, 7.5)
    }

    func testAlertHistoryRecordsTransitions() {
        mockProvider.setDistance(15.0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(engine.alertHistory.count, 1)
        XCTAssertEqual(engine.alertHistory.first?.level, .warning)

        mockProvider.setDistance(5.0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(engine.alertHistory.count, 2)
        XCTAssertEqual(engine.alertHistory.last?.level, .safe)
    }

    func testUpdateSettingsChangesThreshold() {
        engine.updateSettings(AlertSettings(thresholdDistance: 20.0, persistenceDuration: 2.0, alertEnabled: true, alertDuration: .infinity))
        mockProvider.setDistance(15.0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(engine.currentLevel, .safe)
    }

    func testInvalidReadingIsIgnored() {
        mockProvider.simulateDisconnect()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(engine.currentLevel, .safe)
        XCTAssertEqual(engine.latestDistance, 0.0)
    }
}
