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
    @State private var isShowingSettings = false
    @State private var liveDescription: String?
    @State private var isPeriodicInferring = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Always show camera when authorized; overlay model status on top.
                cameraContent

                if case .loading = visionModelManager.state {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Loading vision model…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 50)
                }

                if case .error(let error) = visionModelManager.state {
                    VStack(spacing: 8) {
                        Text("Model failed to load")
                            .font(.headline)
                        Text(error.localizedDescription)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Dismiss") {
                            // Let the user continue with camera only.
                            // Reset state so the overlay disappears; model is simply not loaded.
                            visionModelManager.resetState()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(visionModelManager: visionModelManager)
        }
        .onChange(of: capturedImageForSheet?.id) { _, newId in
            if newId != nil {
                descriptionForSheet = nil
                inferenceErrorForSheet = nil
                isInferringForSheet = true
            }
        }
        .onAppear {
            // Only set up camera permissions on launch; model loading is user-initiated from Settings.
            cameraManager.checkPermission()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .task(id: visionModelManager.periodicMode) {
            await runPeriodicLoop()
        }
    }

    @ViewBuilder
    private var cameraContent: some View {
        if cameraManager.isAuthorized {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top controls (in their own row)
                    HStack {
                        Button {
                            isShowingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.headline)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.bordered)
                        .padding(.leading, 8)
                        .padding(.top, 8)

                        Spacer()

                        if case .ready = visionModelManager.state {
                            Button {
                                visionModelManager.startLoading(forceLoad: true)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.headline)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.bordered)
                            .padding(.trailing, 8)
                            .padding(.top, 8)
                        }
                    }

                    // Camera preview takes the remaining vertical space
                    GeometryReader { proxy in
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
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    }

                    // Bottom controls (own row)
                    HStack(spacing: 24) {
                        Button {
                            cameraManager.zoomOut()
                        } label: {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.headline)
                                .frame(width: 30, height: 30)
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
                                .font(.system(size: 22))
                                .frame(width: 52, height: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .clipShape(Circle())

                        Button {
                            cameraManager.zoomIn()
                        } label: {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.headline)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.bordered)
                        .disabled(cameraManager.zoomFactor >= cameraManager.maxZoomFactor)
                    }
                    .padding(.vertical, 8)
                }
                .ignoresSafeArea(edges: .all)

                // Periodic description overlay
                if let text = liveDescription {
                    VStack {
                        Spacer()
                        HStack {
                            if isPeriodicInferring {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            Text(text)
                                .font(.footnote)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.bottom, 64)
                        .padding(.horizontal, 16)
                    }
                    .transition(.opacity)
                }
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

    private func runPeriodicLoop() async {
        while !Task.isCancelled {
            guard
                let interval = visionModelManager.periodicInterval,
                visionModelManager.container != nil,
                cameraManager.isAuthorized,
                let container = visionModelManager.container
            else {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // check roughly every second when inactive
                continue
            }

            if isPeriodicInferring {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                continue
            }

            guard let cgImage = cameraManager.captureCurrentFrame() else {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                continue
            }

            await MainActor.run {
                isPeriodicInferring = true
            }

            let ciImage = CIImage(cgImage: cgImage)
            let session = ChatSession(container)

            do {
                let result = try await session.respond(
                    to: "Briefly describe what you see in this image.",
                    image: .ciImage(ciImage)
                )
                await MainActor.run {
                    liveDescription = result
                    isPeriodicInferring = false
                }
            } catch {
                await MainActor.run {
                    isPeriodicInferring = false
                }
            }

            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
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

struct SettingsView: View {
    @ObservedObject var visionModelManager: VisionModelManager
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingReloadAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section("Vision model") {
                    ForEach(visionModelManager.availableModels, id: \.id) { model in
                        modelRow(for: model)
                    }
                }

                Section {
                    Button("Apply and reload model") {
                        isShowingReloadAlert = true
                    }
                }

                Section("Periodic description") {
                    Picker("Frequency", selection: Binding(
                        get: { visionModelManager.periodicMode },
                        set: { visionModelManager.setPeriodicMode($0) }
                    )) {
                        Text("Off").tag(VisionModelManager.PeriodicMode.off)
                        Text("Every 2 seconds").tag(VisionModelManager.PeriodicMode.every2s)
                        Text("Every 4 seconds").tag(VisionModelManager.PeriodicMode.every4s)
                        Text("Every 6 seconds").tag(VisionModelManager.PeriodicMode.every6s)
                        Text("Every 8 seconds").tag(VisionModelManager.PeriodicMode.every8s)
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
            
        .alert("Reload model?", isPresented: $isShowingReloadAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reload", role: .destructive) {
                visionModelManager.unloadAndReloadSelected(forceDownload: true)
            }
        } message: {
            Text("This will unload the current model and load the selected one. This may take a little while.")
        }
    }


    @ViewBuilder
    private func modelRow(for model: VisionModelManager.VisionModel) -> some View {
        HStack {
            Text(model.displayName)
            Spacer()
            if model.id == visionModelManager.selectedModelID {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            visionModelManager.selectedModelID = model.id
        }
    }
}

#Preview {
    ContentView(visionModelManager: VisionModelManager())
}
