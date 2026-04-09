import SwiftUI
import Combine
import CoreLocation

struct AddDeviceSheet: View {
    @ObservedObject var deviceManager: DeviceManager
    @ObservedObject var locationManager: LocationManager
    @Binding var isPresented: Bool

    @StateObject private var scanner = StellaScanner()
    @StateObject private var pairingBridge = PairingBridge()
    @State private var pairingTarget: DiscoveredStella?

    private var pairingManager: StellaPairingManager? { pairingBridge.manager }
    private var currentPairingState: PairingState { pairingBridge.state }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scanSection

                #if DEBUG
                Divider()
                    .padding(.vertical, 8)

                mockDeviceSection
                #endif
            }
            .padding(.horizontal)
            .navigationTitle("Add Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                scanner.startScan()
            }
            .onDisappear {
                scanner.stopScan()
            }
            .onChange(of: pairingBridge.state) { _, newState in
                guard newState == .paired,
                      let stella = pairingTarget,
                      let provider = pairingBridge.manager?.pairedProvider
                else { return }
                deviceManager.addStellaDevice(name: stella.name, provider: provider)
                pairingBridge.detach()
                pairingTarget = nil
                isPresented = false
            }
        }
    }

    private var scanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nearby Device")
                    .font(.headline)
                Spacer()
                scanningIndicator
            }

            if let target = pairingTarget {
                pairingProgressCard(for: target)
            }

            if unpairedDevices.isEmpty && scanner.scanningState == .scanning && pairingTarget == nil {
                ContentUnavailableView(
                    "Scanning…",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("Looking for Stella wearables nearby.")
                )
                .frame(maxHeight: 220)
            } else {
                List {
                    ForEach(unpairedDevices) { stella in
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
        case .waitingForBluetooth:
            Label("Bluetooth Off", systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.orange)
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

    private var unpairedDevices: [DiscoveredStella] {
        let pairedIDs = Set(
            deviceManager.devices
                .compactMap { ($0.provider as? StellaDistanceProvider)?.peripheralIdentifier }
        )
        return scanner.discoveredDevices.filter {
            !pairedIDs.contains($0.peripheralIdentifier) &&
            $0.id != pairingTarget?.id
        }
    }

    private func startPairing(_ stella: DiscoveredStella) {
        pairingTarget = stella
        let pm = StellaPairingManager(centralManager: scanner.central)
        scanner.connectionDelegate = pm
        pairingBridge.attach(pm)
        pm.pair(stella: stella)
    }

    private func discoveredRow(_ stella: DiscoveredStella) -> some View {
        let bars = rssiBars(for: stella.rssi)
        let variableValue = Double(bars) / 3.0

        return Button {
            startPairing(stella)
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
        .disabled(pairingTarget != nil)
    }

    private func pairingProgressCard(for stella: DiscoveredStella) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stella.name)
                .font(.subheadline.weight(.semibold))

            Group {
                switch currentPairingState {
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

            if case .failed = currentPairingState {
                Button("Try Again") {
                    startPairing(stella)
                }
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
            .frame(maxWidth: .infinity)

            Divider()

            NavigationLink {
                UWBDiagnosticsView()
                    .navigationTitle("UWB Diagnostics")
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                Label("UWB Diagnostics", systemImage: "antenna.radiowaves.left.and.right")
            }
        }
        .padding(.bottom, 8)
    }
}
