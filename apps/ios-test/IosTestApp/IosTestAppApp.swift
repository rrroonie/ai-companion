import SwiftUI

@main
struct IosTestAppApp: App {
    @StateObject private var visionModelManager = VisionModelManager()

    var body: some Scene {
        WindowGroup {
            ContentView(visionModelManager: visionModelManager)
        }
    }
}

