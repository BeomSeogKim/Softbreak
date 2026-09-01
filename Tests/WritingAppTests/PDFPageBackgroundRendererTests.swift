import CoreGraphics
import Foundation
import PDFKit
import Testing
@testable import WritingApp

@Suite("PDF theme backgrounds")
struct PDFPageBackgroundRendererTests {
    @Test("Background rendering preserves URL annotations")
    func preservesURLAnnotations() async throws {
        let testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PDFPageBackgroundRendererTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: testDirectory) }

        let sourceURL = testDirectory.appendingPathComponent("source.pdf")
        var mediaBox = CGRect(x: 0, y: 0, width: 200, height: 200)
        let linkBounds = CGRect(x: 20, y: 30, width: 100, height: 20)
        let targetURL = try #require(URL(string: "https://example.com/theme"))
        let context = try #require(CGContext(
            sourceURL as CFURL,
            mediaBox: &mediaBox,
            nil
        ))
        context.beginPDFPage(nil)
        context.setFillColor(CGColor(gray: 0.8, alpha: 1))
        context.fill(CGRect(x: 40, y: 40, width: 120, height: 120))
        context.setURL(targetURL as CFURL, for: linkBounds)
        context.endPDFPage()
        context.closePDF()

        let renderer = PDFPageBackgroundRenderer()
        let outputURL = try await renderer.render(
            sourceURL: sourceURL,
            backgroundHex: DocumentTheme.pine.palette.background
        )
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let outputDocument = try #require(PDFDocument(url: outputURL))
        let outputPage = try #require(outputDocument.page(at: 0))
        let outputAnnotation = try #require(outputPage.annotations.first)
        let outputAction = try #require(outputAnnotation.action as? PDFActionURL)

        #expect(outputDocument.pageCount == 1)
        #expect(outputPage.annotations.count == 1)
        #expect(outputAnnotation.bounds == linkBounds)
        #expect(outputAction.url == targetURL)
    }
}
