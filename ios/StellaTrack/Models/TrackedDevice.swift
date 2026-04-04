import Foundation
import Combine
import CoreLocation

@MainActor
class TrackedDevice: ObservableObject, Identifiable {
    let id: UUID
    @Published var name: String
    let provider: DistanceProvider
    let alertEngine: AlertEngine
    let distanceHistory: DistanceHistory

    @Published var batteryLevel: Double?
    @Published var lastSeen: Date?
    @Published var mockCoordinate: CLLocationCoordinate2D?

    private var cancellables = Set<AnyCancellable>()

    init(id: UUID = UUID(), name: String, provider: DistanceProvider, settings: AlertSettings = .default) {
        self.id = id
        self.name = name
        self.provider = provider
        self.alertEngine = AlertEngine(provider: provider, settings: settings)
        self.distanceHistory = DistanceHistory()

        provider.distancePublisher
            .filter(\.isValid)
            .sink { [weak self] reading in
                self?.distanceHistory.add(distance: reading.distance, direction: reading.direction, at: reading.timestamp)
                self?.lastSeen = reading.timestamp
            }
            .store(in: &cancellables)

        provider.batteryLevelPublisher
            .sink { [weak self] level in
                self?.batteryLevel = level
            }
            .store(in: &cancellables)
    }
}
