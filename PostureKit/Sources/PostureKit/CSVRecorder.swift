import Foundation

public enum CSVError: Error, Equatable {
    case missingHeader
    case columnCountMismatch(expected: Int, found: Int, row: String)
    case invalidNumber(field: String, value: String)
    case invalidLabel(String)
}

/// Writes labeled motion samples to a CSV file for later replay or analysis.
public struct CSVRecorder: Sendable {
    /// Column order shared with `CSVParser` so the two stay in sync.
    static let columns = [
        "timestamp", "pitch", "roll", "yaw",
        "accelerometerX", "accelerometerY", "accelerometerZ",
        "gyroX", "gyroY", "gyroZ", "label",
    ]
    static let header = columns.joined(separator: ",")

    public init() {}

    public func write(_ samples: [LabeledMotionSample], to url: URL) throws {
        for labeled in samples where labeled.label.contains(",") || labeled.label.contains("\n") {
            throw CSVError.invalidLabel(labeled.label)
        }

        var lines = [Self.header]
        lines.append(contentsOf: samples.map(Self.row(for:)))
        let contents = lines.joined(separator: "\n") + "\n"
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func row(for labeled: LabeledMotionSample) -> String {
        let sample = labeled.sample
        let numericFields: [Double] = [
            sample.timestamp, sample.pitch, sample.roll, sample.yaw,
            sample.accelerometerX, sample.accelerometerY, sample.accelerometerZ,
            sample.gyroX, sample.gyroY, sample.gyroZ,
        ]
        let numericFieldStrings = numericFields.map { String($0) }
        return (numericFieldStrings + [labeled.label]).joined(separator: ",")
    }
}
