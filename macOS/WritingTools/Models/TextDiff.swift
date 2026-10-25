import Foundation

// MARK: - Tokenizer

/// A piece of text produced by `WordTokenizer`.
/// Tokens always concatenate back to the exact input string.
struct TextToken: Equatable {
    enum Kind: Equatable {
        case word
        case whitespace
        case punctuation
    }

    let text: String
    let kind: Kind
}

/// Splits text into word, whitespace and punctuation tokens.
///
/// Word boundaries come from Foundation's Unicode word segmentation
/// (`enumerateSubstrings(options: .byWords)`), so scripts written without
/// spaces are segmented by the system rather than by custom language rules.
enum WordTokenizer {
    static func tokenize(_ text: String) -> [TextToken] {
        guard !text.isEmpty else { return [] }

        var tokens: [TextToken] = []
        var cursor = text.startIndex

        text.enumerateSubstrings(
            in: text.startIndex..<text.endIndex,
            options: [.byWords, .substringNotRequired]
        ) { _, wordRange, _, _ in
            if cursor < wordRange.lowerBound {
                appendGap(text[cursor..<wordRange.lowerBound], to: &tokens)
            }
            tokens.append(TextToken(text: String(text[wordRange]), kind: .word))
            cursor = wordRange.upperBound
        }

        if cursor < text.endIndex {
            appendGap(text[cursor...], to: &tokens)
        }

        return tokens
    }

    /// Splits the text between two words into whitespace runs and single
    /// punctuation characters.
    private static func appendGap(_ gap: Substring, to tokens: inout [TextToken]) {
        var whitespace = ""
        for character in gap {
            if character.isWhitespace {
                whitespace.append(character)
                continue
            }
            if !whitespace.isEmpty {
                tokens.append(TextToken(text: whitespace, kind: .whitespace))
                whitespace = ""
            }
            tokens.append(TextToken(text: String(character), kind: .punctuation))
        }
        if !whitespace.isEmpty {
            tokens.append(TextToken(text: whitespace, kind: .whitespace))
        }
    }
}

// MARK: - Diff Model

/// One reviewable change between the original and the revised text.
struct DiffHunk: Identifiable, Equatable {
    enum Kind: Equatable {
        case replacement
        case insertion
        case deletion
    }

    enum Decision: Equatable {
        /// Not reviewed yet. Applied like an accepted edit.
        case pending
        case accepted
        case rejected
    }

    /// Position of the hunk in `TextDiff.hunks`.
    let id: Int
    let oldText: String
    let newText: String
    /// UTF-16 range of `oldText` inside the original string.
    let oldRange: NSRange

    var decision: Decision = .pending
    /// Short label returned by an on-demand explanation (e.g. "spelling").
    var category: String?
    var explanation: String?

    /// Whether the edit ends up in the result. Pending edits count as accepted.
    var isApplied: Bool { decision != .rejected }

    var kind: Kind {
        if oldText.isEmpty { return .insertion }
        if newText.isEmpty { return .deletion }
        return .replacement
    }
}

enum DiffSegment: Equatable {
    /// Text that is the same in the original and the revision.
    case equal(String)
    /// A change; the associated value is the hunk's id.
    case change(Int)
}

/// Word-level diff between an original text and a revision, with a
/// per-hunk pending/accept/reject decision.
struct TextDiff: Equatable {
    let original: String
    let revised: String
    let segments: [DiffSegment]
    var hunks: [DiffHunk]

    var hasChanges: Bool { !hunks.isEmpty }

    var acceptedCount: Int {
        hunks.filter { $0.decision == .accepted }.count
    }

    var rejectedCount: Int {
        hunks.filter { $0.decision == .rejected }.count
    }

    var pendingCount: Int {
        hunks.filter { $0.decision == .pending }.count
    }

    init(original: String, revised: String) {
        self.original = original
        self.revised = revised

        let pieces = Self.cleanedUp(Self.rawPieces(original: original, revised: revised))

        var segments: [DiffSegment] = []
        var hunks: [DiffHunk] = []
        var location = 0
        for piece in pieces {
            switch piece {
            case .equal(let text):
                segments.append(.equal(text))
                location += text.utf16.count
            case .change(let oldText, let newText):
                let length = oldText.utf16.count
                let hunk = DiffHunk(
                    id: hunks.count,
                    oldText: oldText,
                    newText: newText,
                    oldRange: NSRange(location: location, length: length)
                )
                segments.append(.change(hunk.id))
                hunks.append(hunk)
                location += length
            }
        }

        self.segments = segments
        self.hunks = hunks
    }

    /// The text that results from the current decisions.
    func resultText() -> String {
        var result = ""
        for segment in segments {
            switch segment {
            case .equal(let text):
                result += text
            case .change(let id):
                let hunk = hunks[id]
                result += hunk.isApplied ? hunk.newText : hunk.oldText
            }
        }
        return result
    }

    mutating func setDecision(_ decision: DiffHunk.Decision, for id: Int) {
        guard hunks.indices.contains(id) else { return }
        hunks[id].decision = decision
    }

    mutating func setAllDecisions(_ decision: DiffHunk.Decision) {
        for index in hunks.indices {
            hunks[index].decision = decision
        }
    }

    /// The first pending hunk after `id`, wrapping around to the start;
    /// nil once every hunk has been reviewed.
    func nextPendingHunkID(after id: Int?) -> Int? {
        let pending = hunks.filter { $0.decision == .pending }.map(\.id)
        guard let id else { return pending.first }
        return pending.first { $0 > id } ?? pending.first
    }

    // MARK: - Building

    private enum Piece: Equatable {
        case equal(String)
        case change(old: String, new: String)
    }

    /// Myers diff over tokens, grouped into alternating equal/change pieces.
    private static func rawPieces(original: String, revised: String) -> [Piece] {
        let oldTokens = WordTokenizer.tokenize(original).map(\.text)
        let newTokens = WordTokenizer.tokenize(revised).map(\.text)
        let difference = newTokens.difference(from: oldTokens)

        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in difference {
            switch change {
            case .remove(let offset, _, _):
                removed.insert(offset)
            case .insert(let offset, _, _):
                inserted.insert(offset)
            }
        }

        var pieces: [Piece] = []
        var oldIndex = 0
        var newIndex = 0

        func append(_ piece: Piece) {
            switch (pieces.last, piece) {
            case (.equal(let previous)?, .equal(let next)):
                pieces[pieces.count - 1] = .equal(previous + next)
            case (.change(let previousOld, let previousNew)?, .change(let nextOld, let nextNew)):
                pieces[pieces.count - 1] = .change(old: previousOld + nextOld, new: previousNew + nextNew)
            default:
                pieces.append(piece)
            }
        }

        while oldIndex < oldTokens.count || newIndex < newTokens.count {
            let oldChanged = oldIndex < oldTokens.count && removed.contains(oldIndex)
            let newChanged = newIndex < newTokens.count && inserted.contains(newIndex)

            if oldChanged || newChanged {
                var oldText = ""
                var newText = ""
                while oldIndex < oldTokens.count, removed.contains(oldIndex) {
                    oldText += oldTokens[oldIndex]
                    oldIndex += 1
                }
                while newIndex < newTokens.count, inserted.contains(newIndex) {
                    newText += newTokens[newIndex]
                    newIndex += 1
                }
                append(.change(old: oldText, new: newText))
            } else if oldIndex < oldTokens.count, newIndex < newTokens.count {
                // Unchanged tokens on both sides are the common subsequence, in order.
                append(.equal(oldTokens[oldIndex]))
                oldIndex += 1
                newIndex += 1
            } else {
                // Defensive: should be unreachable for a valid difference.
                let oldRest = oldTokens[oldIndex...].joined()
                let newRest = newTokens[newIndex...].joined()
                append(.change(old: oldRest, new: newRest))
                oldIndex = oldTokens.count
                newIndex = newTokens.count
            }
        }

        return pieces
    }

    /// Absorbs short single-line equalities that sit between two changes, so
    /// "Their was" → "There were" reads as one edit instead of two.
    /// An equality is absorbed when it is no longer than the larger side of
    /// the change on each side of it.
    private static func cleanedUp(_ pieces: [Piece]) -> [Piece] {
        var pieces = pieces
        var index = 1
        while index < pieces.count - 1 {
            guard
                case .change(let leftOld, let leftNew) = pieces[index - 1],
                case .equal(let equality) = pieces[index],
                case .change(let rightOld, let rightNew) = pieces[index + 1]
            else {
                index += 1
                continue
            }

            let equalityLength = equality.count
            let leftLength = max(leftOld.count, leftNew.count)
            let rightLength = max(rightOld.count, rightNew.count)
            let isSingleLine = !equality.contains(where: \.isNewline)

            if isSingleLine && equalityLength <= leftLength && equalityLength <= rightLength {
                let merged = Piece.change(
                    old: leftOld + equality + rightOld,
                    new: leftNew + equality + rightNew
                )
                pieces.replaceSubrange((index - 1)...(index + 1), with: [merged])
                // Re-check the previous triple, which may now qualify.
                index = max(1, index - 1)
            } else {
                index += 1
            }
        }
        return pieces
    }
}

// MARK: - Attributed Application

extension NSMutableAttributedString {
    /// Applies the accepted and pending hunks of `diff` one by one, from the end of the
    /// string to the start, so formatting between separate edits is kept.
    /// Each replacement takes the attributes of the text it replaces.
    /// The receiver's string must equal `diff.original`.
    @discardableResult
    func applyAcceptedHunks(of diff: TextDiff) -> Bool {
        guard string == diff.original else { return false }

        for hunk in diff.hunks.reversed() where hunk.isApplied {
            let range = hunk.oldRange
            guard NSMaxRange(range) <= length else { return false }

            let attributes: [NSAttributedString.Key: Any]
            if range.length > 0 {
                attributes = self.attributes(at: range.location, effectiveRange: nil)
            } else if range.location > 0 {
                attributes = self.attributes(at: range.location - 1, effectiveRange: nil)
            } else if length > 0 {
                attributes = self.attributes(at: 0, effectiveRange: nil)
            } else {
                attributes = [:]
            }

            replaceCharacters(
                in: range,
                with: NSAttributedString(string: hunk.newText, attributes: attributes)
            )
        }

        return string == diff.resultText()
    }
}
