import Foundation
import Combine
import CoreLocation

@MainActor
class TrackedDevice: ObservableObject, Identifiable {
    static let availableIcons = [
        "figure.child", "figure.walk", "figure.run",
        "figure.roll", "figure.wave",
        "hare.fill", "tortoise.fill", "dog.fill",
        "cat.fill", "bird.fill"
    ]

    private static var nextIconIndex = 0

    let id: UUID
    @Published var name: String
    let provider: DistanceProvider
    let alertEngine: AlertEngine
    let distanceHistory: DistanceHistory
    @Published var icon: String
    let isMock: Bool

    @Published var batteryLevel: Double?
    @Published var lastSeen: Date?
    @Published var mockCoordinate: CLLocationCoordinate2D?

    func setIcon(_ newIcon: String) {
        icon = newIcon
    }

    private var cancellables = Set<AnyCancellable>()

    init(id: UUID = UUID(), name: String, provider: DistanceProvider, settings: AlertSettings = .default, icon: String? = nil, isMock: Bool = false) {
        if let icon {
            self.icon = icon
        } else {
            self.icon = TrackedDevice.availableIcons[TrackedDevice.nextIconIndex % TrackedDevice.availableIcons.count]
            TrackedDevice.nextIconIndex += 1
        }
        self.id = id
        self.name = name
        self.provider = provider
        self.isMock = isMock
        self.alertEngine = AlertEngine(provider: provider, settings: settings)
        self.distanceHistory = DistanceHistory()

        provider.distancePublisher
            .filter(\.isValid)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reading in
                self?.distanceHistory.add(distance: reading.distance, direction: reading.direction, at: reading.timestamp)
                self?.lastSeen = reading.timestamp
            }
            .store(in: &cancellables)

        provider.batteryLevelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.batteryLevel = level
            }
            .store(in: &cancellables)
    }
}
