import Foundation
import Combine

@MainActor
protocol DistanceProvider: AnyObject {
    var distancePublisher: AnyPublisher<DistanceReading, Never> { get }
    var connectionStatusPublisher: AnyPublisher<ConnectionStatus, Never> { get }
    var batteryLevelPublisher: AnyPublisher<Double?, Never> { get }
    var currentConnectionStatus: ConnectionStatus { get }
    func start()
    func stop()
    func playSound()
    func stopSound()
}

extension DistanceProvider {
    func stopSound() {}
}
