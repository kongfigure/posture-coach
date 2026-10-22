import Foundation
import Testing
@testable import PostureKit

@Suite struct CSVRoundTripTests {
    private func makeSamples() -> [LabeledMotionSample] {
        [
            LabeledMotionSample(
                sample: MotionSample(
                    timestamp: 0.0, pitch: 0.01, roll: 0.02, yaw: 0.03,
                    accelerometerX: 0.1, accelerometerY: 0.2, accelerometerZ: 0.98,
                    gyroX: 0.01, gyroY: -0.02, gyroZ: 0.03
                ),
                label: "good"
            ),
            LabeledMotionSample(
                sample: MotionSample(
                    timestamp: 0.5, pitch: -0.45, roll: 0.1, yaw: -0.2,
                    accelerometerX: -0.3, accelerometerY: 0.4, accelerometerZ: 0.9,
                    gyroX: 0.05, gyroY: 0.06, gyroZ: -0.07
                ),
                label: "slouch"
            ),
        ]
    }

    private func temporaryCSVURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("csv")
    }

    @Test func recordThenParseRoundTripsExactly() throws {
        let samples = makeSamples()
        let url = temporaryCSVURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try CSVRecorder().write(samples, to: url)
        let parsed = try CSVParser().parse(url)

        #expect(parsed == samples)
    }

    @Test func writeRejectsLabelsContainingCommas() {
        let invalid = [LabeledMotionSample(sample: makeSamples()[0].sample, label: "good,ish")]
        let url = temporaryCSVURL()
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: CSVError.invalidLabel("good,ish")) {
            try CSVRecorder().write(invalid, to: url)
        }
    }

    @Test func parseRejectsRowsWithWrongColumnCount() {
        let malformed = "\(CSVRecorder.header)\n0.0,0.1,0.2\n"

        #expect(throws: CSVError.columnCountMismatch(expected: 11, found: 3, row: "0.0,0.1,0.2")) {
            try CSVParser().parse(malformed)
        }
    }

    @Test func parseRejectsMissingOrMismatchedHeader() {
        let malformed = "not,the,right,header\n0.0,0.1\n"

        #expect(throws: CSVError.missingHeader) {
            try CSVParser().parse(malformed)
        }
    }
}
