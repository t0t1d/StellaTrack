import SwiftUI
import CoreLocation

struct StellaScanOverlay: View {
    @ObservedObject var deviceManager: DeviceManager
    @ObservedObject var locationManager: LocationManager
    let onDismiss: () -> Void
    let onShowDiagnostics: () -> Void
    let onAddMock: () -> Void

    @StateObject private var scanner = StellaScanner()
    @StateObject private var pairingManager = StellaPairingManager()
    @State private var pairingTarget: DiscoveredStella?

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
        .onChange(of: pairingManager.pairingState) { _, newState in
            guard newState == .paired, let stella = pairingTarget else { return }
            deviceManager.addStellaDevice(name: stella.name)
            pairingManager.reset()
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
        case .idle, .stopped:
            Text("Ready")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Device list

    private var deviceList: some View {
        LazyVStack(spacing: 0) {
            if scanner.discoveredDevices.isEmpty && scanner.scanningState == .scanning && pairingTarget == nil {
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

            ForEach(scanner.discoveredDevices) { stella in
                stellaRow(stella)
            }

            mockDeviceRow
        }
    }

    private func stellaRow(_ stella: DiscoveredStella) -> some View {
        let bars = rssiBars(for: stella.rssi)
        let variableValue = Double(bars) / 3.0

        return Button {
            pairingTarget = stella
            pairingManager.reset()
            pairingManager.pair(stella: stella)
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

    // MARK: - Pairing card

    private func pairingCard(for stella: DiscoveredStella) -> some View {
        HStack(spacing: 10) {
            Group {
                switch pairingManager.pairingState {
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

            if case .failed = pairingManager.pairingState {
                Button("Retry") {
                    pairingManager.reset()
                    pairingManager.pair(stella: stella)
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
        switch pairingManager.pairingState {
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
