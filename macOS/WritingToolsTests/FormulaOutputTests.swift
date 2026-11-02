import XCTest
@testable import WritingTools

final class FormulaOutputTests: XCTestCase {
    /// Accepts everything except the listed commands.
    private func rejecting(_ commands: String...) -> FormulaOutput.Validator {
        { latex in
            commands.first { latex.contains($0) }.map { "Invalid command \($0)" }
        }
    }

    private let acceptAll: FormulaOutput.Validator = { _ in nil }

    // MARK: - Cleaning

    func testStripsSurroundingCodeFence() {
        XCTAssertEqual(FormulaOutput.stripCodeFence("```latex\n$$x$$\n```"), "$$x$$")
        XCTAssertEqual(FormulaOutput.stripCodeFence("```\n$$x$$\n```"), "$$x$$")
        XCTAssertEqual(FormulaOutput.stripCodeFence("  $$x$$  \n"), "$$x$$")
    }

    func testWrapsBareLaTeXInDisplayDelimiters() {
        XCTAssertEqual(FormulaOutput.wrappedIfBareLaTeX(#"\frac{a}{b}"#), "$$\n\\frac{a}{b}\n$$")
        XCTAssertEqual(FormulaOutput.wrappedIfBareLaTeX("x^{2}"), "$$\nx^{2}\n$$")
    }

    func testLeavesDelimitedAndPlainTextAlone() {
        XCTAssertEqual(FormulaOutput.wrappedIfBareLaTeX(#"$$\frac{a}{b}$$"#), #"$$\frac{a}{b}$$"#)
        XCTAssertEqual(FormulaOutput.wrappedIfBareLaTeX("Hello world"), "Hello world")
    }

    // MARK: - Segments

    func testFindsDisplayAndInlineSegments() {
        let text = #"where $W$ is a matrix, $$a=b$$ and \(c\) and \[d\]"#
        let segments = FormulaOutput.mathSegments(in: text)
        XCTAssertEqual(segments.map(\.body), ["W", "a=b", "c", "d"])
        XCTAssertEqual(segments.map(\.isDisplay), [false, true, false, true])
    }

    func testEscapedDollarIsNotMath() {
        XCTAssertTrue(FormulaOutput.mathSegments(in: #"costs \$5 and \$6"#).isEmpty)
    }

    // MARK: - Rewriting

    func testRewritesUnsupportedCommandsToSupportedOnes() {
        let cases: [(String, String)] = [
            (#"\begin{align*} a &= b \end{align*}"#, #"\begin{aligned} a &= b \end{aligned}"#),
            (#"\begin{align}{2} a \end{align}"#, #"\begin{aligned} a \end{aligned}"#),
            (#"\boldsymbol{\mu}"#, #"\bm{\mu}"#),
            (#"\operatorname{softmax}(x)"#, #"\mathrm{softmax}(x)"#),
            (#"\dfrac{a}{b}"#, #"\frac{a}{b}"#),
            (#"x_1, \dots, x_n"#, #"x_1, \ldots, x_n"#),
            (#"\lVert x \rVert"#, #"\Vert x \Vert"#),
            (#"\mathscr{F}"#, #"\mathcal{F}"#),
            (#"E = mc^2 \tag{1}"#, "E = mc^2 "),
            (#"a = b \label{eq:1}"#, "a = b "),
            (#"a = b \nonumber"#, "a = b "),
        ]
        for (input, expected) in cases {
            XCTAssertEqual(FormulaOutput.rewriteForPreview(input), expected, input)
        }
    }

    func testRewriteDoesNotTouchLongerCommandNames() {
        XCTAssertEqual(FormulaOutput.rewriteForPreview(#"\dotsb \dotsc"#), #"\ldots \ldots"#)
        XCTAssertEqual(FormulaOutput.rewriteForPreview(#"\tagged"#), #"\tagged"#)
        XCTAssertEqual(FormulaOutput.rewriteForPreview(#"\lVerty"#), #"\lVerty"#)
    }

    // MARK: - Preparing

    func testPreviewIsRewrittenButSourceIsNot() {
        let prepared = FormulaOutput.prepare(#"$$\operatorname{softmax}(x)$$"#, validate: acceptAll)
        XCTAssertEqual(prepared.source, #"$$\operatorname{softmax}(x)$$"#)
        XCTAssertEqual(prepared.preview, #"$$\mathrm{softmax}(x)$$"#)
        XCTAssertTrue(prepared.failures.isEmpty)
    }

    func testTextAroundFormulasIsKept() {
        let prepared = FormulaOutput.prepare(#"where $W$ is a matrix and $$a=b$$ holds"#, validate: acceptAll)
        XCTAssertEqual(prepared.preview, #"where $W$ is a matrix and $$a=b$$ holds"#)
    }

    func testUnrenderableDisplayFormulaFallsBackToCodeBlock() {
        let prepared = FormulaOutput.prepare(#"$$\underbrace{a+b}_{k}$$"#, validate: rejecting(#"\underbrace"#))
        XCTAssertEqual(prepared.source, #"$$\underbrace{a+b}_{k}$$"#)
        XCTAssertTrue(prepared.preview.contains("```latex\n\\underbrace{a+b}_{k}\n```"))
        XCTAssertFalse(prepared.preview.contains("$$"))
        XCTAssertEqual(prepared.failures.map(\.latex), [#"\underbrace{a+b}_{k}"#])
    }

    func testUnrenderableInlineFormulaFallsBackToInlineCode() {
        let prepared = FormulaOutput.prepare(#"see $\underbrace{a}_{k}$ and $b$"#, validate: rejecting(#"\underbrace"#))
        XCTAssertEqual(prepared.preview, #"see `\underbrace{a}_{k}` and $b$"#)
        XCTAssertEqual(prepared.failures.count, 1)
    }

    func testOnlyFailingFormulasFallBack() {
        let prepared = FormulaOutput.prepare(#"$$a$$ and $$\underbrace{b}_{k}$$"#, validate: rejecting(#"\underbrace"#))
        XCTAssertTrue(prepared.preview.hasPrefix("$$a$$ and"))
        XCTAssertEqual(prepared.failures.count, 1)
    }

    func testFencedBareLaTeXBecomesRenderable() {
        let prepared = FormulaOutput.prepare("```latex\n\\frac{a}{b}\n```", validate: acceptAll)
        XCTAssertEqual(prepared.source, "$$\n\\frac{a}{b}\n$$")
        XCTAssertEqual(prepared.preview, "$$\n\\frac{a}{b}\n$$")
    }

    func testEmptyReplyGivesEmptySource() {
        XCTAssertEqual(FormulaOutput.prepare("  \n", validate: acceptAll).source, "")
    }

    // MARK: - Validator

    func testValidatorAcceptsSupportedAndRejectsUnsupportedLaTeX() {
        XCTAssertNil(FormulaValidator.error(for: #"\frac{a}{b} + \sqrt{x}"#))
        XCTAssertNil(FormulaValidator.error(for: #"\begin{aligned} a &= b \end{aligned}"#))
        XCTAssertNotNil(FormulaValidator.error(for: #"\underbrace{a}_{k}"#))
        XCTAssertNotNil(FormulaValidator.error(for: #"\begin{align} a \end{align}"#))
    }

    func testRewrittenFormulasPassTheValidator() {
        let inputs = [
            #"\begin{align*} a &= b \\ c &= d \end{align*}"#,
            #"\boldsymbol{\mu} + \operatorname{softmax}(x)"#,
            #"\dfrac{a}{b}, x_1, \dots, x_n, \lVert x \rVert"#,
            #"E = mc^2 \tag{1}"#,
        ]
        for input in inputs {
            XCTAssertNil(FormulaValidator.error(for: FormulaOutput.rewriteForPreview(input)), input)
        }
    }
}
