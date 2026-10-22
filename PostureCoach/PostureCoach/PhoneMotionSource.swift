import CoreMotion
import PostureKit

/// Streams head-motion samples from the iPhone's own IMU via
/// `CMMotionManager`, for use when no headphone motion source is available.
///
/// Uses the same fused `CMDeviceMotion` fields as `HeadphoneMotionSource`
/// (`userAcceleration`/`rotationRate`) so both sources produce comparable
/// `MotionSample`s.
final class PhoneMotionSource: SensorSource, @unchecked Sendable {
    private let manager = CMMotionManager()
    private let updateQueue = OperationQueue()
    private let lock = NSLock()
    private var _continuation: AsyncStream<MotionSample>.Continuation?

    private var continuation: AsyncStream<MotionSample>.Continuation? {
        get { lock.withLock { _continuation } }
        set { lock.withLock { _continuation = newValue } }
    }

    func start() async -> AsyncStream<MotionSample> {
        await stop()

        let (stream, continuation) = AsyncStream.makeStream(of: MotionSample.self)
        self.continuation = continuation

        guard manager.isDeviceMotionAvailable else {
            continuation.finish()
            return stream
        }

        manager.startDeviceMotionUpdates(to: updateQueue) { [weak self] motion, error in
            guard let motion, error == nil else { return }
            self?.continuation?.yield(Self.sample(from: motion))
        }
        continuation.onTermination = { [manager] _ in
            manager.stopDeviceMotionUpdates()
        }

        return stream
    }

    func stop() async {
        manager.stopDeviceMotionUpdates()
        continuation?.finish()
        continuation = nil
    }

    private static func sample(from motion: CMDeviceMotion) -> MotionSample {
        MotionSample(
            timestamp: motion.timestamp,
            pitch: motion.attitude.pitch,
            roll: motion.attitude.roll,
            yaw: motion.attitude.yaw,
            accelerometerX: motion.userAcceleration.x,
            accelerometerY: motion.userAcceleration.y,
            accelerometerZ: motion.userAcceleration.z,
            gyroX: motion.rotationRate.x,
            gyroY: motion.rotationRate.y,
            gyroZ: motion.rotationRate.z
        )
    }
}
