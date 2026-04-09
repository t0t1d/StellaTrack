import SwiftUI
import Combine
import CoreLocation
private var uiLog: BLEDebugLog { BLEDebugLog.shared }

struct StellaScanOverlay: View {
    @ObservedObject var deviceManager: DeviceManager
    @ObservedObject var locationManager: LocationManager
    let onDismiss: () -> Void
    let onShowDiagnostics: () -> Void
    let onAddMock: () -> Void

    @StateObject private var scanner = StellaScanner()
    @StateObject private var pairingBridge = PairingBridge()
    @State private var pairingTarget: DiscoveredStella?

    private var pairingManager: StellaPairingManager? { pairingBridge.manager }
    private var currentPairingState: PairingState { pairingBridge.state }

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            GlassEffectContainer {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 12)

                    if let target = pairingTarget {
                        pairingCard(for: target)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 10)
                    }

                    deviceList
                        .padding(.bottom, 6)
                }
                .frame(maxWidth: 370)
                .glassEffect(.regular.interactive().tint(.gray.opacity(0.12)), in: .rect(cornerRadius: 22))
            }
            .frame(maxWidth: 370)
            .contentShape(Rectangle())
            .onTapGesture { }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .offset(y: 30)
        }
        .environment(\.colorScheme, .dark)
        .onAppear { scanner.startScan() }
        .onDisappear { scanner.stopScan() }
        .onChange(of: pairingBridge.state) { _, newState in
            guard newState == .paired,
                  let stella = pairingTarget,
                  let provider = pairingBridge.manager?.pairedProvider
            else { return }
            deviceManager.addStellaDevice(name: stella.name, provider: provider)
            pairingBridge.detach()
            pairingTarget = nil
            onDismiss()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Nearby Device")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                scanStateLabel
            }

            Spacer()

            Button {
                onShowDiagnostics()
            } label: {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(9)
                    .glassEffect(.regular.interactive().tint(.gray.opacity(0.25)), in: .circle)
            }
            .buttonStyle(.plain)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(9)
                    .glassEffect(.regular.interactive().tint(.gray.opacity(0.25)), in: .circle)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var scanStateLabel: some View {
        switch scanner.scanningState {
        case .scanning:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.55)
                    .tint(.white.opacity(0.6))
                Text("Scanning…")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        case .waitingForBluetooth:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("Bluetooth Off")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        case .idle, .stopped:
            Text("Ready")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Device list

    private var deviceList: some View {
        LazyVStack(spacing: 0) {
            if unpairedDevices.isEmpty && scanner.scanningState == .scanning && pairingTarget == nil {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.35))
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                    Text("Looking for devices…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            }

            ForEach(unpairedDevices) { stella in
                stellaRow(stella)
            }

            mockDeviceRow
        }
    }

    private func stellaRow(_ stella: DiscoveredStella) -> some View {
        let bars = rssiBars(for: stella.rssi)
        let variableValue = Double(bars) / 3.0

        return Button {
            startPairing(stella)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wifi", variableValue: variableValue)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 24)

                Text(stella.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                if pairingTarget?.id == stella.id {
                    ProgressView()
                        .scaleEffect(0.65)
                        .tint(.white.opacity(0.6))
                } else {
                    Text("\(stella.rssi) dBm")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(pairingTarget != nil)
    }

    private var mockDeviceRow: some View {
        Button {
            onAddMock()
            onDismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.viewfinder")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 24)

                Text("Mock Device")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    // MARK: - Pairing

    private func startPairing(_ stella: DiscoveredStella) {
        pairingTarget = stella
        let pm = StellaPairingManager(centralManager: scanner.central)
        scanner.connectionDelegate = pm
        pairingBridge.attach(pm)
        uiLog.log("startPairing — central=\(String(describing: type(of: scanner.central))), delegate set=\(scanner.connectionDelegate != nil)")
        pm.pair(stella: stella)
    }

    // MARK: - Pairing card

    private func pairingCard(for stella: DiscoveredStella) -> some View {
        HStack(spacing: 10) {
            Group {
                switch currentPairingState {
                case .idle:
                    Image(systemName: "link").foregroundStyle(.white.opacity(0.6))
                case .connecting, .configuringUWB:
                    ProgressView().scaleEffect(0.65).tint(.white)
                case .paired:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                case .failed:
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(stella.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                pairingStateText
            }

            Spacer()

            if case .failed = currentPairingState {
                Button("Retry") {
                    startPairing(stella)
                }
                .font(.caption.bold())
                .foregroundStyle(.blue)
            }
        }
        .padding(10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var pairingStateText: some View {
        switch currentPairingState {
        case .idle:
            Text("Ready").font(.caption).foregroundStyle(.white.opacity(0.4))
        case .connecting:
            Text("Connecting…").font(.caption).foregroundStyle(.white.opacity(0.4))
        case .configuringUWB:
            Text("Configuring UWB…").font(.caption).foregroundStyle(.white.opacity(0.4))
        case .paired:
            Text("Paired").font(.caption).foregroundStyle(.green)
        case .failed(let msg):
            Text(msg).font(.caption).foregroundStyle(.red)
        }
    }

    private func rssiBars(for rssi: Int) -> Int {
        if rssi > -50 { return 3 }
        if rssi > -65 { return 2 }
        return 1
    }
}

// MARK: - PairingBridge

@MainActor
final class PairingBridge: ObservableObject {
    @Published private(set) var state: PairingState = .idle
    private(set) var manager: StellaPairingManager?
    private var cancellable: AnyCancellable?

    func attach(_ pm: StellaPairingManager) {
        manager?.reset()
        manager = pm
        state = pm.pairingState
        cancellable = pm.$pairingState
            .receive(on: RunLoop.main)
            .sink { [weak self] newState in
                self?.state = newState
            }
    }

    func detach() {
        manager?.reset()
        manager = nil
        cancellable = nil
        state = .idle
    }
}
