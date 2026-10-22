import PostureKit
import SwiftData
import SwiftUI

struct SessionView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SessionViewModel
    @State private var showNudgeBanner = false

    init(sensorSource: any SensorSource, config: DetectorConfig = DetectorConfig()) {
        _viewModel = State(initialValue: SessionViewModel(sensorSource: sensorSource, config: config))
    }

    var body: some View {
        VStack(spacing: 24) {
            postureIndicator

            if viewModel.isRunning, viewModel.postureState == .calibrating {
                Text("Calibrating… \(viewModel.calibrationSecondsRemaining)s")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Text(sessionTimerText)
                .font(.system(.title2, design: .monospaced))

            if showNudgeBanner {
                Text("Sit up straight!")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.15), in: .capsule)
                    .transition(.opacity.combined(with: .scale))
            }

            Button(viewModel.isRunning ? "Stop" : "Start") {
                if viewModel.isRunning {
                    viewModel.stop()
                } else {
                    viewModel.start()
                }
            }
            .font(.title2)
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .animation(.default, value: showNudgeBanner)
        .onChange(of: viewModel.lastNudgeAt) { _, _ in
            showNudgeBanner = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                showNudgeBanner = false
            }
        }
        .onDisappear { viewModel.stop() }
        .onChange(of: viewModel.finishedSession) { _, newValue in
            guard let summary = newValue else { return }
            let session = Session(
                startTime: summary.startDate,
                duration: summary.duration,
                percentUpright: summary.percentUpright,
                slouchCount: summary.slouchCount,
                nudgeCount: summary.nudgeCount
            )
            modelContext.insert(session)
            try? modelContext.save()
        }
    }

    private var postureIndicator: some View {
        Circle()
            .fill(indicatorColor)
            .frame(width: 140, height: 140)
            .overlay {
                Text(indicatorLabel)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
    }

    private var indicatorColor: Color {
        switch viewModel.postureState {
        case .calibrating: .gray
        case .upright: .green
        case .slouching: .red
        }
    }

    private var indicatorLabel: String {
        switch viewModel.postureState {
        case .calibrating: "Calibrating"
        case .upright: "Upright"
        case .slouching: "Slouching"
        }
    }

    private var sessionTimerText: String {
        viewModel.sessionElapsed.formattedAsMinutesSeconds
    }
}

/// Synthetic motion data for the preview: upright through calibration, then
/// a sustained slouch, so the preview shows calibration, the green/red
/// indicator flip, and (on device) the nudge haptic firing.
private enum PreviewMotionData {
    static let samples: [MotionSample] = {
        func sample(at timestamp: TimeInterval, pitchDegrees: Double) -> MotionSample {
            MotionSample(
                timestamp: timestamp,
                pitch: pitchDegrees * .pi / 180,
                roll: 0,
                yaw: 0,
                accelerometerX: 0,
                accelerometerY: 0,
                accelerometerZ: 1,
                gyroX: 0,
                gyroY: 0,
                gyroZ: 0
            )
        }

        var samples: [MotionSample] = []
        var t: TimeInterval = 0
        while t <= 3 {
            samples.append(sample(at: t, pitchDegrees: 0)) // upright, calibrating
            t += 0.25
        }
        while t <= 10 {
            samples.append(sample(at: t, pitchDegrees: -30)) // sustained slouch
            t += 0.25
        }
        return samples
    }()
}

#Preview("Replay Demo") {
    SessionView(
        sensorSource: ReplaySource(samples: PreviewMotionData.samples, speedMultiplier: 1),
        config: DetectorConfig(
            calibrationDuration: 3,
            slouchThresholdDegrees: 15,
            minimumSlouchDuration: 1,
            nudgeCooldown: 5
        )
    )
    .modelContainer(for: Session.self, inMemory: true)
}
