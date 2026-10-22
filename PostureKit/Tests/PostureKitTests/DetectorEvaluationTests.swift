import Foundation
import Testing
@testable import PostureKit

/// Runs `PostureDetector` over every labeled fixture in `Resources` and
/// prints a markdown table of accuracy, false-nudge rate, and detection
/// delay — meant to be pasted into the README after tuning thresholds.
///
/// Ground truth: the `slouch` label is the positive class. `upright` and
/// `glance` (a dip too brief to count as a real slouch) are both negative,
/// since neither should produce a confirmed slouch or a nudge.
@Suite struct DetectorEvaluationTests {
    private static let fixtures = ["upright", "slouching", "glance-down"]

    private func resourceURL(_ name: String) -> URL {
        Bundle.module.url(forResource: name, withExtension: "csv", subdirectory: "Resources")!
    }

    private struct FixtureResult {
        let name: String
        let accuracyPercent: Double
        let falseNudgesPerHour: Double
        let averageDetectionDelay: TimeInterval?
    }

    @Test func printsDetectionAccuracyReport() throws {
        let results = try Self.fixtures.map { try evaluate(fixture: $0) }
        print(Self.markdownTable(for: results))
    }

    private func evaluate(fixture: String, config: DetectorConfig = DetectorConfig()) throws -> FixtureResult {
        let samples = try CSVParser().parse(resourceURL(fixture))
        var detector = PostureDetector(config: config)

        var correct = 0
        var compared = 0
        var totalNudges = 0
        var falseNudges = 0
        var detectionDelays: [TimeInterval] = []

        var episodeStart: TimeInterval?
        var episodeDetected = false
        var lastTimestamp: TimeInterval = 0

        for labeled in samples {
            let sample = labeled.sample
            let groundTruthIsSlouch = labeled.label == "slouch"

            if groundTruthIsSlouch {
                if episodeStart == nil {
                    episodeStart = sample.timestamp
                    episodeDetected = false
                }
            } else {
                episodeStart = nil
            }

            let events = detector.process(sample)
            for event in events {
                switch event {
                case .nudge:
                    totalNudges += 1
                    if !groundTruthIsSlouch { falseNudges += 1 }
                case .slouchStarted(let at):
                    if let start = episodeStart, !episodeDetected {
                        detectionDelays.append(at - start)
                        episodeDetected = true
                    }
                case .calibrated, .slouchEnded:
                    break
                }
            }

            // Accuracy is only meaningful once calibration has produced a baseline.
            if detector.state != .calibrating {
                compared += 1
                if (detector.state == .slouching) == groundTruthIsSlouch { correct += 1 }
            }

            lastTimestamp = sample.timestamp
        }

        let accuracy = compared > 0 ? Double(correct) / Double(compared) * 100 : 100
        let durationHours = lastTimestamp / 3600
        let falseNudgesPerHour = durationHours > 0 ? Double(falseNudges) / durationHours : 0
        let averageDelay = detectionDelays.isEmpty
            ? nil
            : detectionDelays.reduce(0, +) / Double(detectionDelays.count)

        return FixtureResult(
            name: fixture,
            accuracyPercent: accuracy,
            falseNudgesPerHour: falseNudgesPerHour,
            averageDetectionDelay: averageDelay
        )
    }

    private static func markdownTable(for results: [FixtureResult]) -> String {
        var lines = [
            "| Fixture | Accuracy | False nudges/hr | Avg detection delay |",
            "|---|---|---|---|",
        ]
        for result in results {
            let delay = result.averageDetectionDelay.map { String(format: "%.1fs", $0) } ?? "–"
            lines.append(
                "| \(result.name) | \(String(format: "%.1f%%", result.accuracyPercent)) | "
                    + "\(String(format: "%.2f", result.falseNudgesPerHour)) | \(delay) |"
            )
        }
        return lines.joined(separator: "\n")
    }
}
