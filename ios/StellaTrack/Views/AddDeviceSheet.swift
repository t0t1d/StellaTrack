import SwiftUI
import CoreLocation

struct AddDeviceSheet: View {
    @ObservedObject var deviceManager: DeviceManager
    @Binding var isPresented: Bool

    @StateObject private var scanner = StellaScanner()
    @StateObject private var pairingManager = StellaPairingManager()
    @StateObject private var locationManager = LocationManager()

    @State private var pairingTarget: DiscoveredStella?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scanSection

                Divider()
                    .padding(.vertical, 8)

                mockDeviceSection
            }
            .padding(.horizontal)
            .navigationTitle("Add Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                scanner.startScan()
                locationManager.requestPermission()
                locationManager.startUpdating()
            }
            .onDisappear {
                scanner.stopScan()
            }
            .onChange(of: pairingManager.pairingState) { _, newState in
                guard newState == .paired, let stella = pairingTarget else { return }
                let coord: CLLocationCoordinate2D?
                if let userLoc = locationManager.userLocation {
                    coord = CLLocationCoordinate2D(
                        latitude: userLoc.latitude + 0.0002,
                        longitude: userLoc.longitude
                    )
                } else {
                    coord = nil
                }
                deviceManager.addMockDevice(name: stella.name, initialCoordinate: coord, userLocation: locationManager.userLocation)
                pairingManager.reset()
                pairingTarget = nil
                isPresented = false
            }
        }
    }

    private var scanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nearby Stella")
                    .font(.headline)
                Spacer()
                scanningIndicator
            }

            if let target = pairingTarget {
                pairingProgressCard(for: target)
            }

            if scanner.discoveredDevices.isEmpty && scanner.scanningState == .scanning && pairingTarget == nil {
                ContentUnavailableView(
                    "Scanning…",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("Looking for Stella wearables nearby.")
                )
                .frame(maxHeight: 220)
            } else {
                List {
                    ForEach(scanner.discoveredDevices) { stella in
                        discoveredRow(stella)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowSeparator(.visible)
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: 180, maxHeight: 280)
            }
        }
    }

    @ViewBuilder
    private var scanningIndicator: some View {
        switch scanner.scanningState {
        case .scanning:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.85)
                Text("Scanning")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .idle, .stopped:
            Label("Ready", systemImage: "checkmark.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func rssiBars(for rssi: Int) -> Int {
        if rssi > -50 { return 3 }
        if rssi > -65 { return 2 }
        return 1
    }

    private func discoveredRow(_ stella: DiscoveredStella) -> some View {
        let bars = rssiBars(for: stella.rssi)
        let variableValue = Double(bars) / 3.0

        return Button {
            pairingTarget = stella
            pairingManager.reset()
            pairingManager.pair(stella: stella)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wifi", variableValue: variableValue)
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stella.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("\(stella.rssi) dBm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(pairingTarget != nil)
    }

    private func pairingProgressCard(for stella: DiscoveredStella) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stella.name)
                .font(.subheadline.weight(.semibold))

            Group {
                switch pairingManager.pairingState {
                case .idle:
                    Text("Tap a device to pair.")
                case .connecting:
                    Label("Connecting…", systemImage: "link")
                case .configuringUWB:
                    Label("Configuring UWB…", systemImage: "dot.radiowaves.left.and.right")
                case .paired:
                    Label("Paired", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if case .failed = pairingManager.pairingState {
                Button("Try Again") {
                    pairingManager.reset()
                    pairingManager.pair(stella: stella)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var mockDeviceSection: some View {
        VStack(spacing: 12) {
            Text("Development")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Add Mock Device") {
                let coord: CLLocationCoordinate2D?
                if let userLoc = locationManager.userLocation {
                    coord = CLLocationCoordinate2D(
                        latitude: userLoc.latitude + 0.0002,
                        longitude: userLoc.longitude
                    )
                } else {
                    coord = nil
                }
                deviceManager.addMockDevice(
                    name: "Child \(deviceManager.devices.count + 1)",
                    initialCoordinate: coord,
                    userLocation: locationManager.userLocation
                )
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding(.bottom, 8)
    }
}
