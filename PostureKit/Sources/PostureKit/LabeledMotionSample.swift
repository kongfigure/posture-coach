import Foundation

/// A sample tagged with a ground-truth posture label, for recording and
/// replaying test fixtures (e.g. "good", "slouch").
public struct LabeledMotionSample: Codable, Sendable, Equatable {
    public let sample: MotionSample
    public let label: String

    public init(sample: MotionSample, label: String) {
        self.sample = sample
        self.label = label
    }
}
