import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject var visionModelManager: VisionModelManager
    @StateObject private var cameraManager = CameraManager()
    @State private var capturedImageForSheet: CapturedImageItem?

    var body: some View {
        ZStack {
            switch visionModelManager.state {
            case .notLoaded, .loading:
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Downloading/loading vision model…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            case .ready:
                cameraContent
            case .error(let error):
                VStack(spacing: 16) {
                    Text("Model failed to load")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
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
            visionModelManager.startLoading()
            cameraManager.checkPermission()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }

    @ViewBuilder
    private var cameraContent: some View {
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
            .onAppear {
                cameraManager.startSession()
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
}

private struct CapturedImageItem: Identifiable {
    let id = UUID()
    let cgImage: CGImage
}

#Preview {
    ContentView(visionModelManager: VisionModelManager())
}
