import AppKit
import Observation

private let logger = AppLogger.logger("FormulaViewModel")

/// Drives the Formula OCR window: sends the screenshot to the model, prepares
/// the transcription for the preview, and repairs formulas the preview cannot
/// render.
@MainActor
@Observable
final class FormulaViewModel {
    enum Phase: Equatable {
        case recognizing
        case ready
        case failed(String)
    }

    let title: String
    let screenshot: NSImage?

    private(set) var phase: Phase = .recognizing
    /// The LaTeX Markdown to copy.
    private(set) var source = ""
    /// The Markdown to render; formulas the preview cannot parse appear as code.
    private(set) var preview = ""
    private(set) var failures: [FormulaOutput.Failure] = []

    private let imageData: Data
    private let provider: any AIProvider
    private let systemPrompt: String
    private var requestTask: Task<Void, Never>?

    init(title: String, imageData: Data, provider: any AIProvider, systemPrompt: String) {
        self.title = title
        self.screenshot = NSImage(data: imageData)
        self.imageData = imageData
        self.provider = provider
        self.systemPrompt = systemPrompt
    }

    func start() {
        requestTask?.cancel()
        phase = .recognizing

        requestTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.requestTask = nil }

            do {
                let reply = try await provider.processText(
                    systemPrompt: systemPrompt,
                    userPrompt: Self.userPrompt,
                    images: [imageData],
                    streaming: false
                )
                try Task.checkCancellation()

                var prepared = FormulaOutput.prepare(reply, validate: FormulaValidator.error(for:))
                guard !prepared.source.isEmpty else {
                    phase = .failed(String(localized: "No formula was recognized in the screenshot."))
                    return
                }

                if !prepared.failures.isEmpty,
                   let repaired = await repairedPreview(of: prepared) {
                    prepared = FormulaOutput.Prepared(
                        source: prepared.source,
                        preview: repaired.preview,
                        failures: repaired.failures
                    )
                }
                try Task.checkCancellation()

                source = prepared.source
                preview = prepared.preview
                failures = prepared.failures
                phase = .ready
            } catch is CancellationError {
                return
            } catch {
                logger.error("Formula request failed: \(error.localizedDescription)")
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

    // MARK: - Repair

    /// Asks the model once to rewrite formulas the preview cannot parse. Only the
    /// preview uses the result: the text to copy stays as transcribed.
    private func repairedPreview(of prepared: FormulaOutput.Prepared) async -> FormulaOutput.Prepared? {
        let errors = prepared.failures
            .map { "- \($0.latex)\n  Error: \($0.message)" }
            .joined(separator: "\n")
        let request = """
            Markdown:

            \(prepared.source)

            Formulas the renderer rejected:
            \(errors)
            """

        do {
            let reply = try await provider.processText(
                systemPrompt: Self.repairPrompt,
                userPrompt: request,
                images: [],
                streaming: false
            )
            let repaired = FormulaOutput.prepare(reply, validate: FormulaValidator.error(for:))
            return repaired.failures.count < prepared.failures.count ? repaired : nil
        } catch {
            logger.error("Formula repair failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static let userPrompt = "Transcribe the formula in the attached image."

    private static let repairPrompt = """
        You adapt LaTeX for a renderer that supports only part of it. Rewrite the Markdown you are given so \
        that every formula can be rendered, keeping the meaning and the visible result as close as possible. \
        The renderer rejects, for example: \\underbrace, \\overbrace, \\xrightarrow, \\substack, \\middle, \\mathop, \
        the array environment and cases with more than two columns. Replace each with the nearest construct \
        that is supported, such as \\rightarrow, aligned or matrix. Change nothing else. Output only the \
        Markdown, without code fences or commentary.
        """
}
