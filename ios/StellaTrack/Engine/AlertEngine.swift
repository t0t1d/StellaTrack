import Foundation
import Combine

@MainActor
class AlertEngine: ObservableObject {
    @Published private(set) var currentLevel: AlertLevel = .safe
    @Published private(set) var latestDistance: Double = 0.0
    @Published private(set) var alertHistory: [AlertEvent] = []

    var alertLevelPublisher: AnyPublisher<AlertLevel, Never> {
        $currentLevel.eraseToAnyPublisher()
    }

    @Published var settings: AlertSettings
    private var cancellables = Set<AnyCancellable>()
    private var persistenceTimer: DispatchSourceTimer?
    private var warningStartTime: Date?
    private let timerQueue = DispatchQueue(label: "com.separationawareness.alertengine.timer")

    init(provider: DistanceProvider, settings: AlertSettings = .default) {
        self.settings = settings

        provider.distancePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reading in
                self?.processReading(reading)
            }
            .store(in: &cancellables)
    }

    func updateSettings(_ newSettings: AlertSettings) {
        settings = newSettings
    }

    func updateSettings(thresholdDistance: Double) {
        settings.thresholdDistance = thresholdDistance
        reevaluate()
    }

    func updateSettings(persistenceDuration: TimeInterval) {
        settings.persistenceDuration = persistenceDuration
        reevaluate()
    }

    func setAlertEnabled(_ enabled: Bool) {
        settings.alertEnabled = enabled
        if enabled {
            reevaluate()
        } else {
            cancelPersistenceTimer()
            if currentLevel != .safe {
                transitionTo(.safe, distance: latestDistance)
            }
        }
    }

    private func reevaluate() {
        guard settings.alertEnabled, latestDistance > 0 else { return }
        let exceedsThreshold = latestDistance > settings.thresholdDistance
        if !exceedsThreshold && currentLevel != .safe {
            cancelPersistenceTimer()
            transitionTo(.safe, distance: latestDistance)
        } else if exceedsThreshold && currentLevel == .safe {
            transitionTo(.warning, distance: latestDistance)
            startPersistenceTimer()
        }
    }

    private func processReading(_ reading: DistanceReading) {
        guard reading.isValid else {
            cancelPersistenceTimer()
            return
        }
        latestDistance = reading.distance

        guard settings.alertEnabled else { return }

        let exceedsThreshold = reading.distance > settings.thresholdDistance

        switch (currentLevel, exceedsThreshold) {
        case (.safe, true):
            transitionTo(.warning, distance: reading.distance)
            startPersistenceTimer()

        case (.safe, false):
            break

        case (.warning, true):
            break

        case (.warning, false):
            cancelPersistenceTimer()
            transitionTo(.safe, distance: reading.distance)

        case (.alert, true):
            break

        case (.alert, false):
            transitionTo(.safe, distance: reading.distance)
        }
    }

    private func transitionTo(_ level: AlertLevel, distance: Double) {
        guard level != currentLevel else { return }
        currentLevel = level
        let event = AlertEvent(level: level, distance: distance, timestamp: Date())
        alertHistory.append(event)
    }

    private func startPersistenceTimer() {
        cancelPersistenceTimer()
        warningStartTime = Date()
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self,
                      self.currentLevel == .warning,
                      let start = self.warningStartTime,
                      Date().timeIntervalSince(start) >= self.settings.persistenceDuration else { return }
                self.cancelPersistenceTimer()
                self.transitionTo(.alert, distance: self.latestDistance)
            }
        }
        persistenceTimer = timer
        timer.resume()
    }

    private func cancelPersistenceTimer() {
        persistenceTimer?.cancel()
        persistenceTimer = nil
        warningStartTime = nil
    }
}
