import Foundation
import Testing
@testable import PostureKit

@Suite struct ReplaySourceTests {
    @Test func playsBackAllSamplesInOrder() async throws {
        let samples = [
            MotionSample(timestamp: 0.0, pitch: 0, roll: 0, yaw: 0, accelerometerX: 0, accelerometerY: 0, accelerometerZ: 1, gyroX: 0, gyroY: 0, gyroZ: 0),
            MotionSample(timestamp: 0.05, pitch: 1, roll: 0, yaw: 0, accelerometerX: 0, accelerometerY: 0, accelerometerZ: 1, gyroX: 0, gyroY: 0, gyroZ: 0),
            MotionSample(timestamp: 0.10, pitch: 2, roll: 0, yaw: 0, accelerometerX: 0, accelerometerY: 0, accelerometerZ: 1, gyroX: 0, gyroY: 0, gyroZ: 0),
        ]
        // High speed multiplier keeps the test fast despite real inter-sample gaps.
        let source = ReplaySource(samples: samples, speedMultiplier: 1000)
        let stream = await source.start()

        var received: [MotionSample] = []
        for await sample in stream {
            received.append(sample)
        }

        #expect(received == samples)
    }

    @Test func stopEndsTheStreamWithoutPlayingLaterSamples() async {
        let samples = [
            MotionSample(timestamp: 0, pitch: 0, roll: 0, yaw: 0, accelerometerX: 0, accelerometerY: 0, accelerometerZ: 1, gyroX: 0, gyroY: 0, gyroZ: 0),
            // Large gap: cancellation always wins the race against this sleep.
            MotionSample(timestamp: 3600, pitch: 1, roll: 0, yaw: 0, accelerometerX: 0, accelerometerY: 0, accelerometerZ: 1, gyroX: 0, gyroY: 0, gyroZ: 0),
        ]
        let source = ReplaySource(samples: samples, speedMultiplier: 1)
        let stream = await source.start()
        var iterator = stream.makeAsyncIterator()

        let first = await iterator.next()
        await source.stop()
        let next = await iterator.next()

        #expect(first == samples[0])
        #expect(next == nil)
    }

    @Test func loadsSamplesFromCSVIgnoringLabels() async throws {
        let labeled = [
            LabeledMotionSample(
                sample: MotionSample(timestamp: 0, pitch: 0.1, roll: 0, yaw: 0, accelerometerX: 0, accelerometerY: 0, accelerometerZ: 1, gyroX: 0, gyroY: 0, gyroZ: 0),
                label: "good"
            ),
            LabeledMotionSample(
                sample: MotionSample(timestamp: 0.02, pitch: 0.9, roll: 0, yaw: 0, accelerometerX: 0, accelerometerY: 0, accelerometerZ: 1, gyroX: 0, gyroY: 0, gyroZ: 0),
                label: "slouch"
            ),
        ]
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("csv")
        defer { try? FileManager.default.removeItem(at: url) }
        try CSVRecorder().write(labeled, to: url)

        let source = try ReplaySource(csvURL: url, speedMultiplier: 1000)
        let stream = await source.start()

        var received: [MotionSample] = []
        for await sample in stream {
            received.append(sample)
        }

        #expect(received == labeled.map(\.sample))
    }
}
