import SwiftUI

/// Review window content: the text with inline edits on the left, one card
/// per edit on the right, and Apply / Copy at the bottom. Holding Option
/// temporarily shows the original text.
struct ReviewView: View {
    @Bindable var viewModel: ReviewViewModel
    @Bindable private var settings = AppSettings.shared
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var question: String = ""
    @State private var isOptionHeld = false
    @State private var flagsMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
            Divider()
            bottomBar
        }
        .windowBackground(useGradient: settings.useGradientTheme)
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            ),
            presenting: viewModel.errorMessage
        ) { _ in
            Button("OK") { viewModel.errorMessage = nil }
        } message: { message in
            Text(message)
        }
        .onAppear {
            flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                isOptionHeld = event.modifierFlags.contains(.option)
                return event
            }
        }
        .onDisappear {
            if let flagsMonitor {
                NSEvent.removeMonitor(flagsMonitor)
            }
            flagsMonitor = nil
            viewModel.cancel()
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.title)
                    .font(.headline)
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let diff = viewModel.diff, diff.hasChanges {
                if viewModel.explainEnabled {
                    Button {
                        viewModel.explainAll()
                    } label: {
                        Label("Explain All", systemImage: "questionmark.bubble")
                    }
                    .disabled(viewModel.isRequestInFlight || !viewModel.hasExplainableHunks)
                    .help("Explain every edit that has no explanation yet")
                }

                Button("Accept All") { viewModel.setAllDecisions(.accepted) }
                Button("Reject All") { viewModel.setAllDecisions(.rejected) }
            }

            Button {
                viewModel.start()
            } label: {
                Label("Re-check", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .disabled(viewModel.phase == .checking)
            .help("Run the command again")
            .accessibilityLabel("Re-check")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var summaryText: String {
        switch viewModel.phase {
        case .checking:
            return String(localized: "Checking…")
        case .failed:
            return String(localized: "Check failed")
        case .ready:
            guard let diff = viewModel.diff else { return "" }
            if !diff.hasChanges {
                return String(localized: "No changes suggested")
            }
            if diff.pendingCount == 0 {
                return String(localized: "All edits reviewed: \(diff.acceptedCount) accepted, \(diff.rejectedCount) rejected")
            }
            return String(localized: "\(diff.pendingCount) pending · \(diff.acceptedCount) accepted · \(diff.rejectedCount) rejected")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .checking:
            VStack(spacing: 12) {
                ProgressView()
                Text("Checking…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Try Again") { viewModel.start() }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .ready:
            if let diff = viewModel.diff {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        if diff.hasChanges {
                            displayModeBar
                            Divider()
                        }
                        DiffTextView(
                            diff: diff,
                            selectedHunkID: viewModel.selectedHunkID,
                            mode: isOptionHeld ? .original : viewModel.displayMode,
                            onSelectHunk: { viewModel.selectedHunkID = $0 }
                        )
                    }
                    .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    sidebar(diff: diff)
                        .frame(width: 300)
                }
            }
        }
    }

    private var displayModeBar: some View {
        HStack(spacing: 8) {
            Picker("View", selection: $viewModel.displayMode) {
                Text("Markup").tag(ReviewViewModel.DisplayMode.markup)
                Text("Final").tag(ReviewViewModel.DisplayMode.final)
                Text("Original").tag(ReviewViewModel.DisplayMode.original)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help("Markup shows the suggested edits, Final the text Apply writes back, Original the selected text")

            Spacer()

            Text(isOptionHeld ? "Showing the original" : "Hold ⌥ to see the original")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func sidebar(diff: TextDiff) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if !diff.hasChanges {
                        Text("The text looks good. There is nothing to change.")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }

                    ForEach(diff.hunks) { hunk in
                        HunkCardView(
                            hunk: hunk,
                            isSelected: viewModel.selectedHunkID == hunk.id,
                            explainEnabled: viewModel.explainEnabled,
                            isExplaining: viewModel.explainingHunkIDs.contains(hunk.id),
                            canExplain: !viewModel.isRequestInFlight,
                            onSelect: { viewModel.selectedHunkID = hunk.id },
                            onAccept: { viewModel.decide(.accepted, for: hunk.id) },
                            onReject: { viewModel.decide(.rejected, for: hunk.id) },
                            onUndo: { viewModel.undoDecision(for: hunk.id) },
                            onExplain: { viewModel.explain(hunkIDs: [hunk.id]) }
                        )
                        .id(hunk.id)
                    }

                    if !viewModel.followUps.isEmpty {
                        Text("Questions")
                            .font(.headline)
                            .padding(.top, 8)

                        ForEach(viewModel.followUps) { followUp in
                            FollowUpView(followUp: followUp)
                        }
                    }
                }
                .padding(12)
            }
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(keys: [.upArrow, .downArrow, .tab, .return, .delete]) { press in
                handleKeyPress(press)
            }
            .onChange(of: viewModel.selectedHunkID) { _, newValue in
                guard let newValue else { return }
                if reduceMotion {
                    proxy.scrollTo(newValue, anchor: .center)
                } else {
                    withAnimation { proxy.scrollTo(newValue, anchor: .center) }
                }
            }
        }
    }

    /// ↑/↓ or Tab/⇧Tab move between edits, Return accepts, Delete rejects;
    /// both then jump to the next pending edit.
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .downArrow:
            viewModel.selectNextHunk(forward: true)
        case .upArrow:
            viewModel.selectNextHunk(forward: false)
        case .tab:
            viewModel.selectNextHunk(forward: !press.modifiers.contains(.shift))
        case .return:
            guard let id = viewModel.selectedHunkID else { return .ignored }
            viewModel.decide(.accepted, for: id)
        case .delete:
            guard let id = viewModel.selectedHunkID else { return .ignored }
            viewModel.decide(.rejected, for: id)
        default:
            return .ignored
        }
        return .handled
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if viewModel.explainEnabled {
                TextField("Ask about these edits…", text: $question)
                    .textFieldStyle(.plain)
                    .appleStyleTextField(
                        text: question,
                        isLoading: viewModel.isAnswering,
                        onSubmit: askQuestion
                    )
                    .disabled(viewModel.phase != .ready || viewModel.isRequestInFlight)
                    .accessibilityLabel("Question about the edits")
            } else {
                Spacer()
            }

            Button {
                viewModel.copyResult()
            } label: {
                Label(viewModel.showCopyConfirmation ? "Copied!" : "Copy",
                      systemImage: viewModel.showCopyConfirmation ? "checkmark" : "doc.on.doc")
            }
            .disabled(viewModel.phase != .ready)
            .help("Copy the text with the accepted edits")

            Button {
                viewModel.apply()
            } label: {
                Text(applyTitle)
                    .frame(minWidth: 60)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(viewModel.phase != .ready || viewModel.diff?.hasChanges != true)
            .help("Replace the selection with the accepted and pending edits (⌘↩)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var applyTitle: String {
        let pending = viewModel.diff?.pendingCount ?? 0
        guard viewModel.phase == .ready, pending > 0 else { return String(localized: "Apply") }
        return String(localized: "Apply (incl. \(pending) pending)")
    }

    private func askQuestion() {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !viewModel.isRequestInFlight else { return }
        question = ""
        viewModel.ask(text)
    }
}

// MARK: - Hunk Card

private struct HunkCardView: View {
    let hunk: DiffHunk
    let isSelected: Bool
    let explainEnabled: Bool
    let isExplaining: Bool
    let canExplain: Bool
    let onSelect: () -> Void
    let onAccept: () -> Void
    let onReject: () -> Void
    let onUndo: () -> Void
    let onExplain: () -> Void

    var body: some View {
        Group {
            if hunk.decision == .pending {
                expandedContent
            } else {
                reviewedContent
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(.controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                              lineWidth: isSelected ? 2 : 1)
        )
        .opacity(hunk.decision == .pending || isSelected ? 1 : 0.7)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityDescription)
    }

    /// A reviewed edit collapses to one line with its outcome and Undo.
    private var reviewedContent: some View {
        HStack(spacing: 6) {
            Image(systemName: hunk.decision == .accepted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(hunk.decision == .accepted ? Color.green : Color.red)

            Text(hunk.decision == .accepted ? "Accepted" : "Rejected")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            changeText
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Undo", action: onUndo)
                .buttonStyle(.link)
                .font(.caption)
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            changeText
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                if let category = hunk.category {
                    Text(category)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(.capsule)
                }

                Spacer()

                if explainEnabled && hunk.explanation == nil {
                    if isExplaining {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Explain", action: onExplain)
                            .buttonStyle(.link)
                            .font(.caption)
                            .disabled(!canExplain)
                    }
                }

                decisionButton(
                    systemImage: "checkmark",
                    isOn: hunk.decision == .accepted,
                    tint: .green,
                    label: "Accept edit",
                    action: onAccept
                )
                decisionButton(
                    systemImage: "xmark",
                    isOn: hunk.decision == .rejected,
                    tint: .red,
                    label: "Reject edit",
                    action: onReject
                )
            }

            if let explanation = hunk.explanation {
                Text(explanation)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var changeText: Text {
        let old = DiffTextView.visibleWhitespace(hunk.oldText)
        let new = DiffTextView.visibleWhitespace(hunk.newText)
        switch hunk.kind {
        case .replacement:
            return Text(old).foregroundStyle(.red).strikethrough()
                + Text(" → ").foregroundStyle(.secondary)
                + Text(new).foregroundStyle(.green)
        case .insertion:
            return Text("+ ").foregroundStyle(.secondary) + Text(new).foregroundStyle(.green)
        case .deletion:
            return Text("− ").foregroundStyle(.secondary) + Text(old).foregroundStyle(.red).strikethrough()
        }
    }

    private var accessibilityDescription: String {
        let state = switch hunk.decision {
        case .pending: String(localized: "pending")
        case .accepted: String(localized: "accepted")
        case .rejected: String(localized: "rejected")
        }
        switch hunk.kind {
        case .replacement:
            return String(localized: "Replace \(hunk.oldText) with \(hunk.newText), \(state)")
        case .insertion:
            return String(localized: "Insert \(hunk.newText), \(state)")
        case .deletion:
            return String(localized: "Delete \(hunk.oldText), \(state)")
        }
    }

    private func decisionButton(
        systemImage: String,
        isOn: Bool,
        tint: Color,
        label: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isOn ? Color.white : tint)
                .frame(width: 22, height: 22)
                .background(isOn ? tint : tint.opacity(0.15))
                .clipShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Follow-up

private struct FollowUpView: View {
    let followUp: ReviewViewModel.FollowUp

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(followUp.question)
                .font(.callout.weight(.semibold))
                .textSelection(.enabled)

            if followUp.isStreaming {
                if followUp.answer.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(followUp.answer)
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                RichMarkdownView(text: followUp.answer, fontSize: 13)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.controlBackgroundColor).opacity(0.6))
        )
    }
}
