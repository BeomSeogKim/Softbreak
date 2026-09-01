import Foundation
import Markdown

struct MarkdownHTMLRenderer: Sendable {
    private let css: String

    init(css: String) {
        self.css = css
    }

    func render(_ source: String, baseURL: URL?) -> String {
        let document = Document(parsing: source)
        let body = HTMLBodyRenderer(baseURL: baseURL).render(document)

        return """
        <!doctype html>
        <html lang="ko">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'none'; style-src 'unsafe-inline'; img-src http: https: file:; base-uri 'none'; form-action 'none'">
        <style>
        \(css)
        </style>
        </head>
        <body>
        \(body)</body>
        </html>
        """
    }
}

private struct HTMLBodyRenderer {
    private let baseURL: URL?

    init(baseURL: URL?) {
        self.baseURL = baseURL
    }

    func render(_ markup: Markup) -> String {
        switch markup {
        case let document as Document:
            return renderChildren(of: document)
        case let blockQuote as BlockQuote:
            return "<blockquote>\n\(renderChildren(of: blockQuote))</blockquote>\n"
        case let codeBlock as CodeBlock:
            return renderCodeBlock(codeBlock)
        case let heading as Heading:
            return "<h\(heading.level)>\(renderChildren(of: heading))</h\(heading.level)>\n"
        case is ThematicBreak:
            return "<hr>\n"
        case let html as HTMLBlock:
            return "<p>\(escapeHTML(html.rawHTML))</p>\n"
        case let list as OrderedList:
            let start = list.startIndex == 1 ? "" : " start=\"\(list.startIndex)\""
            return "<ol\(start)>\n\(renderChildren(of: list))</ol>\n"
        case let list as UnorderedList:
            return "<ul>\n\(renderChildren(of: list))</ul>\n"
        case let listItem as ListItem:
            return renderListItem(listItem)
        case let paragraph as Paragraph:
            return "<p>\(renderChildren(of: paragraph))</p>\n"
        case let table as Table:
            return renderTable(table)
        case let inlineCode as InlineCode:
            return "<code>\(escapeHTML(inlineCode.code))</code>"
        case let emphasis as Emphasis:
            return "<em>\(renderChildren(of: emphasis))</em>"
        case let strong as Strong:
            return "<strong>\(renderChildren(of: strong))</strong>"
        case let strikethrough as Strikethrough:
            return "<del>\(renderChildren(of: strikethrough))</del>"
        case let link as Link:
            return renderLink(link)
        case let image as Image:
            return renderImage(image)
        case let html as InlineHTML:
            return escapeHTML(html.rawHTML)
        case is LineBreak:
            return "<br>\n"
        case is SoftBreak:
            return "\n"
        case let text as Text:
            return escapeHTML(text.string)
        case let symbolLink as SymbolLink:
            return "<code>\(escapeHTML(symbolLink.destination ?? ""))</code>"
        case let attributes as InlineAttributes:
            return renderChildren(of: attributes)
        default:
            return renderChildren(of: markup)
        }
    }

    private func renderChildren(of markup: Markup) -> String {
        markup.children.map(render).joined()
    }

    private func renderCodeBlock(_ codeBlock: CodeBlock) -> String {
        let language = codeBlock.language?
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init)
        let languageAttribute = language.map { " class=\"language-\(escapeHTML($0))\"" } ?? ""

        return "<pre><code\(languageAttribute)>\(escapeHTML(codeBlock.code))</code></pre>\n"
    }

    private func renderListItem(_ listItem: ListItem) -> String {
        let checkbox: String

        switch listItem.checkbox {
        case .checked?:
            checkbox = "<input type=\"checkbox\" disabled checked> "
        case .unchecked?:
            checkbox = "<input type=\"checkbox\" disabled> "
        case nil:
            checkbox = ""
        }

        let content = listItem.children.enumerated().map { index, child in
            if index == 0, let paragraph = child as? Paragraph {
                return renderChildren(of: paragraph)
            }
            return render(child)
        }.joined()

        return "<li>\(checkbox)\(content)</li>\n"
    }

    private func renderLink(_ link: Link) -> String {
        let label = renderChildren(of: link)
        guard let destination = link.destination,
              let href = allowedLinkDestination(destination) else {
            return label
        }

        let title = link.title.map { " title=\"\(escapeHTML($0))\"" } ?? ""
        return "<a href=\"\(escapeHTML(href))\"\(title)>\(label)</a>"
    }

    private func renderImage(_ image: Image) -> String {
        guard let source = image.source,
              let resolvedSource = allowedImageSource(source) else {
            return escapeHTML(plainText(of: image))
        }

        let alt = escapeHTML(plainText(of: image))
        let title = image.title.map { " title=\"\(escapeHTML($0))\"" } ?? ""
        return "<img src=\"\(escapeHTML(resolvedSource))\" alt=\"\(alt)\"\(title)>"
    }

    private func allowedLinkDestination(_ destination: String) -> String? {
        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              ["http", "https", "mailto"].contains(scheme),
              URL(string: trimmed) != nil else {
            return nil
        }

        return trimmed
    }

    private func allowedImageSource(_ source: String) -> String? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              !trimmed.hasPrefix("//"),
              let components = URLComponents(string: trimmed) else {
            return nil
        }

        if let scheme = components.scheme?.lowercased() {
            guard ["http", "https", "file"].contains(scheme),
                  let url = URL(string: trimmed) else {
                return nil
            }
            return url.absoluteURL.absoluteString
        }

        guard let baseURL else {
            return URL(string: trimmed)?.relativeString
        }

        guard let resolvedURL = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL,
              let scheme = resolvedURL.scheme?.lowercased(),
              ["http", "https", "file"].contains(scheme) else {
            return nil
        }

        return resolvedURL.absoluteString
    }

    private func plainText(of markup: Markup) -> String {
        switch markup {
        case let text as Text:
            return text.string
        case let code as InlineCode:
            return code.code
        case let html as InlineHTML:
            return html.rawHTML
        case is SoftBreak:
            return " "
        case is LineBreak:
            return "\n"
        case let symbolLink as SymbolLink:
            return symbolLink.destination ?? ""
        default:
            return markup.children.map(plainText).joined()
        }
    }

    private func renderTable(_ table: Table) -> String {
        let header = renderTableRow(
            table.head,
            cellTag: "th",
            alignments: table.columnAlignments
        )
        let bodyRows = table.body.children.map {
            renderTableRow($0, cellTag: "td", alignments: table.columnAlignments)
        }.joined()
        let body = bodyRows.isEmpty ? "" : "<tbody>\n\(bodyRows)</tbody>\n"

        return "<table>\n<thead>\n\(header)</thead>\n\(body)</table>\n"
    }

    private func renderTableRow(
        _ row: Markup,
        cellTag: String,
        alignments: [Table.ColumnAlignment?]
    ) -> String {
        let cells = row.children.enumerated().compactMap { index, markup -> String? in
            guard let cell = markup as? Table.Cell,
                  cell.colspan > 0,
                  cell.rowspan > 0 else {
                return nil
            }

            let alignment: String
            if index < alignments.count, let value = alignments[index] {
                switch value {
                case .left:
                    alignment = " align=\"left\""
                case .center:
                    alignment = " align=\"center\""
                case .right:
                    alignment = " align=\"right\""
                }
            } else {
                alignment = ""
            }

            let colspan = cell.colspan > 1 ? " colspan=\"\(cell.colspan)\"" : ""
            let rowspan = cell.rowspan > 1 ? " rowspan=\"\(cell.rowspan)\"" : ""
            return "<\(cellTag)\(alignment)\(colspan)\(rowspan)>\(renderChildren(of: cell))</\(cellTag)>\n"
        }.joined()

        return "<tr>\n\(cells)</tr>\n"
    }

    private func escapeHTML(_ string: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(string.utf8.count)

        for character in string {
            switch character {
            case "&":
                escaped += "&amp;"
            case "<":
                escaped += "&lt;"
            case ">":
                escaped += "&gt;"
            case "\"":
                escaped += "&quot;"
            case "'":
                escaped += "&#39;"
            default:
                escaped.append(character)
            }
        }

        return escaped
    }
}
