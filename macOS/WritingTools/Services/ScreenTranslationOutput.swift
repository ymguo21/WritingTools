import Foundation

/// Splits a Screenshot Translate reply into the recognized text and its translation.
///
/// The model is asked for `<original>…</original><translation>…</translation>`.
/// The reply arrives in pieces, so parsing also works on an unfinished reply:
/// an open block shows what has arrived so far, without half-written tags.
enum ScreenTranslationOutput {
    struct Parsed: Equatable {
        var original: String
        var translation: String
        /// False when the reply did not use the tags and is shown whole as the translation.
        var usedTags: Bool
    }

    private static let originalOpen = "<original>"
    private static let originalClose = "</original>"
    private static let translationOpen = "<translation>"
    private static let translationClose = "</translation>"

    static func parse(_ raw: String, isComplete: Bool) -> Parsed {
        let originalStart = raw.range(of: originalOpen)
        let translationStart = raw.range(of: translationOpen)

        guard originalStart != nil || translationStart != nil else {
            return untagged(raw, isComplete: isComplete)
        }

        var original = ""
        if let start = originalStart {
            let rest = raw[start.upperBound...]
            if let close = rest.range(of: originalClose) {
                original = String(rest[..<close.lowerBound])
            } else if let next = rest.range(of: translationOpen) {
                // The closing tag was left out; the translation starts where the original ends.
                original = String(rest[..<next.lowerBound])
            } else {
                original = withoutPartialTag(String(rest), tags: [originalClose, translationOpen], isComplete: isComplete)
            }
        }

        var translation = ""
        if let start = translationStart {
            let rest = raw[start.upperBound...]
            if let close = rest.range(of: translationClose) {
                translation = String(rest[..<close.lowerBound])
            } else {
                translation = withoutPartialTag(String(rest), tags: [translationClose], isComplete: isComplete)
            }
        }

        return Parsed(
            original: original.trimmingCharacters(in: .whitespacesAndNewlines),
            translation: translation.trimmingCharacters(in: .whitespacesAndNewlines),
            usedTags: true
        )
    }

    /// A reply without tags. While it is still arriving, wait to see whether a tag
    /// is being written; once it is complete, show it whole.
    private static func untagged(_ raw: String, isComplete: Bool) -> Parsed {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if isComplete {
            return Parsed(original: "", translation: FormulaOutput.stripCodeFence(trimmed), usedTags: false)
        }
        if trimmed.isEmpty || trimmed.hasPrefix("<") || trimmed.hasPrefix("`") {
            return Parsed(original: "", translation: "", usedTags: true)
        }
        return Parsed(original: "", translation: trimmed, usedTags: false)
    }

    /// Drops the start of a closing tag that is cut off at the end of the text so far.
    private static func withoutPartialTag(_ text: String, tags: [String], isComplete: Bool) -> String {
        guard !isComplete else { return text }
        for tag in tags {
            for length in stride(from: tag.count - 1, through: 1, by: -1) where text.hasSuffix(String(tag.prefix(length))) {
                return String(text.dropLast(length))
            }
        }
        return text
    }
}
