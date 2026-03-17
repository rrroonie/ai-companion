import MLXLMCommon
import MLXVLM
import SwiftUI

/// Manages download and load of the vision model; exposes state and the loaded container for inference.
final class VisionModelManager: ObservableObject {
    enum State: Sendable {
        case notLoaded
        case loading
        case ready(ModelContainer)
        case error(Error)
    }

    @Published private(set) var state: State = .notLoaded

    /// Call from view's onAppear to start download/load. No-op if already loading or ready.
    func startLoading() {
        switch state {
        case .loading, .ready:
            return
        case .notLoaded, .error:
            break
        }

        Task { @MainActor in
            state = .loading
        }

        Task {
            do {
                let container = try await loadModelContainer(
                    configuration: VLMRegistry.qwen2VL2BInstruct4Bit,
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

    /// Returns the loaded container when state is `.ready`; otherwise nil.
    var container: ModelContainer? {
        if case .ready(let c) = state { return c }
        return nil
    }
}
