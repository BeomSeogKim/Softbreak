import Foundation
import Testing
@testable import WritingApp

@Suite("Markdown formatting")
struct MarkdownFormattingTests {
    @Test("Heading shortcuts preserve a Korean caret position")
    func headingPreservesCaret() throws {
        let source = "조용한 아침"
        let edit = try #require(
            MarkdownFormatting.heading(
                level: 1,
                source: source,
                selection: NSRange(location: 3, length: 0)
            )
        )

        #expect(edit.replacement == "# 조용한 아침")
        #expect(edit.selectionAfter == NSRange(location: 5, length: 0))
    }

    @Test("A heading command replaces an existing ATX level")
    func headingReplacesLevel() throws {
        let source = "#### 제목\n본문"
        let edit = try #require(
            MarkdownFormatting.heading(
                level: 2,
                source: source,
                selection: NSRange(location: 7, length: 0)
            )
        )

        #expect(edit.replacement == "## 제목\n")
        #expect(applying(edit, to: source) == "## 제목\n본문")
    }

    @Test("Paragraph removes a heading marker")
    func paragraphRemovesHeading() throws {
        let source = "### 제목"
        let edit = try #require(
            MarkdownFormatting.heading(
                level: 0,
                source: source,
                selection: NSRange(location: 6, length: 0)
            )
        )

        #expect(applying(edit, to: source) == "제목")
    }

    @Test("A selection ending at the next line does not format that line")
    func selectionBoundary() throws {
        let source = "첫 줄\n둘째 줄\n셋째 줄"
        let secondLineStart = (source as NSString).range(of: "둘째").location
        let edit = try #require(
            MarkdownFormatting.heading(
                level: 2,
                source: source,
                selection: NSRange(location: 0, length: secondLineStart)
            )
        )

        #expect(applying(edit, to: source) == "## 첫 줄\n둘째 줄\n셋째 줄")
    }

    @Test("Bold wraps and then unwraps selected text")
    func boldToggle() throws {
        let source = "조용한 문장"
        let range = (source as NSString).range(of: "조용한")
        let wrapped = try #require(
            MarkdownFormatting.toggleInline(
                prefix: "**",
                source: source,
                selection: range
            )
        )
        let wrappedSource = applying(wrapped, to: source)
        #expect(wrappedSource == "**조용한** 문장")

        let unwrapped = try #require(
            MarkdownFormatting.toggleInline(
                prefix: "**",
                source: wrappedSource,
                selection: wrapped.selectionAfter
            )
        )
        #expect(applying(unwrapped, to: wrappedSource) == source)
    }

    @Test("An empty inline command inserts a pair around the caret")
    func emptyItalic() throws {
        let edit = try #require(
            MarkdownFormatting.toggleItalic(
                source: "문장",
                selection: NSRange(location: 1, length: 0)
            )
        )

        #expect(applying(edit, to: "문장") == "문**장")
        #expect(edit.selectionAfter == NSRange(location: 2, length: 0))
    }

    @Test("Italic combines with bold instead of replacing it")
    func italicInsideBold() throws {
        let source = "**text**"
        let selection = (source as NSString).range(of: "text")
        let combined = try #require(
            MarkdownFormatting.toggleItalic(source: source, selection: selection)
        )
        let combinedSource = applying(combined, to: source)
        #expect(combinedSource == "***text***")

        let restored = try #require(
            MarkdownFormatting.toggleItalic(
                source: combinedSource,
                selection: combined.selectionAfter
            )
        )
        #expect(applying(restored, to: combinedSource) == source)
    }

    @Test("Italic combines with a fully selected bold span")
    func italicAroundSelectedBold() throws {
        let source = "**text**"
        let edit = try #require(
            MarkdownFormatting.toggleItalic(
                source: source,
                selection: NSRange(location: 0, length: (source as NSString).length)
            )
        )

        #expect(applying(edit, to: source) == "***text***")
    }

    @Test("Link preserves an emoji label and selects the URL")
    func linkWithEmoji() throws {
        let source = "불꽃 🎆 안내"
        let range = (source as NSString).range(of: "🎆")
        let edit = try #require(MarkdownFormatting.link(source: source, selection: range))

        #expect(applying(edit, to: source) == "불꽃 [🎆](https://) 안내")
        #expect(
            ((applying(edit, to: source) as NSString).substring(with: edit.selectionAfter))
                == "https://"
        )
    }

    @Test("Inline code chooses a delimiter longer than its content")
    func inlineCodeWithBacktick() throws {
        let source = "a`b"
        let selection = NSRange(location: 0, length: (source as NSString).length)
        let wrapped = try #require(
            MarkdownFormatting.toggleInlineCode(source: source, selection: selection)
        )
        let wrappedSource = applying(wrapped, to: source)
        #expect(wrappedSource == "``a`b``")

        let restored = try #require(
            MarkdownFormatting.toggleInlineCode(
                source: wrappedSource,
                selection: wrapped.selectionAfter
            )
        )
        #expect(applying(restored, to: wrappedSource) == source)
    }

    @Test("Inline code pads content with boundary backtick runs")
    func inlineCodeWithBoundaryBackticks() throws {
        let source = "`code``"
        let selection = NSRange(location: 0, length: (source as NSString).length)
        let edit = try #require(
            MarkdownFormatting.toggleInlineCode(source: source, selection: selection)
        )

        #expect(applying(edit, to: source) == "``` `code`` ```")
    }

    @Test("Inline code unwraps a complete selected span")
    func inlineCodeUnwrapsSelectedSpan() throws {
        let source = "`code`"
        let edit = try #require(
            MarkdownFormatting.toggleInlineCode(
                source: source,
                selection: NSRange(location: 0, length: (source as NSString).length)
            )
        )

        #expect(applying(edit, to: source) == "code")
    }

    @Test("Block shortcuts convert and toggle selected lines")
    func blockToggle() throws {
        let source = "첫째\n둘째"
        let selection = NSRange(location: 0, length: (source as NSString).length)
        let listed = try #require(
            MarkdownFormatting.block(
                .unorderedList,
                source: source,
                selection: selection
            )
        )
        let listedSource = applying(listed, to: source)
        #expect(listedSource == "- 첫째\n- 둘째")

        let restored = try #require(
            MarkdownFormatting.block(
                .unorderedList,
                source: listedSource,
                selection: listed.selectionAfter
            )
        )
        #expect(applying(restored, to: listedSource) == source)
    }

    @Test("Ordered list numbering skips blank lines")
    func orderedList() throws {
        let source = "첫째\n\n둘째"
        let edit = try #require(
            MarkdownFormatting.block(
                .orderedList,
                source: source,
                selection: NSRange(location: 0, length: (source as NSString).length)
            )
        )

        #expect(applying(edit, to: source) == "1. 첫째\n\n2. 둘째")
    }

    @Test("Block shortcuts transform and remove marker-only items")
    func markerOnlyListItems() throws {
        let source = "1. 첫째\n1. \n2. 둘째"
        let selection = NSRange(location: 0, length: (source as NSString).length)
        let converted = try #require(
            MarkdownFormatting.block(
                .unorderedList,
                source: source,
                selection: selection
            )
        )
        let convertedSource = applying(converted, to: source)
        #expect(convertedSource == "- 첫째\n- \n- 둘째")

        let removed = try #require(
            MarkdownFormatting.block(
                .unorderedList,
                source: convertedSource,
                selection: converted.selectionAfter
            )
        )
        #expect(applying(removed, to: convertedSource) == "첫째\n\n둘째")
    }

    @Test("Code block places the caret inside an empty fence")
    func emptyCodeBlock() throws {
        let edit = try #require(
            MarkdownFormatting.fencedCode(
                source: "",
                selection: NSRange(location: 0, length: 0)
            )
        )

        #expect(edit.replacement == "```\n\n```")
        #expect(edit.selectionAfter == NSRange(location: 4, length: 0))
    }

    @Test("Code blocks preserve CRLF and toggle around the selection")
    func codeBlockPreservesCRLF() throws {
        let source = "첫째\r\n둘째"
        let selection = NSRange(location: 0, length: (source as NSString).length)
        let wrapped = try #require(
            MarkdownFormatting.fencedCode(source: source, selection: selection)
        )
        let wrappedSource = applying(wrapped, to: source)
        #expect(wrappedSource == "```\r\n첫째\r\n둘째\r\n```")
        #expect(wrappedSource.replacingOccurrences(of: "\r\n", with: "").contains("\n") == false)

        let restored = try #require(
            MarkdownFormatting.fencedCode(
                source: wrappedSource,
                selection: wrapped.selectionAfter
            )
        )
        #expect(applying(restored, to: wrappedSource) == source)
    }

    @Test("Code block toggles from a caret inside fenced content")
    func codeBlockTogglesFromInside() throws {
        let source = "앞\n```swift\nlet value = 1\n```\n뒤"
        let caret = (source as NSString).range(of: "value").location
        let edit = try #require(
            MarkdownFormatting.fencedCode(
                source: source,
                selection: NSRange(location: caret, length: 0)
            )
        )

        #expect(applying(edit, to: source) == "앞\nlet value = 1\n뒤")
        #expect(edit.selectionAfter == NSRange(location: caret - 9, length: 0))
    }

    @Test("Code block round trips a selection with a trailing newline")
    func codeBlockWithTrailingNewline() throws {
        let source = "내용\n"
        let selection = NSRange(location: 0, length: (source as NSString).length)
        let wrapped = try #require(
            MarkdownFormatting.fencedCode(source: source, selection: selection)
        )
        let wrappedSource = applying(wrapped, to: source)
        let restored = try #require(
            MarkdownFormatting.fencedCode(
                source: wrappedSource,
                selection: wrapped.selectionAfter
            )
        )

        #expect(applying(restored, to: wrappedSource) == source)
    }

    @Test("Code block expands a partial selection to complete lines")
    func codeBlockExpandsToLine() throws {
        let source = "before code after"
        let selection = (source as NSString).range(of: "code")
        let wrapped = try #require(
            MarkdownFormatting.fencedCode(source: source, selection: selection)
        )
        let wrappedSource = applying(wrapped, to: source)
        #expect(wrappedSource == "```\nbefore code after\n```")
        #expect((wrappedSource as NSString).substring(with: wrapped.selectionAfter) == "code")

        let restored = try #require(
            MarkdownFormatting.fencedCode(
                source: wrappedSource,
                selection: wrapped.selectionAfter
            )
        )
        #expect(applying(restored, to: wrappedSource) == source)
    }

    @Test("Four-backtick fences keep literal triple-backtick lines")
    func fourBacktickFence() throws {
        let source = "````\nliteral\n```\nafter\n````"
        let caret = (source as NSString).range(of: "after").location
        let edit = try #require(
            MarkdownFormatting.fencedCode(
                source: source,
                selection: NSRange(location: caret, length: 0)
            )
        )

        #expect(applying(edit, to: source) == "literal\n```\nafter")
    }

    @Test("Code block unwraps a selected fence without its trailing newline")
    func selectedFenceWithoutTrailingNewline() throws {
        let source = "```\nfoo\n```\nnext"
        let selectedLength = ("```\nfoo\n```" as NSString).length
        let edit = try #require(
            MarkdownFormatting.fencedCode(
                source: source,
                selection: NSRange(location: 0, length: selectedLength)
            )
        )

        #expect(applying(edit, to: source) == "foo\nnext")
    }

    @Test("Code block preserves a mixed final line ending")
    func codeBlockPreservesMixedEnding() throws {
        let source = "first\nsecond\r\n"
        let selection = NSRange(location: 0, length: (source as NSString).length)
        let wrapped = try #require(
            MarkdownFormatting.fencedCode(source: source, selection: selection)
        )
        let wrappedSource = applying(wrapped, to: source)
        let restored = try #require(
            MarkdownFormatting.fencedCode(
                source: wrappedSource,
                selection: wrapped.selectionAfter
            )
        )

        #expect(applying(restored, to: wrappedSource) == source)
    }

    private func applying(_ edit: MarkdownEdit, to source: String) -> String {
        (source as NSString).replacingCharacters(in: edit.replacementRange, with: edit.replacement)
    }
}
