import Foundation
import Combine

enum PairingState: Equatable {
    case idle
    case connecting
    case configuringUWB
    case paired
    case failed(String)

    static func == (lhs: PairingState, rhs: PairingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.connecting, .connecting),
             (.configuringUWB, .configuringUWB), (.paired, .paired):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

@MainActor
class StellaPairingManager: ObservableObject {
    @Published private(set) var pairingState: PairingState = .idle

    func pair(stella: DiscoveredStella) {
        pairingState = .connecting

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.pairingState = .configuringUWB

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self else { return }
                self.pairingState = .paired
            }
        }
    }

    func reset() {
        pairingState = .idle
    }
}
