import Foundation
import Testing
@testable import WritingApp

@Suite("Markdown Return continuation")
struct MarkdownLineContinuationTests {
    @Test("Unordered list markers continue with their indentation")
    func unorderedLists() throws {
        for source in ["- 항목", "* 항목", "\t+ 항목"] {
            let edit = try #require(
                MarkdownFormatting.continueLine(
                    source: source,
                    selection: caretAtEnd(of: source)
                )
            )
            let marker = source.hasPrefix("\t") ? "\t+ " : String(source.prefix(2))

            #expect(applying(edit, to: source) == source + "\n" + marker)
            #expect(edit.selectionAfter == caretAtEnd(of: applying(edit, to: source)))
        }
    }

    @Test("Ordered lists increment and preserve CRLF")
    func orderedList() throws {
        let source = "  8) 첫째\r\n  9) 둘째"
        let edit = try #require(
            MarkdownFormatting.continueLine(
                source: source,
                selection: caretAtEnd(of: source)
            )
        )

        #expect(applying(edit, to: source) == source + "\r\n  10) ")
    }

    @Test("Checked tasks continue as unchecked tasks")
    func taskList() throws {
        let source = "> - [x] 완료"
        let edit = try #require(
            MarkdownFormatting.continueLine(
                source: source,
                selection: caretAtEnd(of: source)
            )
        )

        #expect(applying(edit, to: source) == source + "\n> - [ ] ")
    }

    @Test("Quotes and plain indentation continue")
    func quoteAndIndentation() throws {
        let quote = "> 인용"
        let quoteEdit = try #require(
            MarkdownFormatting.continueLine(
                source: quote,
                selection: caretAtEnd(of: quote)
            )
        )
        #expect(applying(quoteEdit, to: quote) == "> 인용\n> ")

        let indented = "    코드"
        let indentEdit = try #require(
            MarkdownFormatting.continueLine(
                source: indented,
                selection: caretAtEnd(of: indented)
            )
        )
        #expect(applying(indentEdit, to: indented) == "    코드\n    ")
    }

    @Test("Return on an empty list item exits that list level")
    func emptyListItem() throws {
        let source = "- 첫째\n- "
        let edit = try #require(
            MarkdownFormatting.continueLine(
                source: source,
                selection: caretAtEnd(of: source)
            )
        )
        let result = applying(edit, to: source)

        #expect(result == "- 첫째\n")
        #expect(edit.selectionAfter == caretAtEnd(of: result))
    }

    @Test("An empty quoted task exits to the quote before exiting the quote")
    func emptyQuotedTask() throws {
        let source = "> - [X] "
        let taskExit = try #require(
            MarkdownFormatting.continueLine(
                source: source,
                selection: caretAtEnd(of: source)
            )
        )
        let quoteOnly = applying(taskExit, to: source)
        #expect(quoteOnly == "> ")

        let quoteExit = try #require(
            MarkdownFormatting.continueLine(
                source: quoteOnly,
                selection: taskExit.selectionAfter
            )
        )
        #expect(applying(quoteExit, to: quoteOnly).isEmpty)
    }

    @Test("Plain paragraphs and multi-line selections keep native Return behavior")
    func nativeFallback() {
        #expect(
            MarkdownFormatting.continueLine(
                source: "일반 문단",
                selection: NSRange(location: 3, length: 0)
            ) == nil
        )
        #expect(
            MarkdownFormatting.continueLine(
                source: "- 첫째\n- 둘째",
                selection: NSRange(location: 2, length: 5)
            ) == nil
        )
    }

    private func caretAtEnd(of source: String) -> NSRange {
        NSRange(location: (source as NSString).length, length: 0)
    }

    private func applying(_ edit: MarkdownEdit, to source: String) -> String {
        (source as NSString).replacingCharacters(
            in: edit.replacementRange,
            with: edit.replacement
        )
    }
}
