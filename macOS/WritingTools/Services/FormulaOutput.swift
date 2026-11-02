import Foundation

/// Turns a model's formula transcription into Markdown that the preview can
/// render without blank formulas.
///
/// The preview renderer (SwiftMath) only knows a subset of LaTeX and shows
/// nothing for a formula it cannot parse. So every formula is rewritten to
/// equivalent supported commands and validated; one that still fails is shown
/// as its source instead. The text to copy is kept separate and is never
/// rewritten.
enum FormulaOutput {
    struct Failure: Equatable {
        let latex: String
        let message: String
    }

    struct Prepared: Equatable {
        /// What the user copies: the transcription with code fences removed.
        let source: String
        /// What the preview renders: formulas rewritten, unrenderable ones as code.
        let preview: String
        let failures: [Failure]
    }

    /// Returns the parser error for a formula body, or nil when it can be rendered.
    typealias Validator = (String) -> String?

    static func prepare(_ raw: String, validate: Validator) -> Prepared {
        let source = wrappedIfBareLaTeX(stripCodeFence(raw))
        let (preview, failures) = renderable(source, validate: validate)
        return Prepared(source: source, preview: preview, failures: failures)
    }

    // MARK: - Cleaning

    /// Removes a surrounding ``` fence, which models add despite being told not to.
    static func stripCodeFence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```"), trimmed.hasSuffix("```") else { return trimmed }

        var lines = trimmed.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return trimmed }
        lines.removeFirst()
        lines.removeLast()
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A reply that is a formula with no math delimiters at all is wrapped in
    /// `$$`, otherwise it would render as plain text.
    static func wrappedIfBareLaTeX(_ text: String) -> String {
        guard mathSegments(in: text).isEmpty, looksLikeLaTeX(text) else { return text }
        return "$$\n\(text)\n$$"
    }

    private static func looksLikeLaTeX(_ text: String) -> Bool {
        text.range(of: #"\\[a-zA-Z]+|[\^_]\{"#, options: .regularExpression) != nil
    }

    // MARK: - Rewriting

    /// Commands the preview renderer rejects, mapped to equivalents it accepts.
    private static let rewrites: [(pattern: String, template: String)] = [
        (#"\\(begin|end)\{(?:align|flalign)\*?\}(?:\{[0-9]+\})?"#, #"\\$1{aligned}"#),
        (#"\\(begin|end)\{gather\*\}"#, #"\\$1{gather}"#),
        (#"\\(begin|end)\{smallmatrix\}"#, #"\\$1{matrix}"#),
        (#"\\(?:boldsymbol|pmb)(?![a-zA-Z])"#, #"\\bm"#),
        (#"\\operatorname\*?\{"#, #"\\mathrm{"#),
        (#"\\(?:mbox|textsf)\{"#, #"\\text{"#),
        (#"\\[dt]frac(?![a-zA-Z])"#, #"\\frac"#),
        (#"\\dots[bcimg]?(?![a-zA-Z])"#, #"\\ldots"#),
        (#"\\[lr]Vert(?![a-zA-Z])"#, #"\\Vert"#),
        (#"\\[lr]vert(?![a-zA-Z])"#, #"\\vert"#),
        (#"\\mathscr(?![a-zA-Z])"#, #"\\mathcal"#),
        (#"\\not\s*="#, #"\\neq"#),
        (#"\\hspace\*?\{[^}]*\}"#, #"\\;"#),
        (#"\\(?:tag|label)\*?\{[^}]*\}"#, ""),
        (#"\\(?:nonumber|notag)(?![a-zA-Z])"#, ""),
    ]

    static func rewriteForPreview(_ latex: String) -> String {
        var result = latex
        for (pattern, template) in rewrites {
            result = result.replacingOccurrences(
                of: pattern, with: template, options: .regularExpression
            )
        }
        return result
    }

    // MARK: - Math segments

    struct MathSegment: Equatable {
        let range: Range<String.Index>
        let opening: String
        let closing: String
        let body: String

        var isDisplay: Bool { opening != "$" && opening != #"\("# }
    }

    private static let segmentExpression: NSRegularExpression = {
        let pattern = #"\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]|\\\(([\s\S]+?)\\\)|(?<![\\$])\$([^$\n]+?)(?<!\\)\$"#
        // The pattern is a constant, so a failure here is a programming error.
        return try! NSRegularExpression(pattern: pattern)
    }()

    private static let delimiters = [("$$", "$$"), (#"\["#, #"\]"#), (#"\("#, #"\)"#), ("$", "$")]

    static func mathSegments(in text: String) -> [MathSegment] {
        let nsRange = NSRange(text.startIndex..., in: text)
        return segmentExpression.matches(in: text, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            for (index, (opening, closing)) in delimiters.enumerated() {
                if let bodyRange = Range(match.range(at: index + 1), in: text) {
                    return MathSegment(
                        range: range, opening: opening, closing: closing,
                        body: String(text[bodyRange])
                    )
                }
            }
            return nil
        }
    }

    /// Rewrites every formula, and replaces those that still fail validation
    /// with their source so nothing renders as blank.
    private static func renderable(
        _ text: String,
        validate: Validator
    ) -> (preview: String, failures: [Failure]) {
        var output = ""
        var cursor = text.startIndex
        var failures: [Failure] = []

        for segment in mathSegments(in: text) {
            output += text[cursor..<segment.range.lowerBound]
            cursor = segment.range.upperBound

            let body = rewriteForPreview(segment.body)
            if let message = validate(body) {
                let latex = segment.body.trimmingCharacters(in: .whitespacesAndNewlines)
                failures.append(Failure(latex: latex, message: message))
                output += segment.isDisplay ? "\n```latex\n\(latex)\n```\n" : "`\(latex)`"
            } else {
                output += segment.opening + body + segment.closing
            }
        }

        output += text[cursor...]
        return (output, failures)
    }
}
