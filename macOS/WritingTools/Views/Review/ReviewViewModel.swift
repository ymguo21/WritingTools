import AppKit
import Observation

private let logger = AppLogger.logger("ReviewViewModel")

/// Drives a review window: runs the command, builds the word-level diff,
/// tracks accept/reject decisions, and handles on-demand explanations.
@MainActor
@Observable
final class ReviewViewModel {
    enum Phase: Equatable {
        case checking
        case ready
        case failed(String)
    }

    /// How the text pane shows the edits.
    enum DisplayMode: Hashable {
        /// Pending edits as red/green suggestions, reviewed edits resolved.
        case markup
        /// The text that Apply would write back, without markup.
        case final
        /// The selected text as it was.
        case original
    }

    struct FollowUp: Identifiable, Equatable {
        let id = UUID()
        let question: String
        var answer: String
        var isStreaming: Bool
    }

    private(set) var phase: Phase = .checking
    private(set) var diff: TextDiff?
    var selectedHunkID: Int?
    var displayMode: DisplayMode = .markup
    private(set) var explainingHunkIDs: Set<Int> = []
    private(set) var followUps: [FollowUp] = []
    private(set) var isAnswering = false
    var errorMessage: String?
    private(set) var showCopyConfirmation = false

    let title: String
    let originalText: String
    /// Whether this command offers on-demand explanations (a review-mode option).
    let explainEnabled: Bool

    private let originalAttributedText: NSAttributedString?
    private let targetApplication: NSRunningApplication?
    private let provider: any AIProvider
    private let systemPrompt: String
    private let userPrompt: String
    @ObservationIgnored private var requestTask: Task<Void, Never>?

    /// Called after the result has been applied, so the window can close.
    @ObservationIgnored var onApplied: (() -> Void)?

    /// Only one model request runs at a time; providers keep a single active task.
    var isRequestInFlight: Bool {
        phase == .checking || !explainingHunkIDs.isEmpty || isAnswering
    }

    var hasExplainableHunks: Bool {
        diff?.hunks.contains { $0.explanation == nil } ?? false
    }

    init(
        title: String,
        originalText: String,
        originalAttributedText: NSAttributedString?,
        targetApplication: NSRunningApplication?,
        provider: any AIProvider,
        systemPrompt: String,
        userPrompt: String,
        explainEnabled: Bool
    ) {
        self.title = title
        self.originalText = originalText
        self.originalAttributedText = originalAttributedText
        self.targetApplication = targetApplication
        self.provider = provider
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.explainEnabled = explainEnabled
    }

    // MARK: - Checking

    func start() {
        requestTask?.cancel()
        phase = .checking
        diff = nil
        selectedHunkID = nil
        displayMode = .markup
        followUps = []

        requestTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.requestTask = nil }

            do {
                let output = try await provider.processText(
                    systemPrompt: systemPrompt,
                    userPrompt: userPrompt,
                    images: [],
                    streaming: false
                )
                try Task.checkCancellation()

                if output.trimmingCharacters(in: .whitespacesAndNewlines) == "ERROR_TEXT_INCOMPATIBLE_WITH_REQUEST" {
                    phase = .failed(String(localized: "The selected text couldn't be processed by this command."))
                    return
                }

                let revised = Self.normalizedOutput(output, original: originalText)
                let diff = TextDiff(original: originalText, revised: revised)
                self.diff = diff
                selectedHunkID = diff.hunks.first?.id
                phase = .ready
            } catch is CancellationError {
                return
            } catch {
                logger.error("Review request failed: \(error.localizedDescription)")
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        let wasInFlight = isRequestInFlight
        requestTask?.cancel()
        requestTask = nil
        if wasInFlight {
            provider.cancel()
        }
        explainingHunkIDs = []
        isAnswering = false
    }

    /// Makes the model output comparable to the original: drops a Markdown
    /// fence the model wrapped around the text, and gives the output the same
    /// leading and trailing whitespace as the original so it doesn't show up
    /// as an edit.
    nonisolated static func normalizedOutput(_ output: String, original: String) -> String {
        guard !original.allSatisfy(\.isWhitespace) else { return output }
        var text = output

        let trimmedOutput = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedOutput.hasPrefix("```"),
           trimmedOutput.hasSuffix("```"),
           !original.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") {
            var lines = trimmedOutput.components(separatedBy: .newlines)
            if lines.count >= 2 {
                lines.removeFirst()
                lines.removeLast()
                text = lines.joined(separator: "\n")
            }
        }

        let leading = String(original.prefix { $0.isWhitespace })
        let trailing = String(original.reversed().prefix { $0.isWhitespace }.reversed())
        let core = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !core.isEmpty else { return original }
        return leading + core + trailing
    }

    // MARK: - Decisions

    /// Records a decision and moves the selection to the next pending edit.
    func decide(_ decision: DiffHunk.Decision, for id: Int) {
        diff?.setDecision(decision, for: id)
        selectedHunkID = diff?.nextPendingHunkID(after: id)
    }

    /// Puts a reviewed edit back to pending and selects it.
    func undoDecision(for id: Int) {
        diff?.setDecision(.pending, for: id)
        selectedHunkID = id
    }

    func setAllDecisions(_ decision: DiffHunk.Decision) {
        diff?.setAllDecisions(decision)
        selectedHunkID = decision == .pending ? diff?.hunks.first?.id : nil
    }

    func selectNextHunk(forward: Bool) {
        guard let hunks = diff?.hunks, !hunks.isEmpty else { return }
        guard let current = selectedHunkID else {
            selectedHunkID = forward ? hunks.first?.id : hunks.last?.id
            return
        }
        let next = forward ? current + 1 : current - 1
        selectedHunkID = min(max(next, 0), hunks.count - 1)
    }

    // MARK: - Output

    var resultText: String {
        diff?.resultText() ?? originalText
    }

    func apply() {
        guard let diff, phase == .ready else { return }
        AppState.shared.replaceSelectedText(
            applying: diff,
            originalAttributedText: originalAttributedText,
            targetApplication: targetApplication
        )
        onApplied?()
    }

    func copyResult() {
        let pasteboard = NSPasteboard.general
        pasteboard.prepareForNewContents(with: [])
        pasteboard.writeObjects([resultText as NSString])

        showCopyConfirmation = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.showCopyConfirmation = false
        }
    }

    // MARK: - Explanations

    func explain(hunkIDs requestedIDs: [Int]) {
        guard explainEnabled, !isRequestInFlight, let diff else { return }
        let ids = requestedIDs.filter { diff.hunks[safe: $0]?.explanation == nil }
        guard !ids.isEmpty else { return }

        explainingHunkIDs = Set(ids)
        let language = AppSettings.shared.resolvedExplanationLanguage

        requestTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.explainingHunkIDs = []
                self.requestTask = nil
            }

            do {
                let output = try await provider.processText(
                    systemPrompt: EditExplanationPrompt.systemPrompt(language: language),
                    userPrompt: EditExplanationPrompt.userPrompt(for: diff, hunkIDs: ids),
                    images: [],
                    streaming: false
                )
                try Task.checkCancellation()

                let explanations = EditExplanationPrompt.parse(output)
                    .filter { ids.contains($0.hunkID) }

                if explanations.isEmpty {
                    // Unparseable answer: show it as-is rather than dropping it.
                    let raw = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if ids.count == 1, let id = ids.first {
                        self.diff?.hunks[id].explanation = raw
                    } else {
                        followUps.append(FollowUp(
                            question: String(localized: "Explain all edits"),
                            answer: raw,
                            isStreaming: false
                        ))
                    }
                    return
                }

                for explanation in explanations {
                    self.diff?.hunks[explanation.hunkID].explanation = explanation.text
                    self.diff?.hunks[explanation.hunkID].category = explanation.category
                }
            } catch is CancellationError {
                return
            } catch {
                logger.error("Explanation request failed: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
        }
    }

    func explainAll() {
        guard let diff else { return }
        explain(hunkIDs: diff.hunks.map(\.id))
    }

    // MARK: - Follow-up Questions

    func ask(_ question: String) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard explainEnabled, !trimmed.isEmpty, !isRequestInFlight, let diff else { return }

        // Keep the last few exchanges as context.
        let history = followUps.suffix(5).flatMap { followUp in
            [(role: "user", content: followUp.question), (role: "assistant", content: followUp.answer)]
        }
        let followUp = FollowUp(question: trimmed, answer: "", isStreaming: true)
        let followUpID = followUp.id
        followUps.append(followUp)
        isAnswering = true

        let language = AppSettings.shared.resolvedExplanationLanguage

        requestTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if let index = self.followUps.firstIndex(where: { $0.id == followUpID }) {
                    self.followUps[index].isStreaming = false
                }
                self.isAnswering = false
                self.requestTask = nil
            }

            do {
                var accumulated = ""
                var lastFlush = ContinuousClock.now
                let flushInterval: Duration = .milliseconds(80)

                try await provider.processTextStreaming(
                    systemPrompt: EditExplanationPrompt.followUpSystemPrompt(language: language),
                    userPrompt: EditExplanationPrompt.followUpUserPrompt(
                        diff: diff,
                        history: history,
                        question: trimmed
                    ),
                    images: []
                ) { [weak self] chunk in
                    guard let self else { return }
                    accumulated += chunk
                    let now = ContinuousClock.now
                    if now - lastFlush >= flushInterval,
                       let index = self.followUps.firstIndex(where: { $0.id == followUpID }) {
                        self.followUps[index].answer = accumulated
                        lastFlush = now
                    }
                }

                if let index = followUps.firstIndex(where: { $0.id == followUpID }) {
                    followUps[index].answer = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } catch is CancellationError {
                return
            } catch {
                logger.error("Follow-up request failed: \(error.localizedDescription)")
                followUps.removeAll { $0.id == followUpID }
                errorMessage = error.localizedDescription
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
