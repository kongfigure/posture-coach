import CoreMotion
import PostureKit

/// Streams head-motion samples from AirPods via `CMHeadphoneMotionManager`.
///
/// `CMHeadphoneMotionManager` only exposes fused `CMDeviceMotion`, not raw
/// accelerometer/gyro data, so `userAcceleration` and `rotationRate` are the
/// closest available stand-ins for `MotionSample`'s accelerometer/gyro fields.
final class HeadphoneMotionSource: NSObject, SensorSource, @unchecked Sendable {
    private let manager = CMHeadphoneMotionManager()
    private let updateQueue = OperationQueue()
    private let lock = NSLock()
    private var _continuation: AsyncStream<MotionSample>.Continuation?

    private var continuation: AsyncStream<MotionSample>.Continuation? {
        get { lock.withLock { _continuation } }
        set { lock.withLock { _continuation = newValue } }
    }

    override init() {
        super.init()
        manager.delegate = self
    }

    func start() async -> AsyncStream<MotionSample> {
        await stop()

        let (stream, continuation) = AsyncStream.makeStream(of: MotionSample.self)
        self.continuation = continuation

        guard manager.isDeviceMotionAvailable else {
            continuation.finish()
            return stream
        }

        beginUpdates()
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

    private func beginUpdates() {
        manager.startDeviceMotionUpdates(to: updateQueue) { [weak self] motion, error in
            guard let motion, error == nil else { return }
            self?.continuation?.yield(Self.sample(from: motion))
        }
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

extension HeadphoneMotionSource: CMHeadphoneMotionManagerDelegate {
    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        // If start() already ran, it was waiting on these headphones to show
        // up — resume delivering updates now that they're connected.
        guard continuation != nil, manager.isDeviceMotionAvailable else { return }
        beginUpdates()
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        continuation?.finish()
        continuation = nil
    }
}
