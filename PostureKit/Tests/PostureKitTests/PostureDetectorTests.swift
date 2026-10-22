import Foundation
import Testing
@testable import PostureKit

@Suite struct PostureDetectorTests {
    private func resourceURL(_ name: String) -> URL {
        Bundle.module.url(forResource: name, withExtension: "csv", subdirectory: "Resources")!
    }

    /// Replays a fixture at high speed and feeds every sample through a
    /// fresh detector, collecting all emitted events in order.
    private func run(
        fixture: String,
        config: DetectorConfig = DetectorConfig()
    ) async throws -> (events: [PostureEvent], finalState: PostureState) {
        let source = try ReplaySource(csvURL: resourceURL(fixture), speedMultiplier: 10_000)
        let stream = await source.start()
        var detector = PostureDetector(config: config)

        var events: [PostureEvent] = []
        for await sample in stream {
            events.append(contentsOf: detector.process(sample))
        }
        return (events, detector.state)
    }

    @Test func uprightFixtureOnlyCalibratesAndStaysUpright() async throws {
        let result = try await run(fixture: "upright")

        #expect(result.events == [.calibrated(baselinePitchDegrees: 0)])
        #expect(result.finalState == .upright)
    }

    @Test func slouchingFixtureConfirmsSlouchAndNudgesAfterDebounce() async throws {
        let result = try await run(fixture: "slouching")

        // Slouch begins at t=10.5 but isn't confirmed until the 3s debounce
        // (minimumSlouchDuration) elapses at t=13.5. The first nudge fires
        // at the same moment since there's no prior nudge to cool down from.
        #expect(result.events == [
            .calibrated(baselinePitchDegrees: 0),
            .slouchStarted(at: 13.5),
            .nudge(at: 13.5),
        ])
        #expect(result.finalState == .slouching)
    }

    @Test func glanceDownFixtureNeverConfirmsSlouch() async throws {
        let result = try await run(fixture: "glance-down")

        // The dip only lasts 0.5s, short of the 3s debounce, so it never
        // becomes a confirmed slouch and never nudges.
        #expect(result.events == [.calibrated(baselinePitchDegrees: 0)])
        #expect(result.finalState == .upright)
    }

    @Test func nudgeCooldownThrottlesRepeatsButAllowsLaterOnes() async throws {
        var config = DetectorConfig()
        config.calibrationDuration = 1
        config.minimumSlouchDuration = 1
        config.nudgeCooldown = 2

        var detector = PostureDetector(config: config)
        var events: [PostureEvent] = []

        func feed(_ timestamp: TimeInterval, pitch: Double) {
            let sample = MotionSample(
                timestamp: timestamp, pitch: pitch, roll: 0, yaw: 0,
                accelerometerX: 0, accelerometerY: 0, accelerometerZ: 1,
                gyroX: 0, gyroY: 0, gyroZ: 0
            )
            events.append(contentsOf: detector.process(sample))
        }

        feed(0, pitch: 0)
        feed(1, pitch: 0) // calibrates here, baseline 0

        // Slouch continuously from t=1.5 to t=5.5 (well past two cooldown windows).
        var t: TimeInterval = 1.5
        while t <= 5.5 {
            feed(t, pitch: -0.5) // ~-28.6 degrees, past the 15 degree default threshold
            t += 0.5
        }

        let nudgeTimestamps = events.compactMap { event -> TimeInterval? in
            if case .nudge(let at) = event { return at }
            return nil
        }

        // Confirmed slouch (and first nudge) at t=2.5 (1.5 + minimumSlouchDuration).
        // Next nudge once the 2s cooldown clears, at t=4.5.
        #expect(nudgeTimestamps == [2.5, 4.5])
    }
}
