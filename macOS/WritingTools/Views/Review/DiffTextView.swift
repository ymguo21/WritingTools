import AppKit
import SwiftUI

/// Read-only text view that shows a `TextDiff` inline. In markup mode,
/// pending edits are suggestions (deletions struck through in red, insertions
/// in green), accepted edits show only the new text with a faint green
/// underline, and rejected edits show the original text with a dotted
/// underline. Final and original modes show plain text. Clicking an edit
/// selects it.
struct DiffTextView: NSViewRepresentable {
    let diff: TextDiff
    let selectedHunkID: Int?
    var mode: ReviewViewModel.DisplayMode = .markup
    var fontSize: CGFloat = 14
    let onSelectHunk: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectHunk: onSelectHunk)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true

        if let textView = scrollView.documentView as? NSTextView {
            textView.isEditable = false
            textView.isSelectable = true
            textView.drawsBackground = false
            textView.isRichText = true
            textView.textContainerInset = NSSize(width: 12, height: 12)
            // Keep the diff colours on clickable edits instead of the default link style.
            textView.linkTextAttributes = [.cursor: NSCursor.pointingHand]
            textView.delegate = context.coordinator
            textView.setAccessibilityLabel(String(localized: "Text with suggested edits"))
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.onSelectHunk = onSelectHunk
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let key = Coordinator.RenderKey(diff: diff, selectedHunkID: selectedHunkID, mode: mode, fontSize: fontSize)
        guard context.coordinator.lastRenderKey != key else { return }
        let selectionChanged = context.coordinator.lastRenderKey?.selectedHunkID != selectedHunkID
            || context.coordinator.lastRenderKey?.mode != mode
        context.coordinator.lastRenderKey = key

        let rendering = Self.render(diff: diff, selectedHunkID: selectedHunkID, mode: mode, fontSize: fontSize)
        textView.textStorage?.setAttributedString(rendering.text)

        if selectionChanged, let id = selectedHunkID, let range = rendering.hunkRanges[id] {
            textView.scrollRangeToVisible(range)
        }
    }

    // MARK: - Rendering

    struct Rendering {
        let text: NSAttributedString
        /// Range of each hunk in the rendered text, keyed by hunk id.
        let hunkRanges: [Int: NSRange]
    }

    static func render(
        diff: TextDiff,
        selectedHunkID: Int?,
        mode: ReviewViewModel.DisplayMode = .markup,
        fontSize: CGFloat
    ) -> Rendering {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4

        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ]

        let result = NSMutableAttributedString()
        var hunkRanges: [Int: NSRange] = [:]

        for segment in diff.segments {
            switch segment {
            case .equal(let text):
                result.append(NSAttributedString(string: text, attributes: base))

            case .change(let id):
                let hunk = diff.hunks[id]
                let start = result.length
                var linked = base
                linked[.link] = Coordinator.url(for: id)

                switch (mode, hunk.decision) {
                case (.original, _):
                    result.append(NSAttributedString(string: hunk.oldText, attributes: linked))

                case (.final, _):
                    let text = hunk.isApplied ? hunk.newText : hunk.oldText
                    result.append(NSAttributedString(string: text, attributes: linked))

                case (.markup, .pending):
                    if !hunk.oldText.isEmpty {
                        var removed = linked
                        removed[.foregroundColor] = NSColor.systemRed
                        removed[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                        removed[.strikethroughColor] = NSColor.systemRed
                        result.append(NSAttributedString(string: visibleWhitespace(hunk.oldText), attributes: removed))
                    }
                    if !hunk.newText.isEmpty {
                        var added = linked
                        added[.foregroundColor] = NSColor.systemGreen
                        added[.backgroundColor] = NSColor.systemGreen.withAlphaComponent(0.12)
                        result.append(NSAttributedString(string: visibleWhitespace(hunk.newText), attributes: added))
                    }

                case (.markup, .accepted):
                    // An accepted deletion leaves nothing behind.
                    var applied = linked
                    applied[.underlineStyle] = NSUnderlineStyle.single.rawValue
                    applied[.underlineColor] = NSColor.systemGreen.withAlphaComponent(0.5)
                    result.append(NSAttributedString(string: hunk.newText, attributes: applied))

                case (.markup, .rejected):
                    // A rejected insertion leaves nothing behind.
                    var kept = linked
                    kept[.underlineStyle] = NSUnderlineStyle.single.union(.patternDot).rawValue
                    kept[.underlineColor] = NSColor.secondaryLabelColor
                    result.append(NSAttributedString(string: hunk.oldText, attributes: kept))
                }

                let range = NSRange(location: start, length: result.length - start)
                hunkRanges[id] = range
                if id == selectedHunkID, range.length > 0 {
                    result.addAttribute(
                        .backgroundColor,
                        value: NSColor.controlAccentColor.withAlphaComponent(0.2),
                        range: range
                    )
                }
            }
        }

        return Rendering(text: result, hunkRanges: hunkRanges)
    }

    /// Makes whitespace-only edits visible (e.g. a removed double space).
    static func visibleWhitespace(_ text: String) -> String {
        guard !text.isEmpty, text.allSatisfy(\.isWhitespace) else { return text }
        return text
            .replacingOccurrences(of: " ", with: "␣")
            .replacingOccurrences(of: "\t", with: "⇥")
            .replacingOccurrences(of: "\n", with: "↵\n")
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        struct RenderKey: Equatable {
            let diff: TextDiff
            let selectedHunkID: Int?
            let mode: ReviewViewModel.DisplayMode
            let fontSize: CGFloat
        }

        private static let scheme = "writingtools-review"

        var onSelectHunk: (Int) -> Void
        var lastRenderKey: RenderKey?

        init(onSelectHunk: @escaping (Int) -> Void) {
            self.onSelectHunk = onSelectHunk
        }

        static func url(for hunkID: Int) -> URL? {
            URL(string: "\(scheme)://hunk/\(hunkID)")
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            let url = (link as? URL) ?? (link as? String).flatMap(URL.init(string:))
            guard let url, url.scheme == Self.scheme, let id = Int(url.lastPathComponent) else {
                return false
            }
            onSelectHunk(id)
            return true
        }
    }
}
