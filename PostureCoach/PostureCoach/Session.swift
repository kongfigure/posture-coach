import Foundation
import SwiftData

/// A completed posture-monitoring session, persisted for the history screen.
@Model
final class Session {
    var startTime: Date
    var duration: TimeInterval
    var percentUpright: Double
    var slouchCount: Int
    var nudgeCount: Int

    init(
        startTime: Date,
        duration: TimeInterval,
        percentUpright: Double,
        slouchCount: Int,
        nudgeCount: Int
    ) {
        self.startTime = startTime
        self.duration = duration
        self.percentUpright = percentUpright
        self.slouchCount = slouchCount
        self.nudgeCount = nudgeCount
    }
}
