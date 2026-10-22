import Foundation

/// Something `PostureDetector` wants the app to react to.
public enum PostureEvent: Sendable, Equatable {
    case calibrated(baselinePitchDegrees: Double)
    case slouchStarted(at: TimeInterval)
    case slouchEnded(at: TimeInterval)
    case nudge(at: TimeInterval)
}
