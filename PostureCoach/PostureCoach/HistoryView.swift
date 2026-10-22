import Charts
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView("No Sessions Yet", systemImage: "chart.bar")
            } else {
                List {
                    Section {
                        Chart(weeklyPostureData) { week in
                            BarMark(
                                x: .value("Week", week.weekStart, unit: .weekOfYear),
                                y: .value("Good posture %", week.averagePercentUpright)
                            )
                            .foregroundStyle(.green)
                        }
                        .chartYScale(domain: 0...100)
                        .frame(height: 220)
                        .listRowInsets(EdgeInsets())
                        .padding()
                    }

                    Section("Sessions") {
                        ForEach(sessions) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.startTime, format: .dateTime)
                                    .font(.headline)
                                Text(
                                    "\(session.duration.formattedAsMinutesSeconds) · \(Int(session.percentUpright))% upright · \(session.slouchCount) slouches · \(session.nudgeCount) nudges"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
    }

    private var weeklyPostureData: [WeeklyPosture] {
        let calendar = Calendar.current
        let grouped: [Date: [Session]] = Dictionary(grouping: sessions) { session in
            calendar.dateInterval(of: .weekOfYear, for: session.startTime)?.start ?? session.startTime
        }

        var weeks: [WeeklyPosture] = []
        for (weekStart, sessionsInWeek) in grouped {
            let total: Double = sessionsInWeek.reduce(0) { $0 + $1.percentUpright }
            let average = total / Double(sessionsInWeek.count)
            weeks.append(WeeklyPosture(weekStart: weekStart, averagePercentUpright: average))
        }
        return weeks.sorted { $0.weekStart < $1.weekStart }
    }
}

private struct WeeklyPosture: Identifiable {
    let weekStart: Date
    let averagePercentUpright: Double
    var id: Date { weekStart }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: Session.self, inMemory: true)
}
