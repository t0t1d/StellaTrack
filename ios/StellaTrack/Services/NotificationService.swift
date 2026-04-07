import Foundation
import UserNotifications
import Combine

@MainActor
class NotificationService: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private var alertDeviceCancellables = Set<AnyCancellable>()
    private var disconnectCancellables = Set<AnyCancellable>()
    private var disconnectTimers: [UUID: DispatchSourceTimer] = [:]
    private let disconnectQueue = DispatchQueue(label: "com.separationawareness.disconnect")

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func observeAlerts(from engine: AlertEngine) {
        engine.alertLevelPublisher
            .removeDuplicates()
            .filter { $0 == .alert }
            .sink { [weak self] _ in
                self?.sendAlertNotification(deviceName: nil, distance: engine.latestDistance)
            }
            .store(in: &cancellables)
    }

    func observeAlerts(from devices: [TrackedDevice]) {
        alertDeviceCancellables.removeAll()
        for device in devices {
            device.alertEngine.alertLevelPublisher
                .removeDuplicates()
                .filter { $0 == .alert }
                .sink { [weak self] _ in
                    self?.sendAlertNotification(deviceName: device.name, distance: device.alertEngine.latestDistance)
                }
                .store(in: &alertDeviceCancellables)
        }
    }

    func observeBattery(from device: TrackedDevice) {
        device.$batteryLevel
            .compactMap { $0 }
            .removeDuplicates()
            .filter { $0 < 20 }
            .sink { [weak self] level in
                self?.sendBatteryNotification(deviceName: device.name, level: level)
            }
            .store(in: &cancellables)
    }

    // MARK: - Background disconnect monitoring

    func enableBackgroundDisconnectMonitoring(for devices: [TrackedDevice]) {
        disableBackgroundDisconnectMonitoring()
        for device in devices {
            guard device.alertEngine.settings.alertEnabled else { continue }

            device.provider.connectionStatusPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] status in
                    guard let self else { return }
                    if status == .disconnected {
                        self.startDisconnectTimer(for: device)
                    } else {
                        self.cancelDisconnectTimer(for: device.id)
                    }
                }
                .store(in: &disconnectCancellables)
        }
    }

    func disableBackgroundDisconnectMonitoring() {
        disconnectCancellables.removeAll()
        for (_, timer) in disconnectTimers {
            timer.cancel()
        }
        disconnectTimers.removeAll()
    }

    private func startDisconnectTimer(for device: TrackedDevice) {
        cancelDisconnectTimer(for: device.id)
        let timer = DispatchSource.makeTimerSource(queue: disconnectQueue)
        timer.schedule(deadline: .now() + 30)
        let deviceName = device.name
        let deviceId = device.id
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.sendDisconnectNotification(deviceName: deviceName)
                self?.disconnectTimers.removeValue(forKey: deviceId)
            }
        }
        disconnectTimers[device.id] = timer
        timer.resume()
    }

    private func cancelDisconnectTimer(for id: UUID) {
        disconnectTimers[id]?.cancel()
        disconnectTimers.removeValue(forKey: id)
    }

    // MARK: - Notification senders

    private nonisolated func sendAlertNotification(deviceName: String?, distance: Double) {
        let content = UNMutableNotificationContent()
        if let deviceName {
            content.title = "Separation Alert — \(deviceName)"
        } else {
            content.title = "Separation Alert"
        }
        content.body = String(format: "Distance has exceeded threshold: %.1f m", distance)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "separation-alert-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private nonisolated func sendBatteryNotification(deviceName: String, level: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Battery Low — \(deviceName)"
        content.body = String(format: "%@ battery is at %.0f%%. Please replace the CR2032 battery.", deviceName, level)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "battery-low-\(deviceName)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private nonisolated func sendDisconnectNotification(deviceName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Device Disconnected — \(deviceName)"
        content.body = "\(deviceName) may be out of range. Connection lost for over 30 seconds."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "disconnect-\(deviceName)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
