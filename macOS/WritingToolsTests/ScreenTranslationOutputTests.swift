import XCTest
@testable import WritingTools

final class ScreenTranslationOutputTests: XCTestCase {
    private func parse(_ raw: String, complete: Bool = true) -> ScreenTranslationOutput.Parsed {
        ScreenTranslationOutput.parse(raw, isComplete: complete)
    }

    func testSplitsOriginalAndTranslation() {
        let parsed = parse("<original>你好</original>\n<translation>Hello</translation>")
        XCTAssertEqual(parsed, .init(original: "你好", translation: "Hello", usedTags: true))
    }

    func testKeepsLineBreaksInsideBlocks() {
        let parsed = parse("<original>a\n\nb</original>\n<translation>A\n\nB</translation>")
        XCTAssertEqual(parsed.original, "a\n\nb")
        XCTAssertEqual(parsed.translation, "A\n\nB")
    }

    func testEmptyBlocksGiveEmptyText() {
        let parsed = parse("<original></original>\n<translation></translation>")
        XCTAssertEqual(parsed, .init(original: "", translation: "", usedTags: true))
    }

    func testMissingClosingTagOfOriginalEndsAtTranslation() {
        let parsed = parse("<original>你好\n<translation>Hello</translation>")
        XCTAssertEqual(parsed.original, "你好")
        XCTAssertEqual(parsed.translation, "Hello")
    }

    func testUnclosedTranslationOfCompleteReplyIsKept() {
        let parsed = parse("<original>你好</original><translation>Hello")
        XCTAssertEqual(parsed.translation, "Hello")
    }

    func testReplyWithoutTagsIsShownAsTranslation() {
        let parsed = parse("Hello there")
        XCTAssertEqual(parsed, .init(original: "", translation: "Hello there", usedTags: false))
    }

    func testReplyWithoutTagsLosesItsCodeFence() {
        XCTAssertEqual(parse("```\nHello\n```").translation, "Hello")
    }

    func testTagsInsideCodeFenceAreStillFound() {
        let parsed = parse("```\n<original>a</original>\n<translation>b</translation>\n```")
        XCTAssertEqual(parsed.original, "a")
        XCTAssertEqual(parsed.translation, "b")
    }

    // MARK: - Partial replies

    func testPartialOpeningTagShowsNothing() {
        XCTAssertEqual(parse("<orig", complete: false), .init(original: "", translation: "", usedTags: true))
        XCTAssertEqual(parse("", complete: false), .init(original: "", translation: "", usedTags: true))
    }

    func testOpenOriginalShowsWhatHasArrived() {
        XCTAssertEqual(parse("<original>你好，世", complete: false).original, "你好，世")
    }

    func testHalfWrittenClosingTagIsHidden() {
        XCTAssertEqual(parse("<original>你好</orig", complete: false).original, "你好")
        XCTAssertEqual(parse("<original>你好</original>\n<trans", complete: false).original, "你好")
        XCTAssertEqual(parse("<original>你好</original><translation>Hel</transl", complete: false).translation, "Hel")
        XCTAssertEqual(parse("<original>你好<", complete: false).original, "你好")
    }

    func testTranslationGrowsWhileOriginalIsComplete() {
        let parsed = parse("<original>你好</original>\n<translation>Hel", complete: false)
        XCTAssertEqual(parsed.original, "你好")
        XCTAssertEqual(parsed.translation, "Hel")
    }

    func testPlainTextStartIsShownWhileStreamingWithoutTags() {
        XCTAssertEqual(parse("Hello", complete: false).translation, "Hello")
    }
}
