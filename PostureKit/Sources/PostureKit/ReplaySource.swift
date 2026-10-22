import Foundation

/// Replays a fixed sequence of samples, honoring their original timing
/// scaled by `speedMultiplier` so tests don't have to wait in real time.
public actor ReplaySource: SensorSource {
    private let samples: [MotionSample]
    private let speedMultiplier: Double
    private var playbackTask: Task<Void, Never>?

    public init(samples: [MotionSample], speedMultiplier: Double = 1.0) {
        self.samples = samples
        self.speedMultiplier = speedMultiplier
    }

    public init(csvURL: URL, speedMultiplier: Double = 1.0) throws {
        let labeled = try CSVParser().parse(csvURL)
        self.samples = labeled.map(\.sample)
        self.speedMultiplier = speedMultiplier
    }

    public func start() async -> AsyncStream<MotionSample> {
        await stop()

        let samples = self.samples
        let speedMultiplier = self.speedMultiplier
        let (stream, continuation) = AsyncStream.makeStream(of: MotionSample.self)

        let task = Task {
            var previousTimestamp: TimeInterval?
            for sample in samples {
                if Task.isCancelled { break }
                if let previousTimestamp, speedMultiplier > 0 {
                    let delta = sample.timestamp - previousTimestamp
                    if delta > 0 {
                        let nanoseconds = (delta / speedMultiplier) * 1_000_000_000
                        try? await Task.sleep(nanoseconds: UInt64(nanoseconds))
                    }
                }
                if Task.isCancelled { break }
                previousTimestamp = sample.timestamp
                continuation.yield(sample)
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }

        playbackTask = task
        return stream
    }

    public func stop() async {
        playbackTask?.cancel()
        playbackTask = nil
    }
}
