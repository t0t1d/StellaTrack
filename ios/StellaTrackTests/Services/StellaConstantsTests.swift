import XCTest
import CoreBluetooth
@testable import StellaTrack

final class StellaConstantsTests: XCTestCase {

    func testNIServiceUUID() {
        let expected = CBUUID(string: "48FE3E40-0817-4BB2-8633-3073689C2DBA")
        XCTAssertEqual(StellaConstants.niServiceUUID, expected)
    }

    func testCustomServiceUUID() {
        let expected = CBUUID(string: "A0E9F8B0-1234-5678-ABCD-0123456789AB")
        XCTAssertEqual(StellaConstants.customServiceUUID, expected)
    }

    func testNUSServiceUUID() {
        let expected = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
        XCTAssertEqual(StellaConstants.nusServiceUUID, expected)
    }

    func testNICharacteristicUUIDs() {
        XCTAssertEqual(
            StellaConstants.niAccessoryConfigUUID,
            CBUUID(string: "95E8D9D5-D8EF-4721-9A4E-807375F53328")
        )
        XCTAssertEqual(
            StellaConstants.rxCharUUID,
            CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
        )
        XCTAssertEqual(
            StellaConstants.txCharUUID,
            CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
        )
    }

    func testCustomCharacteristicUUIDs() {
        XCTAssertEqual(
            StellaConstants.batteryLevelUUID,
            CBUUID(string: "A0E9F8B3-1234-5678-ABCD-0123456789AB")
        )
        XCTAssertEqual(
            StellaConstants.commandUUID,
            CBUUID(string: "A0E9F8B4-1234-5678-ABCD-0123456789AB")
        )
        XCTAssertEqual(
            StellaConstants.deviceInfoUUID,
            CBUUID(string: "A0E9F8B5-1234-5678-ABCD-0123456789AB")
        )
    }

    func testNICommandRawValues() {
        XCTAssertEqual(StellaConstants.NICommand.initializeIOS.rawValue, 0x0A)
        XCTAssertEqual(StellaConstants.NICommand.configureAndStart.rawValue, 0x0B)
        XCTAssertEqual(StellaConstants.NICommand.stop.rawValue, 0x0C)
    }

    func testNIResponseRawValues() {
        XCTAssertEqual(StellaConstants.NIResponse.initializedData.rawValue, 0x01)
        XCTAssertEqual(StellaConstants.NIResponse.uwbDidStart.rawValue, 0x02)
        XCTAssertEqual(StellaConstants.NIResponse.uwbDidStop.rawValue, 0x03)
    }

    func testScanServiceUUIDsContainsAdvertisedService() {
        XCTAssertTrue(StellaConstants.scanServiceUUIDs.contains(StellaConstants.nusServiceUUID))
        XCTAssertTrue(StellaConstants.scanServiceUUIDs.contains(StellaConstants.customServiceUUID))
    }

    func testAllServiceUUIDsContainsAllThreeServices() {
        XCTAssertTrue(StellaConstants.allServiceUUIDs.contains(StellaConstants.niServiceUUID))
        XCTAssertTrue(StellaConstants.allServiceUUIDs.contains(StellaConstants.nusServiceUUID))
        XCTAssertTrue(StellaConstants.allServiceUUIDs.contains(StellaConstants.customServiceUUID))
    }

    func testAllUUIDsUnique() {
        let uuids = [
            StellaConstants.niServiceUUID,
            StellaConstants.nusServiceUUID,
            StellaConstants.niAccessoryConfigUUID,
            StellaConstants.rxCharUUID,
            StellaConstants.txCharUUID,
            StellaConstants.customServiceUUID,
            StellaConstants.batteryLevelUUID,
            StellaConstants.commandUUID,
            StellaConstants.deviceInfoUUID,
        ]
        XCTAssertEqual(Set(uuids).count, uuids.count, "All UUIDs must be unique")
    }

    func testDeviceCommandRawValues() {
        XCTAssertEqual(StellaConstants.DeviceCommand.playSound.rawValue, 0x01)
        XCTAssertEqual(StellaConstants.DeviceCommand.stopSound.rawValue, 0x02)
        XCTAssertEqual(StellaConstants.DeviceCommand.ledOn.rawValue, 0x03)
        XCTAssertEqual(StellaConstants.DeviceCommand.ledOff.rawValue, 0x04)
        XCTAssertEqual(StellaConstants.DeviceCommand.ping.rawValue, 0x06)
    }

    func testDeviceCommandDataPlaySound() {
        let data = StellaConstants.DeviceCommand.playSound.data(parameter: 5)
        XCTAssertEqual(data.count, 2)
        XCTAssertEqual([UInt8](data), [0x01, 5])
    }

    func testDeviceCommandDataStopSound() {
        let data = StellaConstants.DeviceCommand.stopSound.data()
        XCTAssertEqual(data.count, 2)
        XCTAssertEqual([UInt8](data), [0x02, 0])
    }

    func testDeviceCommandDataDefaultParameterIsZero() {
        let data = StellaConstants.DeviceCommand.ledOn.data()
        XCTAssertEqual([UInt8](data), [0x03, 0])
    }

    func testDeviceCommandPingData() {
        let data = StellaConstants.DeviceCommand.ping.data()
        XCTAssertEqual([UInt8](data), [0x06, 0])
    }
}
