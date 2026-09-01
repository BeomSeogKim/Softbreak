import AppKit
import UniformTypeIdentifiers

@MainActor
final class MarkdownDocumentController: NSDocumentController {
    private static let markdownContentType = UTType(
        importedAs: MarkdownDocument.markdownTypeIdentifier,
        conformingTo: .plainText
    )

    override var defaultType: String? {
        MarkdownDocument.markdownTypeIdentifier
    }

    override var documentClassNames: [String] {
        [NSStringFromClass(MarkdownDocument.self)]
    }

    override var allowsAutomaticShareMenu: Bool {
        false
    }

    override func documentClass(forType typeName: String) -> AnyClass? {
        guard typeName == MarkdownDocument.markdownTypeIdentifier else {
            return nil
        }

        return MarkdownDocument.self
    }

    override func typeForContents(of url: URL) throws -> String {
        let filenameExtension = url.pathExtension.lowercased()
        guard MarkdownDocument.supportedFilenameExtensions.contains(filenameExtension) else {
            throw CocoaError(
                .fileReadUnknown,
                userInfo: [
                    NSURLErrorKey: url,
                    NSLocalizedDescriptionKey: "Writing App opens .md and .markdown files.",
                ]
            )
        }

        return MarkdownDocument.markdownTypeIdentifier
    }

    override func displayName(forType typeName: String) -> String? {
        guard typeName == MarkdownDocument.markdownTypeIdentifier else {
            return nil
        }

        return "Markdown"
    }

    override func beginOpenPanel(
        _ openPanel: NSOpenPanel,
        forTypes inTypes: [String]?,
        completionHandler: @escaping (Int) -> Void
    ) {
        openPanel.allowedContentTypes = [Self.markdownContentType]
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false

        super.beginOpenPanel(
            openPanel,
            forTypes: [MarkdownDocument.markdownTypeIdentifier],
            completionHandler: completionHandler
        )
    }
}
