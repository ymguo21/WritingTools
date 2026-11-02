import AppKit
import Observation

private let logger = AppLogger.logger("ScreenTranslationViewModel")

/// Drives the Screenshot Translate window: sends the screenshot to the model and
/// shows the recognized text and its translation as they arrive.
@MainActor
@Observable
final class ScreenTranslationViewModel {
    enum Phase: Equatable {
        case working
        case ready
        case failed(String)
    }

    let title: String

    private(set) var phase: Phase = .working
    private(set) var original = ""
    private(set) var translation = ""
    /// False when the reply could not be split, so the original is unavailable.
    private(set) var separatedOriginal = true

    private let imageData: Data
    private let provider: any AIProvider
    private let systemPrompt: String
    private var requestTask: Task<Void, Never>?

    private static let userPrompt = "Read and translate the text in the attached image."
    private static let flushInterval: Duration = .milliseconds(80)

    init(title: String, imageData: Data, provider: any AIProvider, systemPrompt: String) {
        self.title = title
        self.imageData = imageData
        self.provider = provider
        self.systemPrompt = systemPrompt
    }

    func start() {
        requestTask?.cancel()
        phase = .working

        requestTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.requestTask = nil }

            do {
                var raw = ""
                var lastFlush = ContinuousClock.now

                try await provider.processTextStreaming(
                    systemPrompt: systemPrompt,
                    userPrompt: Self.userPrompt,
                    images: [imageData]
                ) { [weak self] chunk in
                    guard let self else { return }
                    raw += chunk
                    let now = ContinuousClock.now
                    if now - lastFlush >= Self.flushInterval {
                        self.show(ScreenTranslationOutput.parse(raw, isComplete: false))
                        lastFlush = now
                    }
                }
                try Task.checkCancellation()

                let parsed = ScreenTranslationOutput.parse(raw, isComplete: true)
                guard !parsed.original.isEmpty || !parsed.translation.isEmpty else {
                    phase = .failed(String(localized: "No text was recognized in the screenshot."))
                    return
                }
                show(parsed)
                phase = .ready
            } catch is CancellationError {
                return
            } catch {
                logger.error("Screenshot translation failed: \(error.localizedDescription)")
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        let wasInFlight = requestTask != nil
        requestTask?.cancel()
        requestTask = nil
        if wasInFlight {
            provider.cancel()
        }
    }

    private func show(_ parsed: ScreenTranslationOutput.Parsed) {
        original = parsed.original
        translation = parsed.translation
        separatedOriginal = parsed.usedTags
    }
}
