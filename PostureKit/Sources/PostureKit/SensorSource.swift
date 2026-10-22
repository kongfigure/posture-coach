import Foundation

/// A source of head-motion data, whether live hardware or recorded playback.
public protocol SensorSource: Sendable {
    /// Starts streaming samples. Calling this again restarts the stream.
    func start() async -> AsyncStream<MotionSample>

    /// Stops streaming and finishes any in-flight stream.
    func stop() async
}
