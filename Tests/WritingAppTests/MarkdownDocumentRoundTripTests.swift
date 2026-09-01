import Foundation
import Testing
@testable import WritingApp

@Suite("Markdown document round trips")
@MainActor
struct MarkdownDocumentRoundTripTests {
    @Test("An unchanged UTF-8 document preserves every byte")
    func unchangedUTF8Document() throws {
        let input = Data("# 제목\r\n\r\n한글과 emoji ✍️\r\n".utf8)
        let document = MarkdownDocument()

        try document.read(from: input, ofType: MarkdownDocument.markdownTypeIdentifier)
        let output = try document.data(ofType: MarkdownDocument.markdownTypeIdentifier)

        #expect(output == input)
    }

    @Test("An unchanged UTF-8 BOM document preserves its byte order mark")
    func unchangedByteOrderMarkDocument() throws {
        let bom = Data([0xEF, 0xBB, 0xBF])
        let input = bom + Data("# 제목\n\n본문\n".utf8)
        let document = MarkdownDocument()

        try document.read(from: input, ofType: MarkdownDocument.markdownTypeIdentifier)
        let output = try document.data(ofType: MarkdownDocument.markdownTypeIdentifier)

        #expect(output == input)
    }

    @Test("An edited CRLF document changes only the requested text")
    func editedCRLFDocument() throws {
        let document = MarkdownDocument()
        let input = Data("첫 줄\r\n둘째 줄\r\n".utf8)

        try document.read(from: input, ofType: MarkdownDocument.markdownTypeIdentifier)
        document.markdown = document.markdown.replacingOccurrences(of: "둘째", with: "두 번째")
        let output = try document.data(ofType: MarkdownDocument.markdownTypeIdentifier)

        #expect(output == Data("첫 줄\r\n두 번째 줄\r\n".utf8))
    }
}
