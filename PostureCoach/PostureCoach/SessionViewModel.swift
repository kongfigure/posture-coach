import Observation
import PostureKit
import UIKit

/// Drives a posture-monitoring session: pulls samples from an injected
/// `SensorSource`, feeds them through `PostureDetector`, and exposes
/// display-ready state for `SessionView`.
///
/// All displayed timing (calibration countdown, session timer) is derived
/// from the samples' own timestamps rather than a wall-clock `Timer`, so the
/// same code path works unchanged whether driven by live hardware or a
/// `ReplaySource` played back at any speed.
@MainActor
@Observable
final class SessionViewModel {
    let config: DetectorConfig

    private(set) var isRunning = false
    private(set) var postureState: PostureState = .calibrating
    private(set) var calibrationSecondsRemaining: Int
    private(set) var sessionElapsed: TimeInterval = 0
    private(set) var lastNudgeAt: Date?
    /// Set once when a session ends; `SessionView` observes this to persist a `Session`.
    private(set) var finishedSession: SessionSummary?

    private let sensorSource: any SensorSource
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    private var detector: PostureDetector
    private var streamTask: Task<Void, Never>?

    private var calibrationStartTimestamp: TimeInterval?
    private var sessionStartTimestamp: TimeInterval?
    private var sessionStartDate: Date?
    private var lastSampleTimestamp: TimeInterval?
    private var uprightDuration: TimeInterval = 0
    private var slouchingDuration: TimeInterval = 0
    private var slouchCount = 0
    private var nudgeCount = 0

    init(sensorSource: any SensorSource, config: DetectorConfig = DetectorConfig()) {
        self.sensorSource = sensorSource
        self.config = config
        self.detector = PostureDetector(config: config)
        self.calibrationSecondsRemaining = Int(config.calibrationDuration.rounded(.up))
    }

    func start() {
        guard !isRunning else { return }
        resetTrackingState()
        isRunning = true
        postureState = .calibrating
        calibrationSecondsRemaining = Int(config.calibrationDuration.rounded(.up))
        sessionElapsed = 0
        sessionStartDate = Date()
        detector = PostureDetector(config: config)
        feedbackGenerator.prepare()

        streamTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let stream = await self.sensorSource.start()
            for await sample in stream {
                self.handle(sample)
            }
            self.finishSession()
        }
    }

    func stop() {
        guard isRunning else { return }
        streamTask?.cancel()
        streamTask = nil
        Task { await sensorSource.stop() }
        finishSession()
    }

    private func handle(_ sample: MotionSample) {
        if sessionStartTimestamp == nil {
            sessionStartTimestamp = sample.timestamp
        }
        sessionElapsed = sample.timestamp - sessionStartTimestamp!

        if postureState == .calibrating {
            if calibrationStartTimestamp == nil {
                calibrationStartTimestamp = sample.timestamp
            }
            let remaining = config.calibrationDuration - (sample.timestamp - calibrationStartTimestamp!)
            calibrationSecondsRemaining = max(0, Int(remaining.rounded(.up)))
        } else if let lastSampleTimestamp {
            // Attribute the time since the last sample to whichever posture
            // state was active during that interval (calibration excluded).
            let delta = sample.timestamp - lastSampleTimestamp
            if delta > 0 {
                switch postureState {
                case .upright: uprightDuration += delta
                case .slouching: slouchingDuration += delta
                case .calibrating: break
                }
            }
        }
        lastSampleTimestamp = sample.timestamp

        let events = detector.process(sample)
        postureState = detector.state

        for event in events {
            switch event {
            case .slouchStarted:
                slouchCount += 1
            case .nudge:
                nudgeCount += 1
                lastNudgeAt = Date()
                feedbackGenerator.notificationOccurred(.warning)
            case .calibrated, .slouchEnded:
                break
            }
        }
    }

    /// Finalizes and records the current session. Safe to call more than
    /// once (e.g. both from an explicit `stop()` and from the playback
    /// stream finishing on its own) — only the first call does anything.
    private func finishSession() {
        guard isRunning else { return }
        isRunning = false
        defer { resetTrackingState() }

        let trackedDuration = uprightDuration + slouchingDuration
        guard trackedDuration > 0, let sessionStartDate else { return }

        finishedSession = SessionSummary(
            startDate: sessionStartDate,
            duration: sessionElapsed,
            percentUpright: (uprightDuration / trackedDuration) * 100,
            slouchCount: slouchCount,
            nudgeCount: nudgeCount
        )
    }

    private func resetTrackingState() {
        calibrationStartTimestamp = nil
        sessionStartTimestamp = nil
        sessionStartDate = nil
        lastSampleTimestamp = nil
        uprightDuration = 0
        slouchingDuration = 0
        slouchCount = 0
        nudgeCount = 0
    }
}
