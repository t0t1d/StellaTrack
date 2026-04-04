import Foundation
import Combine

enum ScanningState: Equatable {
    case idle
    case scanning
    case stopped
}

@MainActor
class StellaScanner: ObservableObject {
    @Published private(set) var discoveredDevices: [DiscoveredStella] = []
    @Published private(set) var scanningState: ScanningState = .idle

    func startScan() {
        guard scanningState != .scanning else { return }
        discoveredDevices = []
        scanningState = .scanning

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, self.scanningState == .scanning else { return }
            let fakeStella = DiscoveredStella(
                id: UUID(),
                name: "StellaWearable-\(String(format: "%04X", Int.random(in: 0...0xFFFF)))",
                rssi: Int.random(in: -70 ... -40),
                peripheralIdentifier: UUID()
            )
            self.discoveredDevices.append(fakeStella)
        }
    }

    func stopScan() {
        scanningState = .stopped
    }
}
