import Foundation

/// Reads CSV files produced by `CSVRecorder` back into labeled samples.
public struct CSVParser: Sendable {
    public init() {}

    public func parse(_ url: URL) throws -> [LabeledMotionSample] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return try parse(contents)
    }

    public func parse(_ contents: String) throws -> [LabeledMotionSample] {
        var lines = contents.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard !lines.isEmpty else { return [] }

        let header = lines.removeFirst()
        guard header == CSVRecorder.header else {
            throw CSVError.missingHeader
        }

        return try lines.map(Self.parseRow)
    }

    private static func parseRow(_ line: String) throws -> LabeledMotionSample {
        let fields = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        let expected = CSVRecorder.columns.count
        guard fields.count == expected else {
            throw CSVError.columnCountMismatch(expected: expected, found: fields.count, row: line)
        }

        func double(_ index: Int) throws -> Double {
            guard let value = Double(fields[index]) else {
                throw CSVError.invalidNumber(field: CSVRecorder.columns[index], value: fields[index])
            }
            return value
        }

        let sample = MotionSample(
            timestamp: try double(0),
            pitch: try double(1),
            roll: try double(2),
            yaw: try double(3),
            accelerometerX: try double(4),
            accelerometerY: try double(5),
            accelerometerZ: try double(6),
            gyroX: try double(7),
            gyroY: try double(8),
            gyroZ: try double(9)
        )
        return LabeledMotionSample(sample: sample, label: fields[10])
    }
}
