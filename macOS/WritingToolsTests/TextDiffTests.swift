import XCTest
@testable import WritingTools

final class TextDiffTests: XCTestCase {

    // MARK: - Tokenizer

    func testTokensConcatenateBackToInput() {
        let inputs = [
            "Hello, world!  How are you?\nFine.",
            "We met 在会上，然后 decided to go.",
            "Emoji 👩‍💻 and flags 🇩🇪 stay intact.",
            "  leading and trailing  ",
            "",
        ]
        for input in inputs {
            let tokens = WordTokenizer.tokenize(input)
            XCTAssertEqual(tokens.map(\.text).joined(), input, "Round trip failed for: \(input)")
        }
    }

    func testTokenizerSeparatesWordsWhitespaceAndPunctuation() {
        let tokens = WordTokenizer.tokenize("Hi, you.")
        XCTAssertEqual(tokens.map(\.text), ["Hi", ",", " ", "you", "."])
        XCTAssertEqual(tokens.map(\.kind), [.word, .punctuation, .whitespace, .word, .punctuation])
    }

    // MARK: - Diff

    func testIdenticalTextHasNoHunks() {
        let diff = TextDiff(original: "Nothing to fix here.", revised: "Nothing to fix here.")
        XCTAssertFalse(diff.hasChanges)
        XCTAssertEqual(diff.resultText(), "Nothing to fix here.")
    }

    func testAdjacentEditsSeparatedBySpaceMergeIntoOneHunk() {
        let diff = TextDiff(
            original: "Their was five apples on the table.",
            revised: "There were five apples on the table."
        )
        XCTAssertEqual(diff.hunks.count, 1)
        XCTAssertEqual(diff.hunks[0].oldText, "Their was")
        XCTAssertEqual(diff.hunks[0].newText, "There were")
        XCTAssertEqual(diff.hunks[0].kind, .replacement)
        XCTAssertEqual(diff.hunks[0].oldRange, NSRange(location: 0, length: 9))
    }

    func testDistantEditsStaySeparate() {
        let original = "teh cat sat on teh mat"
        let diff = TextDiff(original: original, revised: "the cat sat on the mat")
        XCTAssertEqual(diff.hunks.count, 2)
        XCTAssertEqual(diff.hunks.map(\.oldText), ["teh", "teh"])
        XCTAssertEqual(diff.hunks.map(\.newText), ["the", "the"])
        XCTAssertEqual(diff.hunks[0].oldRange, NSRange(location: 0, length: 3))
        XCTAssertEqual(diff.hunks[1].oldRange, NSRange(location: 15, length: 3))
    }

    func testInsertionAndDeletionKinds() {
        let inserted = TextDiff(original: "Hello world", revised: "Hello world.")
        XCTAssertEqual(inserted.hunks.count, 1)
        XCTAssertEqual(inserted.hunks[0].kind, .insertion)
        XCTAssertEqual(inserted.hunks[0].newText, ".")
        XCTAssertEqual(inserted.hunks[0].oldRange, NSRange(location: 11, length: 0))

        let deleted = TextDiff(original: "It is very very good.", revised: "It is very good.")
        XCTAssertEqual(deleted.hunks.count, 1)
        XCTAssertEqual(deleted.hunks[0].kind, .deletion)
        XCTAssertEqual(deleted.hunks[0].newText, "")
    }

    func testChineseFragmentBecomesOneHunk() {
        let original = "We decided to go 在会上 yesterday."
        let revised = "We decided to go at the meeting yesterday."
        let diff = TextDiff(original: original, revised: revised)

        XCTAssertEqual(diff.hunks.count, 1)
        XCTAssertTrue(diff.hunks[0].oldText.contains("在会上"))
        XCTAssertTrue(diff.hunks[0].newText.contains("at the meeting"))
        XCTAssertEqual(diff.resultText(), revised)
    }

    func testDecisionsProduceOriginalRevisedOrMix() {
        let original = "teh cat sat on teh mat"
        let revised = "the cat sat on the mat"
        var diff = TextDiff(original: original, revised: revised)

        XCTAssertEqual(diff.resultText(), revised)

        diff.setAllDecisions(.rejected)
        XCTAssertEqual(diff.resultText(), original)

        diff.setAllDecisions(.accepted)
        diff.setDecision(.rejected, for: 1)
        XCTAssertEqual(diff.resultText(), "the cat sat on teh mat")
        XCTAssertEqual(diff.acceptedCount, 1)
    }

    func testEditsStartPendingAndPendingEditsAreApplied() {
        let original = "teh cat sat on teh mat"
        let revised = "the cat sat on the mat"
        var diff = TextDiff(original: original, revised: revised)

        XCTAssertTrue(diff.hunks.allSatisfy { $0.decision == .pending })
        XCTAssertEqual(diff.pendingCount, 2)
        XCTAssertEqual(diff.resultText(), revised)

        diff.setDecision(.rejected, for: 0)
        XCTAssertEqual(diff.pendingCount, 1)
        XCTAssertEqual(diff.rejectedCount, 1)
        XCTAssertEqual(diff.acceptedCount, 0)
        XCTAssertEqual(diff.resultText(), "teh cat sat on the mat")

        let attributed = NSMutableAttributedString(string: original)
        XCTAssertTrue(attributed.applyAcceptedHunks(of: diff))
        XCTAssertEqual(attributed.string, "teh cat sat on the mat")
    }

    func testNextPendingHunkSkipsReviewedEditsAndWraps() {
        var diff = TextDiff(
            original: "We saw teh dog in the park. Later we fed teh cat at home. Then we walked teh horse by the river.",
            revised: "We saw the dog in the park. Later we fed the cat at home. Then we walked the horse by the river."
        )
        XCTAssertEqual(diff.hunks.count, 3)
        XCTAssertEqual(diff.nextPendingHunkID(after: nil), 0)

        diff.setDecision(.accepted, for: 0)
        diff.setDecision(.rejected, for: 1)
        XCTAssertEqual(diff.nextPendingHunkID(after: 0), 2)

        diff.setDecision(.pending, for: 0)
        diff.setDecision(.accepted, for: 2)
        XCTAssertEqual(diff.nextPendingHunkID(after: 2), 0, "Wraps around to the first pending edit")

        diff.setAllDecisions(.accepted)
        XCTAssertNil(diff.nextPendingHunkID(after: 1))
    }

    func testRenderShowsResolvedTextForReviewedEdits() {
        var diff = TextDiff(original: "teh cat sat on teh mat", revised: "the cat sat on the mat")

        func rendered(_ mode: ReviewViewModel.DisplayMode) -> String {
            DiffTextView.render(diff: diff, selectedHunkID: nil, mode: mode, fontSize: 14).text.string
        }

        XCTAssertEqual(rendered(.markup), "tehthe cat sat on tehthe mat", "Pending edits show old and new text")

        diff.setDecision(.accepted, for: 0)
        diff.setDecision(.rejected, for: 1)
        XCTAssertEqual(rendered(.markup), "the cat sat on teh mat", "Reviewed edits show only the resulting text")
        XCTAssertEqual(rendered(.final), diff.resultText())
        XCTAssertEqual(rendered(.original), diff.original)
    }

    func testRenderedHunkRangesMatchInEveryMode() {
        var diff = TextDiff(original: "I has a apple.", revised: "I have an apple.")
        diff.setDecision(.accepted, for: 0)
        for mode in [ReviewViewModel.DisplayMode.markup, .final, .original] {
            let rendering = DiffTextView.render(diff: diff, selectedHunkID: 0, mode: mode, fontSize: 14)
            let text = rendering.text.string as NSString
            for hunk in diff.hunks {
                let expected: String
                switch mode {
                case .original: expected = hunk.oldText
                case .final: expected = hunk.isApplied ? hunk.newText : hunk.oldText
                case .markup: expected = hunk.decision == .pending ? hunk.oldText + hunk.newText : hunk.newText
                }
                XCTAssertEqual(text.substring(with: rendering.hunkRanges[hunk.id]!), expected)
            }
        }
    }

    func testRoundTripForAssortedEdits() {
        let pairs = [
            ("I has a apple , and  two banana。", "I have an apple, and two bananas."),
            ("Line one\nline two has a eror\n\nLine four", "Line one\nLine two has an error\n\nLine four"),
            ("", "New text"),
            ("Old text", ""),
            ("中文句子。", "An English sentence."),
        ]
        for (original, revised) in pairs {
            var diff = TextDiff(original: original, revised: revised)
            XCTAssertEqual(diff.resultText(), revised, "Accepted result mismatch for: \(original)")
            diff.setAllDecisions(.rejected)
            XCTAssertEqual(diff.resultText(), original, "Rejected result mismatch for: \(original)")
        }
    }

    func testHunkRangesUseUTF16Offsets() {
        let original = "I ❤️ teh code"
        let diff = TextDiff(original: original, revised: "I ❤️ the code")
        XCTAssertEqual(diff.hunks.count, 1)

        let expectedLocation = ("I ❤️ " as NSString).length
        XCTAssertEqual(diff.hunks[0].oldRange, NSRange(location: expectedLocation, length: 3))
        XCTAssertEqual((original as NSString).substring(with: diff.hunks[0].oldRange), "teh")
    }

    func testEveryHunkRangeMatchesItsOldText() {
        let original = "Their was five apple's on teh table , we eated them 在会上。"
        let revised = "There were five apples on the table, and we ate them at the meeting."
        let diff = TextDiff(original: original, revised: revised)
        let text = original as NSString
        for hunk in diff.hunks {
            XCTAssertEqual(text.substring(with: hunk.oldRange), hunk.oldText)
        }
    }

    // MARK: - Attributed application

    func testApplyAcceptedHunksKeepsFormattingBetweenEdits() {
        let original = "teh bold word and teh end"
        let attributed = NSMutableAttributedString(string: original)
        let boldRange = (original as NSString).range(of: "bold word")
        attributed.addAttribute(.toolTip, value: "bold", range: boldRange)

        let diff = TextDiff(original: original, revised: "the bold word and the end")
        XCTAssertEqual(diff.hunks.count, 2)

        XCTAssertTrue(attributed.applyAcceptedHunks(of: diff))
        XCTAssertEqual(attributed.string, "the bold word and the end")

        let newBoldRange = (attributed.string as NSString).range(of: "bold word")
        var effective = NSRange()
        let value = attributed.attribute(.toolTip, at: newBoldRange.location, effectiveRange: &effective)
        XCTAssertEqual(value as? String, "bold")
        XCTAssertEqual(effective, newBoldRange)
    }

    func testApplyAcceptedHunksSkipsRejected() {
        let original = "teh cat sat on teh mat"
        let attributed = NSMutableAttributedString(string: original)
        var diff = TextDiff(original: original, revised: "the cat sat on the mat")
        diff.setDecision(.rejected, for: 0)

        XCTAssertTrue(attributed.applyAcceptedHunks(of: diff))
        XCTAssertEqual(attributed.string, "teh cat sat on the mat")
    }

    func testApplyAcceptedHunksRejectsMismatchedSource() {
        let attributed = NSMutableAttributedString(string: "different text")
        let diff = TextDiff(original: "teh text", revised: "the text")
        XCTAssertFalse(attributed.applyAcceptedHunks(of: diff))
        XCTAssertEqual(attributed.string, "different text")
    }
}
