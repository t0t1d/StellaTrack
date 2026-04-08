import Foundation
import Combine
import CoreLocation
import simd

@MainActor
class DeviceManager: ObservableObject {
    @Published private(set) var devices: [TrackedDevice] = []

    let persistenceService = PersistenceService()
    private var saveCancellable: AnyCancellable?
    private var deviceObservers = Set<AnyCancellable>()

    init() {
        restoreDevices()
    }

    func refreshMockDistances(userLocation: CLLocationCoordinate2D) {
        for device in devices {
            guard let mock = device.provider as? MockDistanceProvider,
                  let coord = device.mockCoordinate else { continue }
            Self.sendMockReading(provider: mock, from: userLocation, to: coord)
        }
    }

    func addDevice(name: String, provider: DistanceProvider, settings: AlertSettings = .default, id: UUID = UUID(), icon: String? = nil, isMock: Bool = false) -> TrackedDevice {
        let device = TrackedDevice(id: id, name: name, provider: provider, settings: settings, icon: icon, isMock: isMock)
        devices.append(device)
        observeDevice(device)
        scheduleSave()
        return device
    }

    @discardableResult
    func addMockDevice(name: String, settings: AlertSettings = .default, initialCoordinate: CLLocationCoordinate2D? = nil, userLocation: CLLocationCoordinate2D? = nil, id: UUID = UUID(), icon: String? = nil) -> TrackedDevice {
        let provider = MockDistanceProvider()
        let device = addDevice(name: name, provider: provider, settings: settings, id: id, icon: icon, isMock: true)
        if let coord = initialCoordinate {
            device.mockCoordinate = coord
        }
        provider.start()
        if let coord = initialCoordinate, let userLoc = userLocation {
            Self.sendMockReading(provider: provider, from: userLoc, to: coord)
        }
        return device
    }

    @discardableResult
    func addStellaDevice(name: String, settings: AlertSettings = .default, id: UUID = UUID(), icon: String? = nil) -> TrackedDevice {
        let provider = StubDistanceProvider()
        let device = addDevice(name: name, provider: provider, settings: settings, id: id, icon: icon, isMock: false)
        provider.start()
        return device
    }

    func removeDevice(id: UUID) {
        if let index = devices.firstIndex(where: { $0.id == id }) {
            devices[index].provider.stop()
            devices.remove(at: index)
            scheduleSave()
        }
    }

    // MARK: - Persistence

    private func restoreDevices() {
        let records = persistenceService.load()
        for record in records {
            let settings = AlertSettings(
                thresholdDistance: record.thresholdDistance,
                persistenceDuration: record.persistenceDuration,
                alertEnabled: record.alertEnabled,
                alertDuration: record.alertDuration ?? .infinity
            )
            if record.isMock {
                var coord: CLLocationCoordinate2D?
                if let lat = record.mockLatitude, let lon = record.mockLongitude {
                    coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                addMockDevice(
                    name: record.name,
                    settings: settings,
                    initialCoordinate: coord,
                    id: record.id,
                    icon: record.icon
                )
            } else {
                let provider = StubDistanceProvider()
                let device = addDevice(name: record.name, provider: provider, settings: settings, id: record.id, icon: record.icon, isMock: false)
                provider.start()
                _ = device
            }
        }
    }

    func scheduleSave() {
        saveCancellable?.cancel()
        saveCancellable = Just(())
            .delay(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveNow()
            }
    }

    func saveNow() {
        let records: [DeviceRecord] = devices.map { device in
            DeviceRecord(
                id: device.id,
                name: device.name,
                icon: device.icon,
                alertEnabled: device.alertEngine.settings.alertEnabled,
                thresholdDistance: device.alertEngine.settings.thresholdDistance,
                persistenceDuration: device.alertEngine.settings.persistenceDuration,
                alertDuration: device.alertEngine.settings.alertDuration.isInfinite ? nil : device.alertEngine.settings.alertDuration,
                isMock: device.isMock,
                mockLatitude: device.mockCoordinate?.latitude,
                mockLongitude: device.mockCoordinate?.longitude
            )
        }
        persistenceService.save(records)
    }

    private func observeDevice(_ device: TrackedDevice) {
        device.$name
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveNow() }
            .store(in: &deviceObservers)

        device.$icon
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveNow() }
            .store(in: &deviceObservers)

        device.alertEngine.$settings
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveNow() }
            .store(in: &deviceObservers)

        device.$mockCoordinate
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveNow() }
            .store(in: &deviceObservers)
    }

    static func sendMockReading(provider: MockDistanceProvider, from userLoc: CLLocationCoordinate2D, to target: CLLocationCoordinate2D) {
        let lat1 = userLoc.latitude * .pi / 180
        let lon1 = userLoc.longitude * .pi / 180
        let lat2 = target.latitude * .pi / 180
        let lon2 = target.longitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = lon2 - lon1
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let distance = 6_371_000.0 * 2 * atan2(sqrt(a), sqrt(1 - a))
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x)
        let direction = simd_float3(Float(sin(bearing)), 0, Float(cos(bearing)))
        provider.setDistance(distance, direction: direction)
    }
}
