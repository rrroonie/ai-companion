import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var capturedImageForSheet: CapturedImageItem?

    var body: some View {
        ZStack {
            if cameraManager.isAuthorized {
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    Button("Capture") {
                        if let image = cameraManager.captureCurrentFrame() {
                            cameraManager.capturedImage = image
                            capturedImageForSheet = CapturedImageItem(cgImage: image)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 40)
                }
            } else {
                VStack(spacing: 16) {
                    Text("Camera access is required to capture photos.")
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .sheet(item: $capturedImageForSheet) { item in
            Image(uiImage: UIImage(cgImage: item.cgImage))
                .resizable()
                .scaledToFit()
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            cameraManager.checkPermission()
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
}

private struct CapturedImageItem: Identifiable {
    let id = UUID()
    let cgImage: CGImage
}

#Preview {
    ContentView()
}
