import Foundation

/// A single head-motion reading, independent of which sensor produced it.
///
/// `pitch`/`roll`/`yaw` are in radians, matching `CMAttitude`'s native units,
/// so the CoreMotion source can pass them through unconverted.
public struct MotionSample: Codable, Sendable, Equatable {
    public let timestamp: TimeInterval
    public let pitch: Double
    public let roll: Double
    public let yaw: Double
    public let accelerometerX: Double
    public let accelerometerY: Double
    public let accelerometerZ: Double
    public let gyroX: Double
    public let gyroY: Double
    public let gyroZ: Double

    public init(
        timestamp: TimeInterval,
        pitch: Double,
        roll: Double,
        yaw: Double,
        accelerometerX: Double,
        accelerometerY: Double,
        accelerometerZ: Double,
        gyroX: Double,
        gyroY: Double,
        gyroZ: Double
    ) {
        self.timestamp = timestamp
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
        self.accelerometerX = accelerometerX
        self.accelerometerY = accelerometerY
        self.accelerometerZ = accelerometerZ
        self.gyroX = gyroX
        self.gyroY = gyroY
        self.gyroZ = gyroZ
    }
}
