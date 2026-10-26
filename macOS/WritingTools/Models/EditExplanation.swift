import Foundation

/// One explanation returned by the model for a reviewed edit.
struct EditExplanation: Equatable {
    let hunkID: Int
    let category: String?
    let text: String
}

/// Builds the prompts for on-demand explanations and follow-up questions
/// in the review window, and parses the model's answer.
enum EditExplanationPrompt {

    // MARK: - Explanations

    static func systemPrompt(language: String) -> String {
        """
        You are a writing tutor. The user's text was corrected by an editor, and you are \
        given numbered edits, each with the sentence it appears in. For each edit, explain \
        in one or two short sentences why the change was made.

        Write the explanations and categories in \(language).

        Respond with one JSON object per line and nothing else, no Markdown and no code fences:
        {"id": <edit number>, "category": "<1-3 word category such as spelling, grammar, punctuation, word choice, fluency or translation>", "explanation": "<explanation>"}
        """
    }

    static func userPrompt(for diff: TextDiff, hunkIDs: [Int]) -> String {
        var lines = ["Edits:", ""]
        for id in hunkIDs where diff.hunks.indices.contains(id) {
            let hunk = diff.hunks[id]
            lines.append("[\(id)] sentence: \(quoted(sentence(containing: hunk, in: diff.original)))")
            lines.append("    change: \(changeDescription(for: hunk))")
        }
        return lines.joined(separator: "\n")
    }

    static func changeDescription(for hunk: DiffHunk) -> String {
        switch hunk.kind {
        case .replacement:
            return "\(quoted(hunk.oldText)) → \(quoted(hunk.newText))"
        case .insertion:
            return "insert \(quoted(hunk.newText))"
        case .deletion:
            return "delete \(quoted(hunk.oldText))"
        }
    }

    // MARK: - Follow-up Questions

    static func followUpSystemPrompt(language: String) -> String {
        """
        You are a writing tutor helping the user understand edits made to their text. \
        Answer the user's question about the edits clearly and concisely, using the \
        original text, the revised text and the list of edits for context. \
        Answer in \(language) unless the user writes in another language. \
        Use Markdown formatting where helpful.
        """
    }

    static func followUpUserPrompt(
        diff: TextDiff,
        history: [(role: String, content: String)],
        question: String
    ) -> String {
        var prompt = """
        Original text:
        \"\"\"
        \(diff.original)
        \"\"\"

        Revised text:
        \"\"\"
        \(diff.revised)
        \"\"\"

        Edits:

        """
        for hunk in diff.hunks {
            prompt += "[\(hunk.id)] \(changeDescription(for: hunk))\n"
        }

        if !history.isEmpty {
            prompt += "\nConversation so far:\n\n"
            for entry in history {
                let role = entry.role == "user" ? "User" : "Assistant"
                prompt += "\(role): \(entry.content)\n\n"
            }
        }

        prompt += "\nUser's question: \(question)"
        return prompt
    }

    // MARK: - Parsing

    /// Parses one JSON object per line. Lines that are not valid objects are
    /// skipped, and a single JSON array of objects is accepted too, so loosely
    /// formatted output from smaller models still yields what it can.
    static func parse(_ response: String) -> [EditExplanation] {
        let trimmed = stripCodeFence(response.trimmingCharacters(in: .whitespacesAndNewlines))

        if trimmed.hasPrefix("["),
           let data = trimmed.data(using: .utf8),
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return array.compactMap(explanation(from:))
        }

        return trimmed
            .components(separatedBy: .newlines)
            .compactMap { line -> EditExplanation? in
                guard let start = line.firstIndex(of: "{"),
                      let end = line.lastIndex(of: "}"),
                      start < end,
                      let data = String(line[start...end]).data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { return nil }
                return explanation(from: object)
            }
    }

    private static func explanation(from object: [String: Any]) -> EditExplanation? {
        let id: Int
        if let number = object["id"] as? Int {
            id = number
        } else if let string = object["id"] as? String, let number = Int(string) {
            id = number
        } else {
            return nil
        }

        guard let text = (object["explanation"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        else { return nil }

        let category = (object["category"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return EditExplanation(
            hunkID: id,
            category: category?.isEmpty == false ? category : nil,
            text: text
        )
    }

    private static func stripCodeFence(_ text: String) -> String {
        guard text.hasPrefix("```") else { return text }
        var lines = text.components(separatedBy: .newlines)
        lines.removeFirst()
        if lines.last?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Context

    /// The sentence (or line) of the original text that contains `hunk`,
    /// capped to a few hundred characters on either side.
    static func sentence(containing hunk: DiffHunk, in original: String) -> String {
        let text = original as NSString
        let maxReach = 300

        var start = hunk.oldRange.location
        while start > 0, hunk.oldRange.location - start < maxReach,
              !isSentenceBoundary(text.character(at: start - 1)) {
            start -= 1
        }

        var end = NSMaxRange(hunk.oldRange)
        while end < text.length, end - NSMaxRange(hunk.oldRange) < maxReach {
            let character = text.character(at: end)
            end += 1
            if isSentenceBoundary(character) { break }
        }

        let range = NSRange(location: start, length: end - start)
        let sentence = text.substring(with: text.rangeOfComposedCharacterSequences(for: range))
        return sentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let sentenceBoundaries = CharacterSet(charactersIn: ".!?\n\u{3002}\u{FF01}\u{FF1F}")

    private static func isSentenceBoundary(_ unit: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(unit) else { return false }
        return sentenceBoundaries.contains(scalar)
    }

    private static func quoted(_ text: String) -> String {
        "\"\(text)\""
    }
}
