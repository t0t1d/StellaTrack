import Foundation
import Combine
import CoreBluetooth
import NearbyInteraction
import simd
private var bleLog: BLEDebugLog { BLEDebugLog.shared }

private extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined()
    }
}

@MainActor
protocol PeripheralManaging: AnyObject {
    var identifier: UUID { get }
    var name: String? { get }
    func setPeripheralDelegate(_ delegate: CBPeripheralDelegate)
    func discoverServices(_ serviceUUIDs: [CBUUID]?)
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for serviceID: CBUUID)
    func setNotifyValue(_ enabled: Bool, for characteristicID: CBUUID)
    func readValue(for characteristicID: CBUUID)
    func writeValue(_ data: Data, for characteristicID: CBUUID, type: CBCharacteristicWriteType)
}

extension PeripheralManaging {
    func setPeripheralDelegate(_ delegate: CBPeripheralDelegate) {}
}

@MainActor
class StellaDistanceProvider: NSObject, DistanceProvider {

    // MARK: - Publishers

    private let distanceSubject = PassthroughSubject<DistanceReading, Never>()
    private let connectionStatusSubject = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)
    private let batteryLevelSubject = CurrentValueSubject<Double?, Never>(nil)

    var distancePublisher: AnyPublisher<DistanceReading, Never> {
        distanceSubject.eraseToAnyPublisher()
    }
    var connectionStatusPublisher: AnyPublisher<ConnectionStatus, Never> {
        connectionStatusSubject.eraseToAnyPublisher()
    }
    var batteryLevelPublisher: AnyPublisher<Double?, Never> {
        batteryLevelSubject.eraseToAnyPublisher()
    }
    var currentConnectionStatus: ConnectionStatus {
        connectionStatusSubject.value
    }

    // MARK: - BLE References

    let peripheralIdentifier: UUID
    private var peripheral: PeripheralManaging
    private let centralManager: CentralManaging

    private var commandCharID: CBUUID?
    private var batteryCharID: CBUUID?

    // NI protocol characteristics (on NUS config service)
    private var niRxCharID: CBUUID?
    private var niTxCharID: CBUUID?
    private var txSubscriptionConfirmed = false

    // Track which services have been discovered
    private var discoveredServiceCount = 0
    private var expectedServiceCount = 0
    private var allServicesReady = false

    // MARK: - UWB

    private var niSession: NISession?
    private var lastAccessoryConfigData: Data?
    private var lastRangingPublishDate: Date = .distantPast
    private let rangingInterval: TimeInterval = 1.0

    // MARK: - State

    private var wantsConnection = false
    private var reconnectAttempt = 0
    private var reconnectTimer: DispatchSourceTimer?
    private var batteryTimer: DispatchSourceTimer?
    private let bgQueue = DispatchQueue(label: "com.separationawareness.provider.timers")

    // MARK: - Init

    init(peripheral: PeripheralManaging, centralManager: CentralManaging) {
        self.peripheral = peripheral
        self.centralManager = centralManager
        self.peripheralIdentifier = peripheral.identifier
        super.init()
    }

    convenience init(cbPeripheral: CBPeripheral, cbCentralManager: CBCentralManager) {
        let wrapper = CBPeripheralWrapper(cbPeripheral)
        self.init(peripheral: wrapper, centralManager: cbCentralManager)
    }

    // MARK: - DistanceProvider

    func start() {
        guard !wantsConnection else { return }
        wantsConnection = true
        connectionStatusSubject.send(.searching)
        centralManager.connectPeripheral(identifier: peripheralIdentifier, options: nil)
    }

    func stop() {
        wantsConnection = false
        niSession?.invalidate()
        niSession = nil
        lastAccessoryConfigData = nil
        batteryTimer?.cancel()
        batteryTimer = nil
        reconnectTimer?.cancel()
        reconnectTimer = nil
        reconnectAttempt = 0
        centralManager.cancelPeripheralConnection(identifier: peripheralIdentifier)
        connectionStatusSubject.send(.disconnected)
    }

    func playSound() {
        writeCommand(.playSound, parameter: 3)
    }

    func stopSound() {
        writeCommand(.stopSound)
    }

    // MARK: - Peripheral Swap (for reconnect after app restart)

    func replacePeripheral(_ newPeripheral: PeripheralManaging) {
        peripheral = newPeripheral
    }

    // MARK: - BLE State Machine Handlers

    func handleDidConnect() {
        bleLog.log("handleDidConnect — id=\(peripheralIdentifier), type=\(String(describing: type(of: peripheral)))", level: .success)
        reconnectAttempt = 0
        reconnectTimer?.cancel()
        reconnectTimer = nil
        discoveredServiceCount = 0
        expectedServiceCount = 0
        txSubscriptionConfirmed = false
        allServicesReady = false
        lastRangingPublishDate = .distantPast
        connectionStatusSubject.send(.connected)
        peripheral.setPeripheralDelegate(self)
        bleLog.log("discoverServices for NI + Custom services")
        peripheral.discoverServices(StellaConstants.allServiceUUIDs)
    }

    func handleDidFailToConnect(error: Error?) {
        bleLog.log("handleDidFailToConnect — error=\(error?.localizedDescription ?? "nil")", level: .error)
        connectionStatusSubject.send(.disconnected)
    }

    func handleDidDisconnect(error: Error?) {
        niSession?.invalidate()
        niSession = nil
        batteryTimer?.cancel()
        batteryTimer = nil
        reconnectTimer?.cancel()
        reconnectTimer = nil

        if wantsConnection {
            connectionStatusSubject.send(.searching)
            scheduleReconnect()
        } else {
            connectionStatusSubject.send(.disconnected)
            reconnectAttempt = 0
        }
    }

    func handleCustomCharacteristicsDiscovered(
        commandCharID: CBUUID?,
        batteryCharID: CBUUID?
    ) {
        self.commandCharID = commandCharID
        self.batteryCharID = batteryCharID

        if let batteryCharID {
            peripheral.setNotifyValue(true, for: batteryCharID)
            peripheral.readValue(for: batteryCharID)
            startBatteryPolling()
        }
        bleLog.log("Custom service chars: cmd=\(commandCharID != nil), bat=\(batteryCharID != nil)")
    }

    func handleNICharacteristicsDiscovered(
        rxCharID: CBUUID?,
        txCharID: CBUUID?
    ) {
        self.niRxCharID = rxCharID
        self.niTxCharID = txCharID

        if let txCharID {
            peripheral.setNotifyValue(true, for: txCharID)
        }
    }

    func handleTxSubscriptionConfirmed() {
        txSubscriptionConfirmed = true
        bleLog.log("TX subscription confirmed")
        sendInitCommandIfReady()
    }

    func handleTxSubscriptionFailed(error: Error?) {
        bleLog.log("TX subscription failed: \(error?.localizedDescription ?? "unknown") — falling back to BLE-only", level: .error)
        connectionStatusSubject.send(.ranging)
    }

    func handleAllServicesReady() {
        allServicesReady = true
        sendInitCommandIfReady()
    }

    private func sendInitCommandIfReady() {
        guard allServicesReady else { return }
        let hasNUSChars = niRxCharID != nil && niTxCharID != nil

        if hasNUSChars && txSubscriptionConfirmed {
            bleLog.log("NUS RX/TX + TX subscribed — starting NI protocol", level: .success)
            if let niRxCharID {
                let data = Data([StellaConstants.NICommand.initializeIOS.rawValue])
                bleLog.log("[BLE] Writing to \(niRxCharID.uuidString): \(data.hexString)", level: .success)
                peripheral.writeValue(data, for: niRxCharID, type: .withResponse)
            }
        } else if hasNUSChars && !txSubscriptionConfirmed {
            bleLog.log("Waiting for TX subscription confirmation before sending 0x0A")
        } else {
            bleLog.log("BLE-only mode — NUS chars not found, signaling .ranging to complete pairing", level: .success)
            connectionStatusSubject.send(.ranging)
        }
    }

    func handleUWBDidStart() {
        bleLog.log("[NI] UWB did start — transitioning to .ranging", level: .success)
        connectionStatusSubject.send(.ranging)
    }

    func handleUWBDidStop() {
        bleLog.log("[NI] UWB did stop", level: .warning)
    }

    func handleBatteryUpdate(level: Double) {
        batteryLevelSubject.send(level)
    }

    func handleRangingUpdate(distance: Float, direction: simd_float3?) {
        if currentConnectionStatus != .ranging {
            connectionStatusSubject.send(.ranging)
        }

        let now = Date()
        guard now.timeIntervalSince(lastRangingPublishDate) >= rangingInterval else { return }
        lastRangingPublishDate = now

        let reading = DistanceReading(
            distance: Double(distance),
            direction: direction,
            timestamp: now,
            isValid: true
        )
        distanceSubject.send(reading)
    }

    func handleUWBConfigReceived(data: Data) {
        bleLog.log("[NI] Received accessory config: \(data.count) bytes")
        bleLog.log("[NI] Config hex: \(data.hexString)")
        bleLog.log("[NI] Peripheral identifier for NI: \(peripheralIdentifier)")

        lastAccessoryConfigData = data

        let caps = NISession.deviceCapabilities
        bleLog.log("[NI] Device supportsPreciseDistanceMeasurement: \(caps.supportsPreciseDistanceMeasurement)")

        if !caps.supportsPreciseDistanceMeasurement {
            bleLog.log("[NI] ERROR: This device does not support UWB ranging", level: .error)
            connectionStatusSubject.send(.ranging)
            return
        }

        startNISession(with: data)
    }

    private func startNISession(with data: Data) {
        do {
            bleLog.log("[NI] Creating NINearbyAccessoryConfiguration(data:) — \(data.count) bytes...")
            let config = try NINearbyAccessoryConfiguration(data: data)
            bleLog.log("[NI] Config created successfully", level: .success)

            let session = NISession()
            session.delegate = self
            niSession = session
            bleLog.log("[NI] NISession created, calling run()...")
            session.run(config)
            bleLog.log("[NI] NISession.run() called — waiting for didGenerateShareableConfigurationData", level: .success)
        } catch {
            bleLog.log("[NI] ERROR creating config: \(error)", level: .error)
            bleLog.log("[NI] Error domain: \((error as NSError).domain), code: \((error as NSError).code)", level: .error)
            connectionStatusSubject.send(.connected)
        }
    }

    func handleShareableConfigGenerated(data: Data) {
        guard let niRxCharID else {
            bleLog.log("Cannot send shareable config — NI RX char not available", level: .error)
            return
        }
        bleLog.log("[NI] Raw shareable data: \(data.count) bytes")
        bleLog.log("[NI] Hex: \(data.hexString)")
        var payload = Data([StellaConstants.NICommand.configureAndStart.rawValue])
        payload.append(data)
        bleLog.log("[BLE] Writing to \(niRxCharID.uuidString): \(payload.hexString) (.withoutResponse)", level: .success)
        peripheral.writeValue(payload, for: niRxCharID, type: .withoutResponse)
    }

    // MARK: - Private

    private func writeCommand(_ command: StellaConstants.DeviceCommand, parameter: UInt8 = 0) {
        guard let commandCharID else { return }
        let data = command.data(parameter: parameter)
        bleLog.log("[BLE] Writing to \(commandCharID.uuidString): \(data.hexString)")
        peripheral.writeValue(data, for: commandCharID, type: .withResponse)
    }

    private func scheduleReconnect() {
        reconnectTimer?.cancel()
        let delays: [TimeInterval] = [2, 4, 8, 15, 30, 60]
        let delay = delays[min(reconnectAttempt, delays.count - 1)]
        reconnectAttempt += 1
        let timer = DispatchSource.makeTimerSource(queue: bgQueue)
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.wantsConnection else { return }
                self.centralManager.connectPeripheral(identifier: self.peripheralIdentifier, options: nil)
            }
        }
        reconnectTimer = timer
        timer.resume()
    }

    private func startBatteryPolling() {
        batteryTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: bgQueue)
        timer.schedule(deadline: .now() + 30, repeating: 30)
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, let batteryCharID = self.batteryCharID else { return }
                self.peripheral.readValue(for: batteryCharID)
            }
        }
        batteryTimer = timer
        timer.resume()
    }

    func resumeAfterBackground() {
        guard wantsConnection else { return }
        bleLog.log("resumeAfterBackground — status=\(String(describing: currentConnectionStatus))")

        switch currentConnectionStatus {
        case .disconnected, .searching:
            bleLog.log("BLE not connected — triggering reconnect", level: .warning)
            centralManager.connectPeripheral(identifier: peripheralIdentifier, options: nil)
        case .connected, .ranging:
            if niSession == nil, let configData = lastAccessoryConfigData {
                bleLog.log("NISession gone — restarting with cached config", level: .warning)
                startNISession(with: configData)
            } else if niSession == nil {
                bleLog.log("NISession gone, no cached config — sending fresh init", level: .warning)
                sendFreshInitCommand()
            }
        }
    }

    func sendFreshInitCommand() {
        guard let niRxCharID else { return }
        let data = Data([StellaConstants.NICommand.initializeIOS.rawValue])
        bleLog.log("[BLE] Writing to \(niRxCharID.uuidString): \(data.hexString) (fresh init)", level: .success)
        peripheral.writeValue(data, for: niRxCharID, type: .withResponse)
    }
}

// MARK: - CBPeripheralDelegate

extension StellaDistanceProvider: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let serviceList = peripheral.services?.map { $0.uuid.uuidString } ?? []
        let errDesc = error?.localizedDescription
        Task { @MainActor in
            bleLog.log("didDiscoverServices — error=\(errDesc ?? "nil"), services=\(serviceList)")
            if let error {
                bleLog.log("Service discovery error: \(error.localizedDescription)", level: .error)
                self.connectionStatusSubject.send(.disconnected)
                return
            }

            guard let services = peripheral.services, !services.isEmpty else {
                bleLog.log("No services found", level: .error)
                self.connectionStatusSubject.send(.disconnected)
                return
            }

            self.expectedServiceCount = services.count
            self.discoveredServiceCount = 0

            for service in services {
                switch service.uuid {
                case StellaConstants.niServiceUUID:
                    bleLog.log("Found NI accessory service (supplementary)", level: .success)
                    peripheral.discoverCharacteristics(
                        [StellaConstants.niAccessoryConfigUUID],
                        for: service
                    )
                case StellaConstants.nusServiceUUID:
                    bleLog.log("Found NUS config service (Nordic UART), discovering chars...", level: .success)
                    peripheral.discoverCharacteristics(
                        [StellaConstants.rxCharUUID, StellaConstants.txCharUUID],
                        for: service
                    )
                case StellaConstants.customServiceUUID:
                    bleLog.log("Found Custom service, discovering chars...", level: .success)
                    peripheral.discoverCharacteristics(
                        [StellaConstants.batteryLevelUUID, StellaConstants.commandUUID, StellaConstants.deviceInfoUUID],
                        for: service
                    )
                default:
                    bleLog.log("Ignoring unknown service: \(service.uuid.uuidString)")
                    self.discoveredServiceCount += 1
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let charList = service.characteristics?.map { $0.uuid.uuidString } ?? []
        let svcUUID = service.uuid.uuidString
        let errDesc = error?.localizedDescription
        Task { @MainActor in
            bleLog.log("didDiscoverCharacteristics — service=\(svcUUID), error=\(errDesc ?? "nil"), chars=\(charList)")
            if let error {
                bleLog.log("Characteristic discovery error: \(error.localizedDescription)", level: .error)
                self.discoveredServiceCount += 1
                self.checkAllServicesDiscovered()
                return
            }
            guard let chars = service.characteristics else {
                self.discoveredServiceCount += 1
                self.checkAllServicesDiscovered()
                return
            }

            switch service.uuid {
            case StellaConstants.niServiceUUID:
                bleLog.log("NI accessory service chars discovered", level: .success)

            case StellaConstants.nusServiceUUID:
                var rxID: CBUUID?
                var txID: CBUUID?
                for char in chars {
                    switch char.uuid {
                    case StellaConstants.rxCharUUID: rxID = char.uuid
                    case StellaConstants.txCharUUID: txID = char.uuid
                    default: break
                    }
                }
                bleLog.log("NUS config chars: rx=\(rxID != nil), tx=\(txID != nil)", level: .success)
                handleNICharacteristicsDiscovered(rxCharID: rxID, txCharID: txID)

            case StellaConstants.customServiceUUID:
                var cmdID: CBUUID?
                var batID: CBUUID?
                for char in chars {
                    switch char.uuid {
                    case StellaConstants.commandUUID: cmdID = char.uuid
                    case StellaConstants.batteryLevelUUID: batID = char.uuid
                    default: break
                    }
                }
                handleCustomCharacteristicsDiscovered(commandCharID: cmdID, batteryCharID: batID)

            default:
                break
            }

            self.discoveredServiceCount += 1
            self.checkAllServicesDiscovered()
        }
    }

    private func checkAllServicesDiscovered() {
        guard discoveredServiceCount >= expectedServiceCount else { return }
        bleLog.log("All \(discoveredServiceCount) services processed")
        handleAllServicesReady()
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let charUUID = characteristic.uuid.uuidString
        let errDesc = error?.localizedDescription
        Task { @MainActor in
            bleLog.log("didUpdateNotificationState — char=\(charUUID), error=\(errDesc ?? "nil"), isNotifying=\(characteristic.isNotifying)")
            if characteristic.uuid == StellaConstants.txCharUUID {
                if characteristic.isNotifying && error == nil {
                    handleTxSubscriptionConfirmed()
                } else if error != nil {
                    handleTxSubscriptionFailed(error: error)
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let charUUID = characteristic.uuid.uuidString
        let byteCount = characteristic.value?.count ?? 0
        let errDesc = error?.localizedDescription
        Task { @MainActor in
            let hex = characteristic.value.map { $0.map { String(format: "%02X", $0) }.joined() } ?? "nil"
            bleLog.log("didUpdateValue — char=\(charUUID), error=\(errDesc ?? "nil"), bytes=\(byteCount), hex=\(hex)")
            guard error == nil, let value = characteristic.value else {
                bleLog.log("didUpdateValue error or nil data for \(charUUID)", level: .error)
                return
            }

            switch characteristic.uuid {
            case StellaConstants.txCharUUID:
                guard let firstByte = value.first else { return }
                switch StellaConstants.NIResponse(rawValue: firstByte) {
                case .initializedData where value.count > 1:
                    let configData = value.subdata(in: 1..<value.count)
                    bleLog.log("NI accessory config received (\(configData.count) bytes)", level: .success)
                    handleUWBConfigReceived(data: configData)
                case .uwbDidStart:
                    handleUWBDidStart()
                case .uwbDidStop:
                    handleUWBDidStop()
                default:
                    bleLog.log("NI TX unknown response: 0x\(String(format: "%02X", firstByte)), \(value.count) bytes")
                }

            case StellaConstants.batteryLevelUUID:
                if let byte = value.first {
                    bleLog.log("Battery raw: \(byte)", level: .success)
                    handleBatteryUpdate(level: Double(byte))
                } else {
                    bleLog.log("Battery characteristic returned empty data", level: .warning)
                }

            default:
                bleLog.log("unhandled char value: \(charUUID)")
                break
            }
        }
    }
}

// MARK: - NISessionDelegate

extension StellaDistanceProvider: NISessionDelegate {
    nonisolated func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        Task { @MainActor in
            for (i, obj) in nearbyObjects.enumerated() {
                let dist = obj.distance.map { String(format: "%.3f m", $0) } ?? "nil"
                let dir = obj.direction.map { "(\($0.x), \($0.y), \($0.z))" } ?? "nil"
                bleLog.log("[NI] didUpdate object[\(i)] — distance=\(dist), direction=\(dir)")
            }
            guard let obj = nearbyObjects.first, let distance = obj.distance else {
                bleLog.log("[NI] didUpdate — no valid distance in \(nearbyObjects.count) objects", level: .warning)
                return
            }
            handleRangingUpdate(distance: distance, direction: obj.direction)
        }
    }

    nonisolated func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        Task { @MainActor in
            bleLog.log("[NI] didRemove — \(nearbyObjects.count) objects, reason=\(reason.rawValue)", level: .warning)
        }
    }

    nonisolated func session(_ session: NISession, didGenerateShareableConfigurationData shareableConfigurationData: Data, for object: NINearbyObject) {
        Task { @MainActor in
            bleLog.log("[NI] didGenerateShareableConfigurationData — \(shareableConfigurationData.count) bytes", level: .success)
            handleShareableConfigGenerated(data: shareableConfigurationData)
        }
    }

    nonisolated func session(_ session: NISession, didInvalidateWith error: Error) {
        Task { @MainActor in
            bleLog.log("[NI] session didInvalidateWith: \(error.localizedDescription)", level: .error)
            niSession = nil
            guard wantsConnection && currentConnectionStatus != .disconnected else { return }
            connectionStatusSubject.send(.connected)
            sendFreshInitCommand()
        }
    }

    nonisolated func sessionWasSuspended(_ session: NISession) {
        Task { @MainActor in
            bleLog.log("[NI] session was suspended", level: .warning)
        }
    }

    nonisolated func sessionSuspensionEnded(_ session: NISession) {
        Task { @MainActor in
            bleLog.log("[NI] session suspension ended — attempting to re-run", level: .success)
            guard let configData = lastAccessoryConfigData else {
                bleLog.log("[NI] no cached config to re-run, requesting fresh init", level: .warning)
                sendFreshInitCommand()
                return
            }
            startNISession(with: configData)
        }
    }
}

// MARK: - CBPeripheral Wrapper

final class CBPeripheralWrapper: PeripheralManaging {
    private let cbPeripheral: CBPeripheral
    var identifier: UUID { cbPeripheral.identifier }
    var name: String? { cbPeripheral.name }

    private var characteristicMap: [CBUUID: CBCharacteristic] = [:]

    init(_ cbPeripheral: CBPeripheral) {
        self.cbPeripheral = cbPeripheral
    }

    func setPeripheralDelegate(_ delegate: CBPeripheralDelegate) {
        cbPeripheral.delegate = delegate
    }

    func discoverServices(_ serviceUUIDs: [CBUUID]?) {
        cbPeripheral.discoverServices(serviceUUIDs)
    }

    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for serviceID: CBUUID) {
        guard let service = cbPeripheral.services?.first(where: { $0.uuid == serviceID }) else { return }
        cbPeripheral.discoverCharacteristics(characteristicUUIDs, for: service)
    }

    func setNotifyValue(_ enabled: Bool, for characteristicID: CBUUID) {
        guard let char = findCharacteristic(characteristicID) else { return }
        cbPeripheral.setNotifyValue(enabled, for: char)
    }

    func readValue(for characteristicID: CBUUID) {
        guard let char = findCharacteristic(characteristicID) else { return }
        cbPeripheral.readValue(for: char)
    }

    func writeValue(_ data: Data, for characteristicID: CBUUID, type: CBCharacteristicWriteType) {
        guard let char = findCharacteristic(characteristicID) else { return }
        cbPeripheral.writeValue(data, for: char, type: type)
    }

    private func findCharacteristic(_ uuid: CBUUID) -> CBCharacteristic? {
        if let cached = characteristicMap[uuid] { return cached }
        for service in cbPeripheral.services ?? [] {
            if let char = service.characteristics?.first(where: { $0.uuid == uuid }) {
                characteristicMap[uuid] = char
                return char
            }
        }
        return nil
    }
}
