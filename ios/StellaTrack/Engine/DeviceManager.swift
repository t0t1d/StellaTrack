import Foundation
import Combine
import CoreLocation

@MainActor
class DeviceManager: ObservableObject {
    @Published private(set) var devices: [TrackedDevice] = []

    func addDevice(name: String, provider: DistanceProvider, settings: AlertSettings = .default) -> TrackedDevice {
        let device = TrackedDevice(name: name, provider: provider, settings: settings)
        devices.append(device)
        return device
    }

    @discardableResult
    func addMockDevice(name: String, settings: AlertSettings = .default, initialCoordinate: CLLocationCoordinate2D? = nil) -> TrackedDevice {
        let provider = MockDistanceProvider()
        let device = addDevice(name: name, provider: provider, settings: settings)
        if let coord = initialCoordinate {
            device.mockCoordinate = coord
        }
        provider.start()
        return device
    }

    func removeDevice(id: UUID) {
        if let index = devices.firstIndex(where: { $0.id == id }) {
            devices[index].provider.stop()
            devices.remove(at: index)
        }
    }
}
