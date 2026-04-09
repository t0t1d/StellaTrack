import XCTest
import simd
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

    // MARK: - Persistence

    private let testDeviceID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    override func tearDown() {
        DistanceHistory.deleteFile(for: testDeviceID)
        super.tearDown()
    }

    func testSaveAndLoadRoundTrip() {
        let history = DistanceHistory()
        let now = Date()
        history.add(distance: 3.5, direction: nil, at: now.addingTimeInterval(-60))
        history.add(distance: 7.2, direction: simd_float3(1, 0, 0), at: now.addingTimeInterval(-30))
        history.save(for: testDeviceID)

        let restored = DistanceHistory()
        restored.loadFromDisk(for: testDeviceID)
        let points = restored.readings(for: .thirtyMinutes, relativeTo: now)

        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].distance, 3.5, accuracy: 0.001)
        XCTAssertEqual(points[1].distance, 7.2, accuracy: 0.001)
        XCTAssertNil(points[0].direction)
        XCTAssertNotNil(points[1].direction)
        XCTAssertEqual(points[1].direction?.x ?? 0, 1.0, accuracy: 0.001)
    }

    func testLoadFiltersExpiredPoints() {
        let history = DistanceHistory()
        let now = Date()
        history.add(distance: 1.0, direction: nil, at: now.addingTimeInterval(-100))
        history.save(for: testDeviceID)

        let restored = DistanceHistory()
        restored.loadFromDisk(for: testDeviceID)
        let points = restored.readings(for: .twentyFourHours, relativeTo: now)
        XCTAssertEqual(points.count, 1, "Recent point should survive reload")
    }

    func testLoadIgnoresCorruptedData() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DistanceHistory", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(testDeviceID.uuidString).bin")
        try? Data([0xFF, 0xFE, 0xFD]).write(to: file)

        let history = DistanceHistory()
        history.loadFromDisk(for: testDeviceID)
        XCTAssertTrue(history.readings(for: .twentyFourHours).isEmpty, "Corrupted file should result in empty history")
    }

    func testDeleteFileRemovesData() {
        let history = DistanceHistory()
        history.add(distance: 5.0, direction: nil, at: Date())
        history.save(for: testDeviceID)

        DistanceHistory.deleteFile(for: testDeviceID)

        let restored = DistanceHistory()
        restored.loadFromDisk(for: testDeviceID)
        XCTAssertTrue(restored.readings(for: .twentyFourHours).isEmpty)
    }

    func testLoadFromNonexistentFileIsNoOp() {
        let history = DistanceHistory()
        history.loadFromDisk(for: UUID())
        XCTAssertTrue(history.readings(for: .twentyFourHours).isEmpty)
    }
}
