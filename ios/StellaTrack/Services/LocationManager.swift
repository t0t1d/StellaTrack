import Foundation
import CoreLocation
import Combine

@MainActor
class LocationManager: NSObject, ObservableObject {
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var heading: CLLocationDirection?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private(set) var isBackgroundEnabled = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 1
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysPermission() {
        manager.requestAlwaysAuthorization()
    }

    func startUpdating() {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
        if let h = manager.heading, h.trueHeading >= 0 {
            heading = h.trueHeading
        }
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func enableBackgroundUpdates() {
        isBackgroundEnabled = true
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    func disableBackgroundUpdates() {
        isBackgroundEnabled = false
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
        manager.showsBackgroundLocationIndicator = false
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coord = location.coordinate
        Task { @MainActor in
            self.userLocation = coord
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let trueHeading = newHeading.trueHeading
        Task { @MainActor in
            self.heading = trueHeading >= 0 ? trueHeading : nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.startUpdating()
            }
        }
    }
}
