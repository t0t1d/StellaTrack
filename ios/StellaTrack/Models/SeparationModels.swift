import Foundation
import simd

struct DistanceReading: Equatable, Sendable {
    let distance: Double
    let direction: simd_float3?
    let timestamp: Date
    let isValid: Bool
}

enum ConnectionStatus: Equatable, Sendable {
    case disconnected
    case searching
    case connected
    case ranging
}
