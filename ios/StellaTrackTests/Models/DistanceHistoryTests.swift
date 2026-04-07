import XCTest
@testable import StellaTrack

@MainActor
final class DistanceHistoryTests: XCTestCase {

    func testEmptyHistoryReturnsNoReadings() {
        let history = DistanceHistory()
        let readings = history.readings(for: .thirtyMinutes)
        XCTAssertTrue(readings.isEmpty)
    }

    func testAddReadingStoresIt() {
        let history = DistanceHistory()
        history.add(distance: 5.0, direction: nil, at: Date())
        XCTAssertEqual(history.readings(for: .twentyFourHours).count, 1)
    }

    func testReadingsFilteredByTimeWindow() {
        let history = DistanceHistory()
        let now = Date()
        history.add(distance: 5.0, direction: nil, at: now.addingTimeInterval(-3600))
        history.add(distance: 10.0, direction: nil, at: now.addingTimeInterval(-60))

        let thirtyMin = history.readings(for: .thirtyMinutes, relativeTo: now)
        XCTAssertEqual(thirtyMin.count, 1)
        XCTAssertEqual(thirtyMin.first?.distance, 10.0)

        let twoHours = history.readings(for: .twoHours, relativeTo: now)
        XCTAssertEqual(twoHours.count, 2)
    }

    func testOldReadingsPruned() {
        let history = DistanceHistory()
        let now = Date()
        history.add(distance: 1.0, direction: nil, at: now.addingTimeInterval(-90000))
        history.add(distance: 2.0, direction: nil, at: now.addingTimeInterval(-60))
        history.pruneOlderThan(hours: 24, relativeTo: now)
        XCTAssertEqual(history.readings(for: .twentyFourHours, relativeTo: now).count, 1)
    }

    func testDownsampleReducesPoints() {
        let history = DistanceHistory()
        let now = Date()
        for i in 0..<1000 {
            history.add(distance: Double(i), direction: nil, at: now.addingTimeInterval(Double(-1000 + i)))
        }
        let downsampled = history.downsampledReadings(for: .thirtyMinutes, maxPoints: 100, relativeTo: now)
        XCTAssertLessThanOrEqual(downsampled.count, 100)
        XCTAssertGreaterThan(downsampled.count, 0)
    }
}
