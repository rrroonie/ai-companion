---
name: 03-periodic-vision-mode
overview: Add a periodic on-device vision mode that uses the currently loaded VLM to describe the live camera view at a configurable interval (2s/4s/6s/8s) without rendering the captured image, with full control from the Settings screen.
todos:
  - id: vm-periodic-config
    content: Extend VisionModelManager with a persisted periodicMode setting (off, 2s, 4s, 6s, 8s) and helper to expose the active interval.
  - id: settings-periodic-ui
    content: Update SettingsView to add a Periodic description section with options Off, Every 2s, Every 4s, Every 6s, Every 8s bound to the manager’s periodicMode; keep model selection behavior unchanged.
  - id: periodic-run-loop
    content: Add a periodic inference loop in ContentView that, when periodicMode is not off and a model is ready, periodically captures a frame, runs it through the current VLM, and stores the latest description in state, avoiding overlapping runs.
  - id: ui-live-description
    content: Overlay the most recent periodic description in the camera UI as text (no image) in a small pill above the bottom controls, with a subtle loading indicator while a periodic inference is running.
  - id: safety-guards
    content: Ensure periodic mode only runs when the camera is authorized and a model is loaded, and that it pauses automatically when state is not .ready or when the app leaves the camera screen.
isProject: false
---

# 03 – Periodic vision mode (live descriptions)

## Goal

Add a **periodic vision mode** that, when enabled, uses the currently loaded on-device vision model to **periodically describe what the camera sees** at a configurable frequency (2s/4s/6s/8s), **without showing the captured image**. Control this entirely from the Settings screen, and keep the camera UI responsive and full-screen.

---

## 1. VisionModelManager – periodic mode configuration

**File**: `apps/ios-test/IosTestApp/VisionModelManager.swift`

- Add an enum and persisted property:
  - `enum PeriodicMode: String, CaseIterable, Sendable { case off, every2s, every4s, every6s, every8s }`
  - `@Published var periodicMode: PeriodicMode` with a `UserDefaults`-backed key (e.g. `"vision.periodicMode"`).
  - Default value: `.off`.
- Provide a helper:
  - `var periodicInterval: TimeInterval?` that returns `2, 4, 6, 8` seconds or `nil` for `.off`.
- Keep this logic **independent** of model selection and loading; it’s just configuration.

---

## 2. SettingsView – periodic mode controls

**File**: `apps/ios-test/IosTestApp/ContentView.swift` (inline `SettingsView` struct)

- In `SettingsView`, add a new section under the model list:

  ```swift
  Section("Periodic description") {
      Picker("Frequency", selection: $visionModelManager.periodicMode) {
          Text("Off").tag(.off)
          Text("Every 2 seconds").tag(.every2s)
          Text("Every 4 seconds").tag(.every4s)
          Text("Every 6 seconds").tag(.every6s)
          Text("Every 8 seconds").tag(.every8s)
      }
      .pickerStyle(.inline) // or .menu on smaller screens
  }
  ```

- Keep the existing **model selection** section unchanged.
- Keep the **“Apply and reload model”** button and confirmation alert as-is; it only affects model choice, not periodic mode.
- Periodic mode should be **applied immediately** when changed (no need for extra confirmation), since it only toggles background behavior.

---

## 3. ContentView – periodic inference loop

**File**: `apps/ios-test/IosTestApp/ContentView.swift`

- Add new state:
  - `@State private var liveDescription: String?` – holds the latest periodic description.
  - `@State private var isPeriodicInferring = false` – prevents overlapping runs and drives a small spinner.
- Add a `Task`-driven loop bound to the periodic configuration:

  ```swift
  .task(id: visionModelManager.periodicMode) {
      await runPeriodicLoop()
  }
  ```

- Implement `runPeriodicLoop()` inside `ContentView`:
  - If `visionModelManager.periodicInterval` is `nil`, return immediately (mode is off).
  - Otherwise:
    - `while !Task.isCancelled`:
      - Read the current interval at the top of the loop.
      - Guard:
        - `visionModelManager.state == .ready`
        - `visionModelManager.container != nil`
        - `cameraManager.isAuthorized`
      - If any guard fails, `try await Task.sleep(...)` for the interval and continue.
      - Capture a frame with `cameraManager.captureCurrentFrame()`; if `nil`, sleep and continue.
      - Build a `CIImage` from the `CGImage`.
      - Set `isPeriodicInferring = true` on the main actor.
      - Use `ChatSession(container)` with a fixed prompt (e.g. “Briefly describe what you see in this image.”) to get a string result.
      - On success, update `liveDescription` and set `isPeriodicInferring = false` on the main actor.
      - On failure, optionally clear `liveDescription` or set a lightweight error indicator, and set `isPeriodicInferring = false`.
      - Sleep for the interval at the end of each loop.
- This loop:
  - Only runs when `periodicMode != .off`.
  - Cancels/restarts automatically when `periodicMode` changes (via `.task(id: ...)`).

---

## 4. Camera UI – showing periodic description

**File**: `apps/ios-test/IosTestApp/ContentView.swift`

- In `cameraContent`’s `ZStack` overlay, add a new small overlay near the bottom **above** the bottom control row:

  ```swift
  if let text = liveDescription {
      VStack {
          Spacer()
          HStack {
              if isPeriodicInferring {
                  ProgressView().scaleEffect(0.7)
              }
              Text(text)
                  .font(.footnote)
                  .lineLimit(2)
                  .multilineTextAlignment(.leading)
          }
          .padding(8)
          .background(.ultraThinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .padding(.bottom, 64) // just above bottom controls
          .padding(.horizontal, 16)
      }
      .transition(.opacity)
  }
  ```

- Do **not** open the capture sheet or show the captured image for periodic runs; they only produce text in this overlay.
- Manual capture (existing Capture button) should continue to work and show its own sheet, independent of periodic mode.

---

## 5. Safety and lifecycle

- **Run conditions**:
  - Periodic loop only active when:
    - `visionModelManager.periodicMode != .off`
    - `visionModelManager.state == .ready`
    - `visionModelManager.container != nil`
    - `cameraManager.isAuthorized == true`
- **Pause behavior**:
  - The `.task(id: ...)` in `ContentView` is naturally cancelled when:
    - `ContentView` disappears (leaving the camera screen).
    - `periodicMode` changes to `.off`.
  - No extra app lifecycle hooks are required.
- **Memory considerations**:
  - Reuse the existing `VisionModelManager` load/unload behavior; periodic mode never loads models on its own.
  - If memory becomes an issue, the user can unload/reload models via Settings as before.

---

## 6. Summary

- **VisionModelManager**: gains `PeriodicMode` + persisted `periodicMode` + `periodicInterval`.
- **SettingsView**: adds a “Periodic description” section to choose Off / 2s / 4s / 6s / 8s.
- **ContentView**:
  - Periodic background loop that captures frames and runs the current VLM based on the selected interval.
  - Displays the latest periodic description as a small text pill overlay, with a tiny spinner while the current inference is running.
- Manual capture remains unchanged and can be used alongside periodic mode.

