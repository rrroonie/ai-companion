## IosTestApp

This folder contains a minimal SwiftUI iOS test application you can run on simulators or your iPhone.

### Open in Xcode

- In a terminal from the repo root:
  - `open apps/ios-test/IosTestApp.xcodeproj`
- Or open `apps/ios-test/IosTestApp.xcodeproj` directly in Finder.

### Run on simulator

1. In Xcode, select the `IosTestApp` scheme.
2. Choose an iOS simulator device (e.g. an iPhone) from the device menu.
3. Press **⌘R** to build and run.
4. The app shows a label and a **Hello World** button; tapping the button updates the label text to “Hello World”.

### Run on a physical iPhone

1. Connect your iPhone via USB or Wi‑Fi (if wireless debugging is set up).
2. In Xcode, select your iPhone as the run destination.
3. In the **Signing & Capabilities** tab for the `IosTestApp` target:
   - Set **Team** to your Apple ID.
   - Leave **Automatically manage signing** enabled.
   - Ensure the bundle identifier (default `com.yourname.IosTestApp`) is unique for your account.
4. Trust the developer certificate on your iPhone if prompted.
5. Press **⌘R** to build, install, and launch the app on your device.

### Development team (local config)

The development team for code signing is read from **`Config/Local.xcconfig`**, which is not checked in. On a fresh clone:

1. Copy the example: `cp Config/Local.xcconfig.example Config/Local.xcconfig`
2. Open `Config/Local.xcconfig` and set `DEVELOPMENT_TEAM` to your Apple team ID (Xcode → Signing & Capabilities → Team → right‑click team → Copy Team ID).

### Notes

- The deployment target is set to iOS 17.0; adjust it in the project settings if needed to match your devices.
- You can customize the bundle identifier and signing settings further in Xcode as your needs grow.

