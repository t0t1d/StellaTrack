import SwiftUI
import CoreBluetooth

@main
struct StellaTrackApp: App {
    @StateObject private var deviceManager: DeviceManager
    @StateObject private var locationManager = LocationManager()
    @StateObject private var notificationService = NotificationService()

    init() {
        let isTestEnvironment = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if isTestEnvironment {
            _deviceManager = StateObject(wrappedValue: DeviceManager())
        } else {
            let central = CBCentralManager(delegate: nil, queue: nil)
            _deviceManager = StateObject(wrappedValue: DeviceManager(centralManager: central))
        }
    }
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MapHomeView()
                .environmentObject(deviceManager)
                .environmentObject(locationManager)
                .onAppear {
                    notificationService.requestPermission()
                    notificationService.observeAlerts(from: deviceManager.devices)
                    deviceManager.bindLocationManager(locationManager)
                }
                .onChange(of: deviceManager.devices.map(\.id)) { _, _ in
                    notificationService.observeAlerts(from: deviceManager.devices)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            notificationService.disableBackgroundDisconnectMonitoring()
            deviceManager.resumeAllStellaProviders()
            locationManager.disableBackgroundUpdates()
        case .background:
            deviceManager.saveNow()
            let hasAlertEnabled = deviceManager.devices.contains { $0.alertEngine.settings.alertEnabled }
            if hasAlertEnabled {
                notificationService.enableBackgroundDisconnectMonitoring(for: deviceManager.devices)
            }
            let hasMockAlerts = deviceManager.devices.contains { $0.isMock && $0.alertEngine.settings.alertEnabled }
            if hasMockAlerts {
                locationManager.requestAlwaysPermission()
                locationManager.enableBackgroundUpdates()
            }
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}
