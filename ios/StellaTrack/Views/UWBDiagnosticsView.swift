import SwiftUI
import NearbyInteraction

struct UWBDiagnosticsView: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @ObservedObject private var bleDebugLog = BLEDebugLog.shared
    @State private var results: [DiagnosticItem] = []
    @State private var isLoading = true
    @State private var showResetConfirmation = false
    @State private var didReset = false
    @State private var showBLELog = false

    var body: some View {
        List {
            Section {
                NavigationLink("BLE Debug Log (\(bleDebugLog.entries.count))", isActive: $showBLELog) {
                    BLELogView()
                }
            }

            Section("Device") {
                DiagnosticRow(label: "Model", value: deviceModel)
                DiagnosticRow(label: "iOS Version", value: UIDevice.current.systemVersion)
                DiagnosticRow(label: "Device Name", value: UIDevice.current.name)
            }

            Section("UWB Capabilities") {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Checking capabilities...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(results) { item in
                        DiagnosticRow(
                            label: item.name,
                            value: item.value,
                            status: item.status
                        )
                    }
                }
            }

            Section("What This Means") {
                let directionSupported = results.first(where: { $0.name == "Direction Measurement" })?.status == .pass
                let cameraAssistSupported = results.first(where: { $0.name == "Camera Assistance" })?.status == .pass
                if isLoading {
                    Text("Checking...")
                        .foregroundColor(.secondary)
                } else if directionSupported {
                    Label {
                        Text("Your device supports native UWB direction. The direction arrow and estimated map pin will work with a compatible UWB accessory.")
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                } else if cameraAssistSupported {
                    Label {
                        Text("Your device (iPhone 14 series) does not support native UWB direction, but supports Camera-Assisted direction via ARKit. Direction will work when the camera session is active. This requires holding the phone with the camera pointing forward.")
                    } icon: {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom, 4)
                    Label {
                        Text("Native direction: iPhone 11–13, 15, 16\nCamera-assisted only: iPhone 14 (all models)\nThis is an Apple hardware limitation, not a bug.")
                    } icon: {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                } else {
                    Label {
                        Text("Your device does not support UWB direction measurement. The app will show a distance radius on the map instead of a precise direction pin.")
                    } icon: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }

            Section("Raw NISession Info") {
                let caps = NISession.deviceCapabilities
                DiagnosticRow(label: "Capabilities Type", value: String(describing: type(of: caps)))
            }

            Section {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                        Text("Hard Reset App")
                    }
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("Removes all devices, alert settings, and saved configuration. This cannot be undone.")
            }
        }
        .navigationTitle("UWB Diagnostics")
        .onAppear { runDiagnostics() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isLoading = true
                    results = []
                    runDiagnostics()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .alert("Hard Reset", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Everything", role: .destructive) {
                deviceManager.resetAll()
                didReset = true
            }
        } message: {
            Text("This will remove all devices, alert settings, and saved data. You will need to re-pair all devices.")
        }
        .alert("Reset Complete", isPresented: $didReset) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("All app data has been cleared.")
        }
    }

    private func runDiagnostics() {
        var items: [DiagnosticItem] = []

        let caps = NISession.deviceCapabilities
        let isSupported = caps.supportsPreciseDistanceMeasurement
        items.append(DiagnosticItem(
            name: "NearbyInteraction Supported",
            value: isSupported ? "Yes" : "No",
            status: isSupported ? .pass : .fail
        ))

        if isSupported {

            let supportsDistance = caps.supportsPreciseDistanceMeasurement
            items.append(DiagnosticItem(
                name: "Precise Distance",
                value: supportsDistance ? "Yes" : "No",
                status: supportsDistance ? .pass : .fail
            ))

            let supportsDirection = caps.supportsDirectionMeasurement
            items.append(DiagnosticItem(
                name: "Direction Measurement",
                value: supportsDirection ? "Yes" : "No",
                status: supportsDirection ? .pass : .warn
            ))

            if #available(iOS 16.0, *) {
                let supportsCameraAssist = caps.supportsCameraAssistance
                items.append(DiagnosticItem(
                    name: "Camera Assistance",
                    value: supportsCameraAssist ? "Yes" : "No",
                    status: supportsCameraAssist ? .pass : .info
                ))
            }

            if #available(iOS 17.0, *) {
                let supportsExtended = caps.supportsExtendedDistanceMeasurement
                items.append(DiagnosticItem(
                    name: "Extended Distance (U2)",
                    value: supportsExtended ? "Yes" : "No",
                    status: supportsExtended ? .pass : .info
                ))
            }
        } else {
            items.append(DiagnosticItem(
                name: "UWB Hardware",
                value: "Not available on this device",
                status: .fail
            ))
        }

        results = items
        isLoading = false
    }

    private var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { id, element in
            guard let value = element.value as? Int8, value != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(value)))
        }
        return "\(identifier) (\(modelName(for: identifier)))"
    }

    private func modelName(for identifier: String) -> String {
        let map: [String: String] = [
            "iPhone13,2": "iPhone 12",
            "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,4": "iPhone 12 Pro Max",
            "iPhone13,1": "iPhone 12 mini",
            "iPhone14,5": "iPhone 13",
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus",
            "iPhone17,5": "iPhone 16e",
            "arm64": "Simulator",
        ]
        return map[identifier] ?? identifier
    }
}

private struct DiagnosticItem: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let status: DiagnosticStatus
}

private enum DiagnosticStatus {
    case pass, warn, fail, info
}

private struct DiagnosticRow: View {
    let label: String
    let value: String
    var status: DiagnosticStatus? = nil

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            if let status {
                Image(systemName: icon(for: status))
                    .foregroundColor(color(for: status))
            }
            Text(value)
                .foregroundColor(.secondary)
        }
    }

    private func icon(for status: DiagnosticStatus) -> String {
        switch status {
        case .pass: return "checkmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private func color(for status: DiagnosticStatus) -> Color {
        switch status {
        case .pass: return .green
        case .warn: return .orange
        case .fail: return .red
        case .info: return .blue
        }
    }
}
