import Foundation
import CoreBluetooth

enum StellaConstants {
    // NUS Config Service (REQUIRED — all NI protocol exchange happens here)
    static let nusServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let rxCharUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    static let txCharUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    // NI Accessory Service (OPTIONAL — supplementary, NOT required for handshake)
    static let niServiceUUID = CBUUID(string: "48FE3E40-0817-4BB2-8633-3073689C2DBA")
    static let niAccessoryConfigUUID = CBUUID(string: "95E8D9D5-D8EF-4721-9A4E-807375F53328")

    // Custom Stella service (battery, commands, device info)
    static let customServiceUUID = CBUUID(string: "A0E9F8B0-1234-5678-ABCD-0123456789AB")
    static let batteryLevelUUID = CBUUID(string: "A0E9F8B3-1234-5678-ABCD-0123456789AB")
    static let commandUUID = CBUUID(string: "A0E9F8B4-1234-5678-ABCD-0123456789AB")
    static let deviceInfoUUID = CBUUID(string: "A0E9F8B5-1234-5678-ABCD-0123456789AB")

    // Firmware advertises nusServiceUUID (Nordic UART) in BLE advertisement
    static let scanServiceUUIDs: [CBUUID] = [nusServiceUUID, customServiceUUID]
    // Discover all services after connecting (only NUS is required; others are optional)
    static let allServiceUUIDs: [CBUUID] = [nusServiceUUID, niServiceUUID, customServiceUUID]

    // NI protocol message IDs (iOS -> Stella, written to RX characteristic)
    enum NICommand: UInt8 {
        case initializeIOS = 0x0A
        case configureAndStart = 0x0B
        case stop = 0x0C
    }

    // NI protocol response IDs (Stella -> iOS, notified on TX characteristic)
    enum NIResponse: UInt8 {
        case initializedData = 0x01
        case uwbDidStart = 0x02
        case uwbDidStop = 0x03
    }

    // Device command bytes (iOS -> Stella custom service Command characteristic)
    enum DeviceCommand: UInt8 {
        case playSound = 0x01
        case stopSound = 0x02
        case ledOn     = 0x03
        case ledOff    = 0x04
        case ping      = 0x06

        func data(parameter: UInt8 = 0) -> Data {
            Data([rawValue, parameter])
        }
    }
}
