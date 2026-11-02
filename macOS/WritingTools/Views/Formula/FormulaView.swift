import SwiftUI

struct FormulaView: View {
    let viewModel: FormulaViewModel

    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let screenshot = viewModel.screenshot {
                Image(nsImage: screenshot)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 80)
                    .clipShape(.rect(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
                    .accessibilityLabel("Captured screenshot")
            }

            previewSection
            sourceSection
        }
        .padding(16)
        // The ideal size is what the window opens at; without it the window shrinks to fit the content.
        .frame(
            minWidth: 420, idealWidth: 560, maxWidth: .infinity,
            minHeight: 360, idealHeight: 520, maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview")
                .font(.headline)

            Group {
                switch viewModel.phase {
                case .recognizing:
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Recognizing…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .ready:
                    ScrollView {
                        RichMarkdownView(text: viewModel.preview, fontSize: 18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                case .failed(let message):
                    Text(message)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(12)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: .infinity)
            .background(.background.secondary, in: .rect(cornerRadius: 8))

            if !viewModel.failures.isEmpty {
                Text("Some formulas can't be previewed and are shown as source. The source below is unchanged.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Source

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Source")
                    .font(.headline)
                Spacer()
                Button(showCopied ? "Copied" : "Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc") {
                    copySource()
                }
                .disabled(viewModel.phase != .ready)
            }

            ScrollView {
                Text(viewModel.source)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(height: 130)
            .background(.background.secondary, in: .rect(cornerRadius: 8))
        }
    }

    private func copySource() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(viewModel.source, forType: .string)

        showCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            showCopied = false
        }
    }
}
