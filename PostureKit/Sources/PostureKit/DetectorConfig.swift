import Foundation

/// Tunable thresholds for `PostureDetector`. Defaults are a starting point —
/// see `PostureKit/Tests/PostureKitTests/Resources` for the fixtures they're
/// checked against.
public struct DetectorConfig: Sendable, Equatable {
    /// How long to average pitch at startup to establish the upright baseline.
    public var calibrationDuration: TimeInterval
    /// Degrees of pitch deviation from baseline that counts as slouching.
    public var slouchThresholdDegrees: Double
    /// How long the deviation must persist before it's treated as a real
    /// slouch rather than a brief glance down.
    public var minimumSlouchDuration: TimeInterval
    /// Minimum time between nudges, so a sustained slouch doesn't spam the user.
    public var nudgeCooldown: TimeInterval

    public init(
        calibrationDuration: TimeInterval = 10,
        slouchThresholdDegrees: Double = 15,
        minimumSlouchDuration: TimeInterval = 3,
        nudgeCooldown: TimeInterval = 180
    ) {
        self.calibrationDuration = calibrationDuration
        self.slouchThresholdDegrees = slouchThresholdDegrees
        self.minimumSlouchDuration = minimumSlouchDuration
        self.nudgeCooldown = nudgeCooldown
    }
}
