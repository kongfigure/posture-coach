import Foundation
import Testing
@testable import PostureKit

@Suite struct MotionSampleTests {
    @Test func jsonRoundTripPreservesAllFields() throws {
        let sample = MotionSample(
            timestamp: 12.5,
            pitch: 0.12,
            roll: -0.34,
            yaw: 1.5,
            accelerometerX: 0.01,
            accelerometerY: -0.02,
            accelerometerZ: 0.98,
            gyroX: 0.1,
            gyroY: 0.2,
            gyroZ: 0.3
        )

        let data = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(MotionSample.self, from: data)

        #expect(decoded == sample)
    }
}
