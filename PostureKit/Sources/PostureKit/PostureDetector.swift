import Foundation

/// Consumes `MotionSample`s one at a time and derives posture state.
///
/// All timing (calibration window, slouch debounce, nudge cooldown) is
/// measured against each sample's own `timestamp`, not wall-clock time, so
/// detection is deterministic regardless of how fast samples are delivered
/// (e.g. by `ReplaySource` at a high speed multiplier).
public struct PostureDetector: Sendable {
    public let config: DetectorConfig
    public private(set) var state: PostureState = .calibrating

    private var calibrationStartTimestamp: TimeInterval?
    private var pitchDegreesSum: Double = 0
    private var calibrationSampleCount: Int = 0
    private var baselinePitchDegrees: Double?

    private var slouchStartTimestamp: TimeInterval?
    private var isSlouchConfirmed = false
    private var lastNudgeTimestamp: TimeInterval?

    public init(config: DetectorConfig = DetectorConfig()) {
        self.config = config
    }

    @discardableResult
    public mutating func process(_ sample: MotionSample) -> [PostureEvent] {
        switch state {
        case .calibrating:
            return processCalibrating(sample)
        case .upright, .slouching:
            return processTracking(sample)
        }
    }

    private mutating func processCalibrating(_ sample: MotionSample) -> [PostureEvent] {
        if calibrationStartTimestamp == nil {
            calibrationStartTimestamp = sample.timestamp
        }
        pitchDegreesSum += Self.degrees(from: sample.pitch)
        calibrationSampleCount += 1

        let elapsed = sample.timestamp - calibrationStartTimestamp!
        guard elapsed >= config.calibrationDuration else { return [] }

        let baseline = pitchDegreesSum / Double(calibrationSampleCount)
        baselinePitchDegrees = baseline
        state = .upright
        return [.calibrated(baselinePitchDegrees: baseline)]
    }

    private mutating func processTracking(_ sample: MotionSample) -> [PostureEvent] {
        var events: [PostureEvent] = []
        let deviation = abs(Self.degrees(from: sample.pitch) - baselinePitchDegrees!)

        if deviation > config.slouchThresholdDegrees {
            if slouchStartTimestamp == nil {
                slouchStartTimestamp = sample.timestamp
            }
            if !isSlouchConfirmed, sample.timestamp - slouchStartTimestamp! >= config.minimumSlouchDuration {
                isSlouchConfirmed = true
                state = .slouching
                events.append(.slouchStarted(at: sample.timestamp))
            }
        } else {
            slouchStartTimestamp = nil
            if isSlouchConfirmed {
                isSlouchConfirmed = false
                state = .upright
                events.append(.slouchEnded(at: sample.timestamp))
            }
        }

        if isSlouchConfirmed,
           lastNudgeTimestamp == nil || sample.timestamp - lastNudgeTimestamp! >= config.nudgeCooldown {
            lastNudgeTimestamp = sample.timestamp
            events.append(.nudge(at: sample.timestamp))
        }

        return events
    }

    private static func degrees(from radians: Double) -> Double {
        radians * 180 / .pi
    }
}
