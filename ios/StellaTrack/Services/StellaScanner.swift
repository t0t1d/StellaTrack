import Foundation
import Combine
import CoreBluetooth
private var scanLog: BLEDebugLog { BLEDebugLog.shared }

enum ScanningState: Equatable {
    case idle
    case scanning
    case stopped
    case waitingForBluetooth
}

@MainActor
protocol CentralManaging: AnyObject {
    var state: CBManagerState { get }
    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?)
    func stopScan()
    func connect(_ peripheral: CBPeripheral, options: [String: Any]?)
    func cancelPeripheralConnection(_ peripheral: CBPeripheral)
    func connectPeripheral(identifier: UUID, options: [String: Any]?)
    func cancelPeripheralConnection(identifier: UUID)
}

extension CBCentralManager: CentralManaging {
    func connectPeripheral(identifier: UUID, options: [String: Any]?) {
        let peripherals = retrievePeripherals(withIdentifiers: [identifier])
        guard let peripheral = peripherals.first else { return }
        connect(peripheral, options: options)
    }

    func cancelPeripheralConnection(identifier: UUID) {
        let peripherals = retrievePeripherals(withIdentifiers: [identifier])
        guard let peripheral = peripherals.first else { return }
        cancelPeripheralConnection(peripheral)
    }
}

@MainActor
protocol BLEConnectionDelegate: AnyObject {
    func handleDidConnect()
    func handleDidConnect(peripheral: PeripheralManaging)
    func handleDidFailToConnect(error: Error?)
    func handleDidDisconnect(error: Error?)
}

extension BLEConnectionDelegate {
    func handleDidConnect() {}
}

@MainActor
class StellaScanner: NSObject, ObservableObject {
    @Published private(set) var discoveredDevices: [DiscoveredStella] = []
    @Published private(set) var scanningState: ScanningState = .idle

    private(set) var central: CentralManaging
    weak var connectionDelegate: BLEConnectionDelegate?
    private var wantsScan = false

    convenience override init() {
        self.init(centralManager: nil)
    }

    init(centralManager: CentralManaging?) {
        if let centralManager {
            self.central = centralManager
        } else {
            let cbCentral = CBCentralManager()
            self.central = cbCentral
            super.init()
            cbCentral.delegate = self
            return
        }
        super.init()
    }

    func startScan() {
        if scanningState == .scanning {
            central.stopScan()
        }
        discoveredDevices = []
        wantsScan = true

        if central.state == .poweredOn {
            beginScanning()
        } else {
            scanningState = .waitingForBluetooth
        }
    }

    func stopScan() {
        wantsScan = false
        central.stopScan()
        scanningState = .stopped
    }

    func handleBluetoothStateUpdate() {
        if central.state == .poweredOn && wantsScan && scanningState != .scanning {
            beginScanning()
        }
    }

    func handleDiscoveredPeripheral(
        identifier: UUID,
        name: String?,
        rssi: Int,
        peripheral: CBPeripheral?
    ) {
        let deviceName = name ?? "Unknown Stella"

        if let index = discoveredDevices.firstIndex(where: { $0.peripheralIdentifier == identifier }) {
            discoveredDevices[index].rssi = rssi
        } else {
            let stella = DiscoveredStella(
                id: identifier,
                name: deviceName,
                rssi: rssi,
                peripheralIdentifier: identifier,
                peripheral: peripheral
            )
            discoveredDevices.append(stella)
        }
    }

    // MARK: - Connection Event Forwarding

    func handlePeripheralConnected(identifier: UUID) {
        connectionDelegate?.handleDidConnect()
    }

    func handlePeripheralConnected(identifier: UUID, peripheral: PeripheralManaging) {
        connectionDelegate?.handleDidConnect(peripheral: peripheral)
    }

    func handlePeripheralConnectionFailed(identifier: UUID, error: Error?) {
        connectionDelegate?.handleDidFailToConnect(error: error)
    }

    func handlePeripheralDisconnected(identifier: UUID, error: Error?) {
        connectionDelegate?.handleDidDisconnect(error: error)
    }

    private func beginScanning() {
        scanningState = .scanning
        central.scanForPeripherals(
            withServices: StellaConstants.scanServiceUUIDs,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }
}

// MARK: - CBCentralManagerDelegate

extension StellaScanner: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            handleBluetoothStateUpdate()
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            handleDiscoveredPeripheral(
                identifier: peripheral.identifier,
                name: peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String),
                rssi: RSSI.intValue,
                peripheral: peripheral
            )
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let id = peripheral.identifier.uuidString
        let name = peripheral.name ?? "nil"
        let delegateDesc = String(describing: peripheral.delegate)
        Task { @MainActor in
            scanLog.log("CB didConnect — \(id), name=\(name), delegate=\(delegateDesc)", level: .success)
            let wrapper = CBPeripheralWrapper(peripheral)
            handlePeripheralConnected(identifier: peripheral.identifier, peripheral: wrapper)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let id = peripheral.identifier.uuidString
        let errDesc = error?.localizedDescription ?? "nil"
        Task { @MainActor in
            scanLog.log("CB didFailToConnect — \(id), error=\(errDesc)", level: .error)
            handlePeripheralConnectionFailed(identifier: peripheral.identifier, error: error)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let id = peripheral.identifier.uuidString
        let errDesc = error?.localizedDescription ?? "nil"
        Task { @MainActor in
            scanLog.log("CB didDisconnect — \(id), error=\(errDesc)", level: .warning)
            handlePeripheralDisconnected(identifier: peripheral.identifier, error: error)
        }
    }
}
