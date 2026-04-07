import Foundation
import CoreMotion
import Combine

@MainActor
final class MotionManager: ObservableObject {
    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    @Published var isFlat: Bool = true

    private let motionManager = CMMotionManager()
    private let motionQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.separationawareness.motion"
        q.maxConcurrentOperationCount = 1
        return q
    }()

    private static let flatThreshold: Double = 0.3

    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, _ in
            guard let attitude = motion?.attitude else { return }
            let pitch = attitude.pitch
            let roll = attitude.roll
            let flat =
                abs(pitch) < Self.flatThreshold && abs(roll) < Self.flatThreshold
            Task { @MainActor [weak self] in
                self?.pitch = pitch
                self?.roll = roll
                self?.isFlat = flat
            }
        }
    }

    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
    }
}
