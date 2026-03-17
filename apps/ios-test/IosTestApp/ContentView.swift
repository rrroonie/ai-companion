import CoreImage
import MLXLMCommon
import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject var visionModelManager: VisionModelManager
    @StateObject private var cameraManager = CameraManager()
    @State private var capturedImageForSheet: CapturedImageItem?
    @State private var descriptionForSheet: String?
    @State private var inferenceErrorForSheet: Error?
    @State private var isInferringForSheet = false
    @State private var pinchBaseZoom: CGFloat?

    var body: some View {
        NavigationStack {
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
                        HStack(spacing: 12) {
                            Button("Retry") {
                                visionModelManager.startLoading()
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Force reload") {
                                visionModelManager.startLoading(forceLoad: true)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(item: $capturedImageForSheet) { item in
            CapturedImageSheetView(
                item: item,
                visionModelManager: visionModelManager,
                description: $descriptionForSheet,
                error: $inferenceErrorForSheet,
                isInferring: $isInferringForSheet
            )
        }
        .onChange(of: capturedImageForSheet?.id) { _, newId in
            if newId != nil {
                descriptionForSheet = nil
                inferenceErrorForSheet = nil
                isInferringForSheet = true
            }
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
            ZStack(alignment: .topTrailing) {
                CameraPreviewView(session: cameraManager.session)
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                if pinchBaseZoom == nil {
                                    pinchBaseZoom = cameraManager.zoomFactor
                                }
                                if let base = pinchBaseZoom {
                                    cameraManager.applyZoomToTarget(base * value)
                                }
                            }
                            .onEnded { _ in
                                pinchBaseZoom = nil
                            }
                    )
                    .ignoresSafeArea()

                if case .ready = visionModelManager.state {
                    Button {
                        visionModelManager.startLoading(forceLoad: true)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .padding(8)
                }
            }
            .navigationBarHidden(true)

            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(spacing: 40) {
                    Button {
                        cameraManager.zoomOut()
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .disabled(cameraManager.zoomFactor <= cameraManager.minZoomFactor)

                    Button {
                        if let image = cameraManager.captureCurrentFrame() {
                            cameraManager.capturedImage = image
                            descriptionForSheet = nil
                            inferenceErrorForSheet = nil
                            isInferringForSheet = true
                            capturedImageForSheet = CapturedImageItem(cgImage: image)
                        }
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 28))
                            .frame(width: 64, height: 64)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(Circle())

                    Button {
                        cameraManager.zoomIn()
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .disabled(cameraManager.zoomFactor >= cameraManager.maxZoomFactor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
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

private struct CapturedImageSheetView: View {
    let item: CapturedImageItem
    @ObservedObject var visionModelManager: VisionModelManager
    @Binding var description: String?
    @Binding var error: Error?
    @Binding var isInferring: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(uiImage: UIImage(cgImage: item.cgImage))
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 280)

            ScrollView {
                Group {
                    if isInferring {
                        HStack {
                            ProgressView()
                            Text("Describing image…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if let description {
                        Text(description)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let error {
                        Text("Description failed: \(error.localizedDescription)")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
        }
        .padding()
        .presentationDetents([.medium, .large])
        .onAppear {
            runInferenceIfNeeded()
        }
    }

    private func runInferenceIfNeeded() {
        guard isInferring, description == nil, error == nil,
              let container = visionModelManager.container else { return }

        let ciImage = CIImage(cgImage: item.cgImage)
        let session = ChatSession(container)

        Task {
            do {
                let result = try await session.respond(
                    to: "Describe what you see in this image in one or two sentences.",
                    image: .ciImage(ciImage)
                )
                await MainActor.run {
                    description = result
                    error = nil
                    isInferring = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    description = nil
                    isInferring = false
                }
            }
        }
    }
}

#Preview {
    ContentView(visionModelManager: VisionModelManager())
}
