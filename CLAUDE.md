# PostureCoach

iOS 17+ SwiftUI app that detects slouching from AirPods head-motion data
(`CMHeadphoneMotionManager`) and nudges the user to sit up. Portfolio project —
code quality, tests, and measurable detection results matter more than speed.

## Architecture

- All logic lives in the local Swift package **PostureKit**
  (`PostureKit/`), testable headlessly with `swift test`.
- The app target (`PostureCoach/`) is thin: SwiftUI views, SwiftData storage,
  and the CoreMotion source — no detection logic.
- Sensor input goes through a `SensorSource` protocol with three
  implementations: Headphone (CMHeadphoneMotionManager), Phone, and Replay
  (feeds recorded CSV data for tests/demos).
- Never hand-edit `PostureCoach.xcodeproj/project.pbxproj`. New logic goes in
  PostureKit; if the app target needs a new file reference, do it through
  Xcode.

## Commands

```bash
cd PostureKit && swift test                                                  # test logic
xcodebuild -scheme PostureCoach -destination 'generic/platform=iOS Simulator' build  # build app
```

Motion features require a real device (AirPods + iPhone) and are tested
manually — don't try to simulate them in `swift test`.

## Rules

- Detection thresholds are tuned against the CSV fixtures in
  `PostureKit/Tests/PostureKitTests/Resources`. Changing a threshold without
  re-checking against these is how regressions sneak in.
- Every detector change needs a test.
- Only mark a PostureKit symbol `public` if the app target actually uses it.
- Commit after each working milestone.

## Package.swift

`PostureKit/Package.swift` must keep:
- `platforms: [.iOS(.v17), .macOS(.v14)]` — the macOS platform is what lets
  `swift test` run locally on the Mac instead of requiring a device/simulator.
- The `.library(name: "PostureKit", targets: ["PostureKit"])` product — this
  is what the app target links against.
