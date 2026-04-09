import Foundation
import Combine
import simd

@MainActor
class MockDistanceProvider: DistanceProvider {
    private let distanceSubject = PassthroughSubject<DistanceReading, Never>()
    private let connectionStatusSubject = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)
    private let batteryLevelSubject = CurrentValueSubject<Double?, Never>(nil)
    private(set) var playSoundCallCount = 0

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.connectionStatusSubject.send(.connected)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.connectionStatusSubject.send(.ranging)
        }
    }

    func stop() {
        connectionStatusSubject.send(.disconnected)
    }

    func playSound() {
        playSoundCallCount += 1
    }

    func setDistance(_ meters: Double, direction: simd_float3? = nil) {
        distanceSubject.send(DistanceReading(
            distance: meters,
            direction: direction,
            timestamp: Date(),
            isValid: true
        ))
    }

    func setBatteryLevel(_ level: Double) {
        batteryLevelSubject.send(level)
    }

    func simulateDisconnect() {
        distanceSubject.send(DistanceReading(distance: 0, direction: nil, timestamp: Date(), isValid: false))
        connectionStatusSubject.send(.disconnected)
    }
}
