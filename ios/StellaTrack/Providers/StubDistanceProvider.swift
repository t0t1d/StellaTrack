import Foundation
import Combine

/// Placeholder provider for real (non-mock) devices that aren't yet connected.
/// Stays in `.disconnected` state until a real BLE/UWB session replaces it.
@MainActor
class StubDistanceProvider: DistanceProvider {
    private let distanceSubject = PassthroughSubject<DistanceReading, Never>()
    private let connectionStatusSubject = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)
    private let batteryLevelSubject = CurrentValueSubject<Double?, Never>(nil)

    var distancePublisher: AnyPublisher<DistanceReading, Never> {
        distanceSubject.eraseToAnyPublisher()
    }

    var connectionStatusPublisher: AnyPublisher<ConnectionStatus, Never> {
        connectionStatusSubject.eraseToAnyPublisher()
    }

    var batteryLevelPublisher: AnyPublisher<Double?, Never> {
        batteryLevelSubject.eraseToAnyPublisher()
    }

    var currentConnectionStatus: ConnectionStatus {
        connectionStatusSubject.value
    }

    func start() {
        connectionStatusSubject.send(.searching)
    }

    func stop() {
        connectionStatusSubject.send(.disconnected)
    }

    func playSound() {}
}
