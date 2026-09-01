import Foundation
import XCTest
@testable import WritingApp

final class MarkdownHTMLRendererTests: XCTestCase {
    func testRendersACompleteDocumentAndCommonMarkdown() {
        let renderer = MarkdownHTMLRenderer(css: "body { color: #222; }")
        let markdown = """
        # Draft

        A *focused*, **strong**, and ~~revised~~ paragraph with `x < y`.

        > Quoted text

        ---
        """

        let html = renderer.render(markdown, baseURL: nil)

        XCTAssertTrue(html.hasPrefix("<!doctype html>\n<html lang=\"ko\">"))
        XCTAssertTrue(html.contains("<meta charset=\"utf-8\">"))
        XCTAssertTrue(html.contains("default-src 'none'; script-src 'none'; style-src 'unsafe-inline'; img-src http: https: file:"))
        XCTAssertTrue(html.contains("<style>\nbody { color: #222; }\n</style>"))
        XCTAssertTrue(html.contains("<h1>Draft</h1>"))
        XCTAssertTrue(html.contains("<em>focused</em>"))
        XCTAssertTrue(html.contains("<strong>strong</strong>"))
        XCTAssertTrue(html.contains("<del>revised</del>"))
        XCTAssertTrue(html.contains("<code>x &lt; y</code>"))
        XCTAssertTrue(html.contains("<blockquote>\n<p>Quoted text</p>\n</blockquote>"))
        XCTAssertTrue(html.contains("<hr>"))
        XCTAssertTrue(html.hasSuffix("</body>\n</html>"))
    }

    func testEscapesTextCodeAndRawHTML() {
        let renderer = MarkdownHTMLRenderer(css: "")
        let markdown = """
        Text & <span>inline</span>.

        <script>alert("unsafe")</script>

        ```html
        <button onclick="unsafe()">Run & hide</button>
        ```
        """

        let html = renderer.render(markdown, baseURL: nil)

        XCTAssertTrue(html.contains("Text &amp; &lt;span&gt;inline&lt;/span&gt;."))
        XCTAssertTrue(html.contains("&lt;script&gt;alert(&quot;unsafe&quot;)&lt;/script&gt;"))
        XCTAssertTrue(html.contains("&lt;button onclick=&quot;unsafe()&quot;&gt;Run &amp; hide&lt;/button&gt;"))
        XCTAssertFalse(html.contains("<script>"))
        XCTAssertFalse(html.contains("onclick=\"unsafe()\""))
    }

    func testAllowsOnlyWebAndMailLinks() {
        let renderer = MarkdownHTMLRenderer(css: "")
        let markdown = """
        [Web](https://example.com/?a=1&b=2 'A "title"')
        [Mail](mailto:writer@example.com)
        [Local](notes/other.md)
        [Unsafe](javascript:alert%281%29)
        """

        let html = renderer.render(markdown, baseURL: nil)

        XCTAssertTrue(html.contains("href=\"https://example.com/?a=1&amp;b=2\""))
        XCTAssertTrue(html.contains("title=\"A &quot;title&quot;\""))
        XCTAssertTrue(html.contains("href=\"mailto:writer@example.com\""))
        XCTAssertTrue(html.contains("Local"))
        XCTAssertTrue(html.contains("Unsafe"))
        XCTAssertFalse(html.contains("href=\"notes/other.md\""))
        XCTAssertFalse(html.lowercased().contains("href=\"javascript:"))
    }

    func testResolvesRelativeImagesAndRejectsUnsafeImageSchemes() {
        let renderer = MarkdownHTMLRenderer(css: "")
        let documentURL = URL(fileURLWithPath: "/tmp/Writing Notes/draft.md")
        let markdown = """
        ![Local image](images/photo.png "Preview")
        ![Remote image](https://example.com/photo.png)
        ![Unsafe image](javascript:alert%281%29)
        """

        let html = renderer.render(markdown, baseURL: documentURL)

        XCTAssertTrue(html.contains("src=\"file:///tmp/Writing%20Notes/images/photo.png\""))
        XCTAssertTrue(html.contains("alt=\"Local image\""))
        XCTAssertTrue(html.contains("title=\"Preview\""))
        XCTAssertTrue(html.contains("src=\"https://example.com/photo.png\""))
        XCTAssertTrue(html.contains("Unsafe image"))
        XCTAssertFalse(html.lowercased().contains("src=\"javascript:"))
    }

    func testRendersListsTasksBreaksAndTables() {
        let renderer = MarkdownHTMLRenderer(css: "")
        let markdown = """
        3. Third
        4. Fourth

        - [x] Finished
        - [ ] Pending

        soft
        break\u{20}\u{20}
        hard

        | Name | Value |
        | :--- | ----: |
        | One  | 1     |
        """

        let html = renderer.render(markdown, baseURL: nil)

        XCTAssertTrue(html.contains("<ol start=\"3\">"))
        XCTAssertTrue(html.contains("<input type=\"checkbox\" disabled checked>"))
        XCTAssertTrue(html.contains("<input type=\"checkbox\" disabled>"))
        XCTAssertTrue(html.contains("soft\nbreak<br>\nhard"))
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<th align=\"left\">Name</th>"))
        XCTAssertTrue(html.contains("<th align=\"right\">Value</th>"))
        XCTAssertTrue(html.contains("<td align=\"left\">One</td>"))
        XCTAssertTrue(html.contains("<td align=\"right\">1</td>"))
    }
}
