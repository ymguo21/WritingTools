import SwiftUI

struct ScreenTranslationView: View {
    let viewModel: ScreenTranslationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if case .failed(let message) = viewModel.phase {
                Text(message)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TextPane(
                    title: "Original",
                    text: viewModel.original,
                    waitingMessage: "Recognizing…",
                    emptyMessage: viewModel.separatedOriginal ? "" : "The original text could not be separated from the reply.",
                    isWorking: viewModel.phase == .working
                )
                TextPane(
                    title: "Translation",
                    text: viewModel.translation,
                    waitingMessage: "Translating…",
                    emptyMessage: "",
                    isWorking: viewModel.phase == .working
                )
            }
        }
        .padding(16)
        // The ideal size is what the window opens at; without it the window shrinks to fit the content.
        .frame(
            minWidth: 420, idealWidth: 600, maxWidth: .infinity,
            minHeight: 360, idealHeight: 560, maxHeight: .infinity,
            alignment: .topLeading
        )
    }
}

/// A titled, selectable block of text with a Copy button.
private struct TextPane: View {
    let title: LocalizedStringKey
    let text: String
    let waitingMessage: LocalizedStringKey
    let emptyMessage: LocalizedStringKey
    let isWorking: Bool

    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(showCopied ? "Copied" : "Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc") {
                    copy()
                }
                .disabled(text.isEmpty)
            }

            ScrollView {
                if text.isEmpty {
                    if isWorking {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(waitingMessage)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                    } else {
                        Text(emptyMessage)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                } else {
                    Text(text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 90, maxHeight: .infinity)
            .background(.background.secondary, in: .rect(cornerRadius: 8))
        }
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        showCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            showCopied = false
        }
    }
}
