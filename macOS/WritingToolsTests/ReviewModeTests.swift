import XCTest
@testable import WritingTools

final class ReviewModeTests: XCTestCase {

    // MARK: - Model output normalization

    func testOutputGetsOriginalSurroundingWhitespace() {
        XCTAssertEqual(
            ReviewViewModel.normalizedOutput("Fixed text.\n", original: "Fixd text."),
            "Fixed text."
        )
        XCTAssertEqual(
            ReviewViewModel.normalizedOutput("Fixed text.", original: "  Fixd text.\n\n"),
            "  Fixed text.\n\n"
        )
    }

    func testOutputFenceIsRemovedUnlessOriginalWasFenced() {
        XCTAssertEqual(
            ReviewViewModel.normalizedOutput("```\nFixed text.\n```", original: "Fixd text."),
            "Fixed text."
        )
        XCTAssertEqual(
            ReviewViewModel.normalizedOutput("```\ncode\n```", original: "```\ncod\n```"),
            "```\ncode\n```"
        )
    }

    func testEmptyOutputFallsBackToOriginal() {
        XCTAssertEqual(ReviewViewModel.normalizedOutput("  \n", original: "Keep me."), "Keep me.")
    }

    // MARK: - Explanation parsing

    func testParsesOneObjectPerLine() {
        let response = """
        {"id": 0, "category": "spelling", "explanation": "'teh' is a typo."}
        {"id": 2, "category": "grammar", "explanation": "Plural subject needs 'were'."}
        """
        let parsed = EditExplanationPrompt.parse(response)
        XCTAssertEqual(parsed, [
            EditExplanation(hunkID: 0, category: "spelling", text: "'teh' is a typo."),
            EditExplanation(hunkID: 2, category: "grammar", text: "Plural subject needs 'were'."),
        ])
    }

    func testParsesFencedArrayAndStringIDs() {
        let response = """
        ```json
        [{"id": "1", "explanation": "Translated into English."}]
        ```
        """
        let parsed = EditExplanationPrompt.parse(response)
        XCTAssertEqual(parsed, [EditExplanation(hunkID: 1, category: nil, text: "Translated into English.")])
    }

    func testSkipsUnparseableLines() {
        let response = """
        Here are the explanations:
        {"id": 0, "explanation": "Fine."}
        {"id": "x", "explanation": "Bad id."}
        {"id": 3}
        """
        let parsed = EditExplanationPrompt.parse(response)
        XCTAssertEqual(parsed.map(\.hunkID), [0])
    }

    // MARK: - Explanation prompt

    func testUserPromptListsRequestedEditsWithTheirSentence() {
        let diff = TextDiff(
            original: "This is fine. Their was five apples. Also fine.",
            revised: "This is fine. There were five apples. Also fine."
        )
        let prompt = EditExplanationPrompt.userPrompt(for: diff, hunkIDs: [0])

        XCTAssertTrue(prompt.contains("[0] sentence: \"Their was five apples.\""), prompt)
        XCTAssertTrue(prompt.contains("change: \"Their was\" → \"There were\""), prompt)
        XCTAssertFalse(prompt.contains("This is fine."))
    }

    func testSystemPromptNamesLanguage() {
        XCTAssertTrue(EditExplanationPrompt.systemPrompt(language: "Simplified Chinese").contains("Simplified Chinese"))
    }

    // MARK: - Explanation language

    func testExplanationLanguageUsesSettingOrInterfaceLanguage() {
        XCTAssertEqual(
            AppSettings.resolveExplanationLanguage(" Japanese ", interfaceLanguageCode: "de"),
            "Japanese"
        )
        XCTAssertEqual(
            AppSettings.resolveExplanationLanguage("", interfaceLanguageCode: "de"),
            "German"
        )
    }

    // MARK: - New built-in migration

    func testMissingBuiltInIsInsertedAfterItsPredecessor() {
        let custom = CommandModel(name: "Mine", prompt: "p", icon: "pencil")
        let existing = [CommandModel.proofread, CommandModel.rewrite, custom]

        let result = CommandManager.addingMissingBuiltIns(
            to: existing,
            from: [CommandModel.grammarCheck],
            deletedIds: []
        )

        XCTAssertEqual(result.map(\.id), [
            CommandModel.BuiltInID.proofread,
            CommandModel.BuiltInID.grammarCheck,
            CommandModel.BuiltInID.rewrite,
            custom.id,
        ])
    }

    func testTranslateIsInsertedAfterGrammarCheck() {
        let custom = CommandModel(name: "Mine", prompt: "p", icon: "pencil")
        let result = CommandManager.addingMissingBuiltIns(
            to: [CommandModel.proofread, CommandModel.rewrite, custom],
            from: CommandModel.builtInsAddedAfterFirstRelease,
            deletedIds: []
        )
        XCTAssertEqual(result.map(\.id), [
            CommandModel.BuiltInID.proofread,
            CommandModel.BuiltInID.grammarCheck,
            CommandModel.BuiltInID.translate,
            CommandModel.BuiltInID.rewrite,
            custom.id,
        ])
    }

    func testMissingBuiltInIsAppendedWhenPredecessorIsGone() {
        let custom = CommandModel(name: "Mine", prompt: "p", icon: "pencil")
        let result = CommandManager.addingMissingBuiltIns(
            to: [custom],
            from: [CommandModel.grammarCheck],
            deletedIds: []
        )
        XCTAssertEqual(result.map(\.id), [custom.id, CommandModel.BuiltInID.grammarCheck])
    }

    func testDeletedOrExistingBuiltInIsNotAddedAgain() {
        let deleted = CommandManager.addingMissingBuiltIns(
            to: [CommandModel.proofread],
            from: [CommandModel.grammarCheck],
            deletedIds: [CommandModel.BuiltInID.grammarCheck]
        )
        XCTAssertEqual(deleted.map(\.id), [CommandModel.BuiltInID.proofread])

        var edited = CommandModel.grammarCheck
        edited.name = "My Grammar"
        let existing = CommandManager.addingMissingBuiltIns(
            to: [edited],
            from: [CommandModel.grammarCheck],
            deletedIds: []
        )
        XCTAssertEqual(existing.count, 1)
        XCTAssertEqual(existing.first?.name, "My Grammar")
    }
}
