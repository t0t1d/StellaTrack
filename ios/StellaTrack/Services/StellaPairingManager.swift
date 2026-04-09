import Foundation
import Combine
import CoreBluetooth
private var pairLog: BLEDebugLog { BLEDebugLog.shared }

enum PairingState: Equatable {
    case idle
    case connecting
    case configuringUWB
    case paired
    case failed(String)
}

@MainActor
class StellaPairingManager: NSObject, ObservableObject, BLEConnectionDelegate {
    @Published private(set) var pairingState: PairingState = .idle

    private(set) var pairedProvider: StellaDistanceProvider?

    private let centralManager: CentralManaging
    private var targetStella: DiscoveredStella?
    private var cancellables = Set<AnyCancellable>()
    private var uwbRetryCount = 0
    private let maxUWBRetries = 3

    convenience override init() {
        let cbCentral = CBCentralManager()
        self.init(centralManager: cbCentral)
    }

    init(centralManager: CentralManaging) {
        self.centralManager = centralManager
        super.init()
    }

    func pair(stella: DiscoveredStella) {
        targetStella = stella
        uwbRetryCount = 0
        pairingState = .connecting
        pairLog.log("pair() — name=\(stella.name), id=\(stella.peripheralIdentifier), hasPeripheral=\(stella.peripheral != nil)")

        if let cbPeripheral = stella.peripheral {
            pairLog.log("connecting via CBPeripheral reference")
            centralManager.connect(cbPeripheral, options: nil)
        } else {
            pairLog.log("connecting via identifier lookup", level: .warning)
            centralManager.connectPeripheral(identifier: stella.peripheralIdentifier, options: nil)
        }
    }

    func reset() {
        pairedProvider = nil
        targetStella = nil
        pairingState = .idle
        cancellables.removeAll()
    }

    // MARK: - BLE Event Handlers

    func handleDidConnect() {
        guard let stella = targetStella else { return }
        let placeholder = ReconnectPeripheralPlaceholder(identifier: stella.peripheralIdentifier, name: stella.name)
        handleDidConnect(peripheral: placeholder)
    }

    func handleDidConnect(peripheral: PeripheralManaging) {
        pairLog.log("handleDidConnect(peripheral:) — type=\(String(describing: type(of: peripheral))), id=\(peripheral.identifier)", level: .success)
        guard targetStella != nil else {
            pairLog.log("no targetStella, ignoring", level: .warning)
            return
        }
        pairingState = .configuringUWB

        let provider = StellaDistanceProvider(peripheral: peripheral, centralManager: centralManager)
        pairedProvider = provider
        pairLog.log("calling provider.handleDidConnect()")
        provider.handleDidConnect()

        provider.connectionStatusPublisher
            .dropFirst()
            .sink { [weak self] status in
                BLEDebugLog.shared.log("provider status: \(String(describing: status))")
                guard let self else { return }
                if status == .ranging {
                    self.handleRangingStarted()
                }
            }
            .store(in: &cancellables)
    }

    func handleDidFailToConnect(error: Error?) {
        pairLog.log("handleDidFailToConnect — \(error?.localizedDescription ?? "nil")", level: .error)
        let message = error?.localizedDescription ?? "Connection failed"
        pairingState = .failed(message)
        targetStella = nil
    }

    func handleDidDisconnect(error: Error?) {
        pairLog.log("handleDidDisconnect — \(error?.localizedDescription ?? "nil"), state=\(String(describing: self.pairingState))", level: .warning)
        if pairingState == .configuringUWB && uwbRetryCount < maxUWBRetries {
            uwbRetryCount += 1
            pairLog.log("BLE dropped during UWB setup — retry \(uwbRetryCount)/\(maxUWBRetries)", level: .warning)
            pairedProvider?.stop()
            pairedProvider = nil
            cancellables.removeAll()
            pairingState = .connecting
            retryConnection()
        } else if pairingState == .paired {
            pairedProvider?.handleDidDisconnect(error: error)
        } else {
            pairedProvider?.stop()
            pairedProvider = nil
            let message = error?.localizedDescription ?? "Disconnected during pairing"
            pairingState = .failed(message)
        }
    }

    private func retryConnection() {
        guard let stella = targetStella else { return }
        if let cbPeripheral = stella.peripheral {
            pairLog.log("retrying via CBPeripheral reference")
            centralManager.connect(cbPeripheral, options: nil)
        } else {
            pairLog.log("retrying via identifier lookup")
            centralManager.connectPeripheral(identifier: stella.peripheralIdentifier, options: nil)
        }
    }

    func handleRangingStarted() {
        pairingState = .paired
    }
}

private final class ReconnectPeripheralPlaceholder: PeripheralManaging {
    let identifier: UUID
    let name: String?

    init(identifier: UUID, name: String?) {
        self.identifier = identifier
        self.name = name
    }

    func discoverServices(_ serviceUUIDs: [CBUUID]?) {}
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for serviceID: CBUUID) {}
    func setNotifyValue(_ enabled: Bool, for characteristicID: CBUUID) {}
    func readValue(for characteristicID: CBUUID) {}
    func writeValue(_ data: Data, for characteristicID: CBUUID, type: CBCharacteristicWriteType) {}
}
