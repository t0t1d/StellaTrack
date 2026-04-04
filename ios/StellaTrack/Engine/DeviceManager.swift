import Foundation
import Combine
import CoreLocation
import simd

@MainActor
class DeviceManager: ObservableObject {
    @Published private(set) var devices: [TrackedDevice] = []

    func addDevice(name: String, provider: DistanceProvider, settings: AlertSettings = .default) -> TrackedDevice {
        let device = TrackedDevice(name: name, provider: provider, settings: settings)
        devices.append(device)
        return device
    }

    @discardableResult
    func addMockDevice(name: String, settings: AlertSettings = .default, initialCoordinate: CLLocationCoordinate2D? = nil, userLocation: CLLocationCoordinate2D? = nil) -> TrackedDevice {
        let provider = MockDistanceProvider()
        let device = addDevice(name: name, provider: provider, settings: settings)
        if let coord = initialCoordinate {
            device.mockCoordinate = coord
        }
        provider.start()
        if let coord = initialCoordinate, let userLoc = userLocation {
            Self.sendMockReading(provider: provider, from: userLoc, to: coord)
        }
        return device
    }

    func removeDevice(id: UUID) {
        if let index = devices.firstIndex(where: { $0.id == id }) {
            devices[index].provider.stop()
            devices.remove(at: index)
        }
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
