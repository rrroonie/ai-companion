import Foundation
import MLXLMCommon
import MLXVLM
import SwiftUI

/// Manages download and load of the vision model; exposes state and the loaded container for inference.
/// Uses the Hub cache directory so the model is only downloaded once; subsequent launches load from disk.
final class VisionModelManager: ObservableObject {
    enum State: Sendable {
        case notLoaded
        case loading
        case ready(ModelContainer)
        case error(Error)
    }

    enum PeriodicMode: String, CaseIterable, Sendable {
        case off
        case every2s
        case every4s
        case every6s
        case every8s
    }

    struct VisionModel: Identifiable, Equatable {
        let id: String
        let displayName: String
        let configuration: ModelConfiguration
    }

    @Published private(set) var state: State = .notLoaded

    private static let defaultModels: [VisionModel] = [
        .init(
            id: "qwen2-vl-2b-instruct-4bit",
            displayName: "Qwen2-VL-2B-Instruct-4bit",
            configuration: VLMRegistry.qwen2VL2BInstruct4Bit
        ),
        .init(
            id: "moondream2-4bit",
            displayName: "Moondream2-4bit",
            configuration: ModelConfiguration(
                id: "mlx-community/moondream2-4bit",
                defaultPrompt: "Describe the image in English."
            )
        ),
        .init(
            id: "fastvlm-0.5b",
            displayName: "FastVLM-0.5B (Apple)",
            configuration: VLMRegistry.fastvlm
        ),
        .init(
            id: "llama-3.2-11b-vision-4bit",
            displayName: "Llama-3.2-11B-Vision-4bit",
            configuration: ModelConfiguration(
                id: "mlx-community/Llama-3.2-11B-Vision-Instruct-4bit",
                defaultPrompt: "Describe the image in English."
            )
        ),
    ]

    @Published private(set) var availableModels: [VisionModel] = defaultModels

    private let defaultsKeyModel = "vision.selectedModelID"
    private let defaultsKeyPeriodic = "vision.periodicMode"

    @Published var selectedModelID: String
    @Published var periodicMode: PeriodicMode

    var currentModel: VisionModel {
        availableModels.first(where: { $0.id == selectedModelID }) ?? availableModels[0]
    }

    var periodicInterval: TimeInterval? {
        switch periodicMode {
        case .off: return nil
        case .every2s: return 2
        case .every4s: return 4
        case .every6s: return 6
        case .every8s: return 8
        }
    }

    init() {
        let models = Self.defaultModels
        let stored = UserDefaults.standard.string(forKey: defaultsKeyModel)
        if let stored, models.contains(where: { $0.id == stored }) {
            selectedModelID = stored
        } else {
            selectedModelID = models[0].id
        }

        if let periodicRaw = UserDefaults.standard.string(forKey: defaultsKeyPeriodic),
           let savedMode = PeriodicMode(rawValue: periodicRaw) {
            periodicMode = savedMode
        } else {
            periodicMode = .off
        }
    }

    /// Reset to the idle state (no model loaded, no error).
    func resetState() {
        state = .notLoaded
    }

    /// Unload the current model from memory and optionally reload the selected one.
    func unloadAndReloadSelected(forceDownload: Bool = false) {
        state = .notLoaded
        startLoading(forceLoad: forceDownload)
    }

    /// Persist periodic mode changes.
    func setPeriodicMode(_ mode: PeriodicMode) {
        periodicMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: defaultsKeyPeriodic)
    }

    /// Call from view's onAppear to start download/load.
    /// - Parameter forceLoad: If true, always use the Hub id (skip cache); use after errors or to refresh the model.
    ///   No-op if already loading, unless forceLoad is true (then reloads even when ready).
    func startLoading(forceLoad: Bool = false) {
        switch state {
        case .loading:
            if !forceLoad { return }
        case .ready:
            if !forceLoad { return }
        case .notLoaded, .error:
            break
        }

        Task { @MainActor in
            state = .loading
        }

        Task {
            do {
                let baseConfig = currentModel.configuration
                let config = forceLoad ? baseConfig : configurationForLoad(baseConfig)
                let container = try await loadModelContainer(
                    hub: defaultHubApi,
                    configuration: config,
                    progressHandler: { _ in }
                )
                await MainActor.run {
                    state = .ready(container)
                }
            } catch {
                await MainActor.run {
                    state = .error(error)
                }
            }
        }
    }

    /// Prefer loading from local cache when the model is already downloaded (same id/revision).
    /// That skips the download step and makes subsequent app launches faster.
    private func configurationForLoad(_ configuration: ModelConfiguration) -> ModelConfiguration {
        let config = configuration
        let hub = defaultHubApi
        let localDir = config.modelDirectory(hub: hub)
        if Self.isValidCachedModelDirectory(localDir) {
            return ModelConfiguration(
                directory: localDir,
                defaultPrompt: config.defaultPrompt
            )
        }
        return config
    }

    private static func isValidCachedModelDirectory(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path),
              fileManager.fileExists(atPath: url.appending(component: "config.json").path) else {
            return false
        }
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: nil) else {
            return false
        }
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "safetensors" {
                return true
            }
        }
        return false
    }

    /// Returns the loaded container when state is `.ready`; otherwise nil.
    var container: ModelContainer? {
        if case .ready(let c) = state { return c }
        return nil
    }
}
