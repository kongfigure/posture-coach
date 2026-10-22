import Foundation

/// The result of a finished session, as computed by `SessionViewModel`.
///
/// Kept separate from the SwiftData `Session` model so the view model has no
/// dependency on SwiftData — `SessionView` is the one that turns this into a
/// persisted `Session` when it sees one arrive.
struct SessionSummary: Equatable, Sendable {
    let startDate: Date
    let duration: TimeInterval
    let percentUpright: Double
    let slouchCount: Int
    let nudgeCount: Int
}
