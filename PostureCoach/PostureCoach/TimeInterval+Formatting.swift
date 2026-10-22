import Foundation

extension TimeInterval {
    /// Formats as "MM:SS", used by both the live session timer and the history list.
    var formattedAsMinutesSeconds: String {
        let totalSeconds = Int(self)
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
