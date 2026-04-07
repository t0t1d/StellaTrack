import SwiftUI

@main
struct StellaTrackApp: App {
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var notificationService = NotificationService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MapHomeView()
                .environmentObject(deviceManager)
                .onAppear {
                    notificationService.requestPermission()
                    notificationService.observeAlerts(from: deviceManager.devices)
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
        case .background:
            deviceManager.saveNow()
            let hasAlertEnabled = deviceManager.devices.contains { $0.alertEngine.settings.alertEnabled }
            if hasAlertEnabled {
                notificationService.enableBackgroundDisconnectMonitoring(for: deviceManager.devices)
            }
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}
