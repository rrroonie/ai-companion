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

    @Published private(set) var state: State = .notLoaded

    private static let configuration = VLMRegistry.qwen2VL2BInstruct4Bit

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
                let config = forceLoad ? Self.configuration : Self.configurationForLoad()
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
    private static func configurationForLoad() -> ModelConfiguration {
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
