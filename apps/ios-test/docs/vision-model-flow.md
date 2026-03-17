# Vision model flow

## Overview

The app loads an on-device vision-language model (VLM) at startup, then uses it to describe the scene when the user captures a photo from the camera. The model is **mlx-community/qwen2-vl-2b-instruct-4bit**, loaded via mlx-swift-lm (MLXVLM and MLXLMCommon).

## Startup order

1. **App launch** – `IosTestAppApp` creates a `VisionModelManager` and passes it to `ContentView`.
2. **Model load** – On appear, `ContentView` calls `visionModelManager.startLoading()`. The manager calls `loadModelContainer(configuration: VLMRegistry.qwen2VL2BInstruct4Bit)`, which downloads the model from Hugging Face (if not cached) and loads it into memory.
3. **Loading UI** – While the model is loading, the app shows “Downloading/loading vision model…” and does not start the camera.
4. **Camera start** – When the model state becomes `.ready`, the camera UI is shown and `CameraManager.startSession()` is called. The user can then tap **Capture**.

## Capture → inference → description

1. **Capture** – The user taps **Capture**. `CameraManager.captureCurrentFrame()` returns the current frame as a `CGImage`.
2. **Sheet** – The image is shown in a sheet. Inference state is reset (`isInferring = true`, description/error cleared).
3. **Inference** – When the sheet appears, `CapturedImageSheetView` runs inference: convert `CGImage` to `CIImage`, build `UserInput.Image.ciImage(ciImage)`, create a `ChatSession` with the loaded `ModelContainer`, and call `session.respond(to: "Describe what you see…", image: .ciImage(ciImage))`.
4. **Result** – The description (or error) is shown below the image in the sheet. Inference runs off the main thread; the UI is updated on the main actor when done.

## Components

| Component | Role |
|-----------|------|
| **VisionModelManager** | Owns model load via `loadModelContainer`; exposes state (notLoaded / loading / ready(container) / error) and the loaded `ModelContainer`. |
| **ContentView** | Gates camera on model ready; shows loading/error UI; on Capture, presents sheet and resets inference state. |
| **CapturedImageSheetView** | Presents captured image; on appear, runs VLM inference via `ChatSession.respond(to:image:)` and shows description or error. |

## Model

- **Id**: `mlx-community/qwen2-vl-2b-instruct-4bit`
- **Config**: `VLMRegistry.qwen2VL2BInstruct4Bit` (MLXVLM)
- **Download**: Handled by mlx-swift-lm (Hugging Face Hub); cached in the app’s cache directory.

## See also

- [Camera architecture](camera-architecture.md) – Camera preview and capture.
- [.cursor/plans/02-vision-model-camera.plan.md](../../.cursor/plans/02-vision-model-camera.plan.md) – Plan and commit points.
