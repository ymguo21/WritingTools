import XCTest
@testable import WritingTools

final class CommandModelCodingTests: XCTestCase {

    // MARK: - Round-trip tests

    func testMinimalCommandRoundTrip() throws {
        let original = CommandModel(
            name: "Test",
            prompt: "Do something",
            icon: "pencil"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CommandModel.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.prompt, original.prompt)
        XCTAssertEqual(decoded.icon, original.icon)
        XCTAssertFalse(decoded.useResponseWindow)
        XCTAssertFalse(decoded.isBuiltIn)
        XCTAssertFalse(decoded.hasShortcut)
        XCTAssertFalse(decoded.preserveFormatting)
        XCTAssertNil(decoded.providerOverride)
        XCTAssertNil(decoded.modelOverride)
        XCTAssertNil(decoded.customProviderBaseURL)
        XCTAssertNil(decoded.customProviderModel)
    }

    func testFullyPopulatedCommandRoundTrip() throws {
        let id = UUID()
        let original = CommandModel(
            id: id,
            name: "Full Command",
            prompt: "Do everything",
            icon: "star",
            useResponseWindow: true,
            isBuiltIn: true,
            hasShortcut: true,
            preserveFormatting: true,
            providerOverride: "openai",
            modelOverride: "gpt-4o",
            customProviderBaseURL: "https://api.example.com",
            customProviderModel: "custom-model"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CommandModel.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.name, "Full Command")
        XCTAssertEqual(decoded.prompt, "Do everything")
        XCTAssertEqual(decoded.icon, "star")
        XCTAssertTrue(decoded.useResponseWindow)
        XCTAssertTrue(decoded.isBuiltIn)
        XCTAssertTrue(decoded.hasShortcut)
        XCTAssertTrue(decoded.preserveFormatting)
        XCTAssertEqual(decoded.providerOverride, "openai")
        XCTAssertEqual(decoded.modelOverride, "gpt-4o")
        XCTAssertEqual(decoded.customProviderBaseURL, "https://api.example.com")
        XCTAssertEqual(decoded.customProviderModel, "custom-model")
    }

    func testArrayRoundTrip() throws {
        let commands = [
            CommandModel(name: "A", prompt: "a", icon: "a.circle"),
            CommandModel(name: "B", prompt: "b", icon: "b.circle", useResponseWindow: true),
        ]

        let data = try JSONEncoder().encode(commands)
        let decoded = try JSONDecoder().decode([CommandModel].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].name, "A")
        XCTAssertEqual(decoded[1].name, "B")
        XCTAssertTrue(decoded[1].useResponseWindow)
    }

    // MARK: - Compact encoding (false booleans are omitted)

    func testFalseBoolsAreOmittedFromEncoding() throws {
        let command = CommandModel(
            name: "Compact",
            prompt: "test",
            icon: "pencil"
        )

        let data = try JSONEncoder().encode(command)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // False boolean fields should be omitted for compact storage
        XCTAssertNil(json?["useResponseWindow"])
        XCTAssertNil(json?["isBuiltIn"])
        XCTAssertNil(json?["hasShortcut"])
        XCTAssertNil(json?["preserveFormatting"])
        // Nil optionals should also be omitted
        XCTAssertNil(json?["providerOverride"])
        XCTAssertNil(json?["modelOverride"])
        XCTAssertNil(json?["customProviderBaseURL"])
        XCTAssertNil(json?["customProviderModel"])
    }

    func testTrueBoolsArePresent() throws {
        let command = CommandModel(
            name: "Full",
            prompt: "test",
            icon: "pencil",
            useResponseWindow: true,
            isBuiltIn: true,
            hasShortcut: true,
            preserveFormatting: true
        )

        let data = try JSONEncoder().encode(command)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["useResponseWindow"] as? Bool, true)
        XCTAssertEqual(json?["isBuiltIn"] as? Bool, true)
        XCTAssertEqual(json?["hasShortcut"] as? Bool, true)
        XCTAssertEqual(json?["preserveFormatting"] as? Bool, true)
    }

    // MARK: - Legacy data compatibility

    func testLegacyApiKeyFieldIsIgnoredDuringDecoding() throws {
        // Simulate JSON from an older version that included customProviderApiKey
        let legacyJSON: [String: Any] = [
            "id": UUID().uuidString,
            "name": "Legacy",
            "prompt": "test",
            "icon": "pencil",
            "customProviderApiKey": "sk-secret-key",
        ]

        let data = try JSONSerialization.data(withJSONObject: legacyJSON)
        // Should decode without error — the legacy key is silently consumed
        let decoded = try JSONDecoder().decode(CommandModel.self, from: data)
        XCTAssertEqual(decoded.name, "Legacy")
    }

    func testMissingOptionalBoolsDefaultToFalse() throws {
        // Minimal JSON with only required fields
        let minimalJSON: [String: Any] = [
            "id": UUID().uuidString,
            "name": "Minimal",
            "prompt": "test",
            "icon": "pencil",
        ]

        let data = try JSONSerialization.data(withJSONObject: minimalJSON)
        let decoded = try JSONDecoder().decode(CommandModel.self, from: data)

        XCTAssertFalse(decoded.useResponseWindow)
        XCTAssertFalse(decoded.isBuiltIn)
        XCTAssertFalse(decoded.hasShortcut)
        XCTAssertFalse(decoded.preserveFormatting)
    }

    // MARK: - Review mode flags

    func testReviewFlagsRoundTripAndDefaultToFalse() throws {
        let plain = CommandModel(name: "Plain", prompt: "p", icon: "pencil")
        let plainJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(plain)) as? [String: Any]
        XCTAssertNil(plainJSON?["reviewChanges"])
        XCTAssertNil(plainJSON?["explainEdits"])

        let reviewed = CommandModel(
            name: "Reviewed",
            prompt: "p",
            icon: "pencil",
            reviewChanges: true,
            explainEdits: true
        )
        let decoded = try JSONDecoder().decode(CommandModel.self, from: JSONEncoder().encode(reviewed))
        XCTAssertTrue(decoded.reviewChanges)
        XCTAssertTrue(decoded.explainEdits)
        XCTAssertTrue(decoded.effectiveExplainEdits)
    }

    func testExplainEditsOnlyTakesEffectInReviewMode() {
        let command = CommandModel(name: "C", prompt: "p", icon: "pencil", reviewChanges: false, explainEdits: true)
        XCTAssertFalse(command.effectiveExplainEdits)
    }

    func testGrammarCheckPromptIsValidStructuredPrompt() {
        let command = CommandModel.grammarCheck
        XCTAssertNotNil(PromptStructure.from(jsonString: command.prompt))
        XCTAssertTrue(command.reviewChanges)
        XCTAssertTrue(command.explainEdits)
        XCTAssertTrue(command.isBuiltIn)
        XCTAssertTrue(CommandModel.defaultCommands.contains { $0.id == CommandModel.BuiltInID.grammarCheck })
    }

    func testTranslatePromptIsValidStructuredPrompt() {
        let command = CommandModel.translate
        XCTAssertNotNil(PromptStructure.from(jsonString: command.prompt))
        XCTAssertTrue(command.useResponseWindow)
        XCTAssertFalse(command.reviewChanges)
        XCTAssertTrue(command.isBuiltIn)
        XCTAssertTrue(command.prompt.contains(CommandModel.targetLanguagePlaceholder))
        XCTAssertTrue(CommandModel.defaultCommands.contains { $0.id == CommandModel.BuiltInID.translate })
    }

    /// The prompt editor rewrites prompts through `PromptStructure`, so the
    /// built-in prompts must only use fields it knows, or edits would drop them.
    func testBuiltInPromptsSurvivePromptEditorRoundTrip() throws {
        for command in [CommandModel.grammarCheck, CommandModel.translate] {
            let structure = try XCTUnwrap(PromptStructure.from(jsonString: command.prompt), command.name)
            let original = try JSONSerialization.jsonObject(with: Data(command.prompt.utf8)) as? NSDictionary
            let roundTripped = try JSONSerialization.jsonObject(
                with: Data(structure.toJSONString(pretty: false).utf8)
            ) as? NSDictionary
            XCTAssertEqual(original, roundTripped, command.name)
        }
    }

    // MARK: - Hidden commands

    func testIsHiddenDefaultsToFalseAndIsOnlyEncodedWhenSet() throws {
        let visible = CommandModel(name: "A", prompt: "p", icon: "i")
        XCTAssertFalse(visible.isHidden)
        let visibleJSON = String(decoding: try JSONEncoder().encode(visible), as: UTF8.self)
        XCTAssertFalse(visibleJSON.contains("isHidden"))

        var hidden = visible
        hidden.isHidden = true
        let decoded = try JSONDecoder().decode(CommandModel.self, from: JSONEncoder().encode(hidden))
        XCTAssertTrue(decoded.isHidden)
    }

    func testOldDataWithoutIsHiddenDecodesAsVisible() throws {
        let json = #"{"id":"00000000-0000-0000-0000-000000000042","name":"Old","prompt":"p","icon":"i"}"#
        let decoded = try JSONDecoder().decode(CommandModel.self, from: Data(json.utf8))
        XCTAssertFalse(decoded.isHidden)
    }

    // MARK: - Translation target

    func testTranslationTargetFollowsChineseCharacters() {
        XCTAssertEqual(CommandModel.translationTarget(for: "我们提出了一种新方法。"), "English")
        XCTAssertEqual(CommandModel.translationTarget(for: "我们 propose 一个新的 attention 机制"), "English")
        XCTAssertEqual(CommandModel.translationTarget(for: "We fine-tune the model 在下游任务上."), "English")
        XCTAssertEqual(CommandModel.translationTarget(for: "We fine-tune the pre-trained Transformer."), "Simplified Chinese")
        XCTAssertEqual(CommandModel.translationTarget(for: "loss = criterion(logits, labels)  # 1e-4, 256"), "Simplified Chinese")
        XCTAssertEqual(CommandModel.translationTarget(for: "Full-width punctuation alone，。"), "Simplified Chinese")
    }

    func testResolvedPromptFillsTargetLanguage() {
        let translate = CommandModel.translate
        let toEnglish = translate.resolvedPrompt(for: "我们在 ImageNet 上预训练模型。")
        XCTAssertFalse(toEnglish.contains(CommandModel.targetLanguagePlaceholder))
        XCTAssertTrue(toEnglish.contains("translate the input into English"))

        let toChinese = translate.resolvedPrompt(for: "We pre-train the model on ImageNet.")
        XCTAssertTrue(toChinese.contains("translate the input into Simplified Chinese"))
        XCTAssertNotNil(PromptStructure.from(jsonString: toChinese))

        let grammar = CommandModel.grammarCheck
        XCTAssertEqual(grammar.resolvedPrompt(for: "我们"), grammar.prompt)
    }

    // MARK: - Built-in IDs are stable

    func testBuiltInIDsAreStable() {
        XCTAssertEqual(CommandModel.BuiltInID.proofread.uuidString, "00000000-0001-0000-0000-000000000001")
        XCTAssertEqual(CommandModel.BuiltInID.rewrite.uuidString, "00000000-0001-0000-0000-000000000002")
        XCTAssertEqual(CommandModel.BuiltInID.friendly.uuidString, "00000000-0001-0000-0000-000000000003")
        XCTAssertEqual(CommandModel.BuiltInID.professional.uuidString, "00000000-0001-0000-0000-000000000004")
        XCTAssertEqual(CommandModel.BuiltInID.concise.uuidString, "00000000-0001-0000-0000-000000000005")
        XCTAssertEqual(CommandModel.BuiltInID.summary.uuidString, "00000000-0001-0000-0000-000000000006")
        XCTAssertEqual(CommandModel.BuiltInID.keyPoints.uuidString, "00000000-0001-0000-0000-000000000007")
        XCTAssertEqual(CommandModel.BuiltInID.table.uuidString, "00000000-0001-0000-0000-000000000008")
        XCTAssertEqual(CommandModel.BuiltInID.grammarCheck.uuidString, "00000000-0001-0000-0000-000000000009")
        XCTAssertEqual(CommandModel.BuiltInID.translate.uuidString, "00000000-0001-0000-0000-00000000000A")
    }

    func testDefaultCommandsCountAndAllBuiltIn() {
        let defaults = CommandModel.defaultCommands
        XCTAssertEqual(defaults.count, 10)
        XCTAssertTrue(defaults.allSatisfy(\.isBuiltIn))
    }

    // MARK: - Equatable

    func testEqualityByAllFields() {
        let id = UUID()
        let a = CommandModel(id: id, name: "A", prompt: "p", icon: "i")
        let b = CommandModel(id: id, name: "A", prompt: "p", icon: "i")
        XCTAssertEqual(a, b)
    }

    func testInequalityWhenNameDiffers() {
        let id = UUID()
        let a = CommandModel(id: id, name: "A", prompt: "p", icon: "i")
        let b = CommandModel(id: id, name: "B", prompt: "p", icon: "i")
        XCTAssertNotEqual(a, b)
    }
}
