import AppKit
import Foundation

@MainActor
final class MarkdownDocument: NSDocument {
    nonisolated static let markdownTypeIdentifier = "net.daringfireball.markdown"
    nonisolated static let supportedFilenameExtensions: Set<String> = ["md", "markdown"]

    nonisolated private static let utf8ByteOrderMark = Data([0xEF, 0xBB, 0xBF])

    // NSDocument's read callback is imported as nonisolated even though the
    // default document model serializes reads on the UI actor. Keep the small
    // source snapshot reachable by that callback without opting into
    // concurrent reads or writes.
    nonisolated(unsafe) private var storedMarkdown = ""
    nonisolated(unsafe) private var originalUTF8Data: Data?
    nonisolated(unsafe) private var originalMarkdown: String?
    nonisolated(unsafe) private var preservesByteOrderMark = false

    var markdown: String {
        get { storedMarkdown }
        set {
            guard newValue != storedMarkdown else { return }
            storedMarkdown = newValue
            updateChangeCount(.changeDone)
        }
    }

    override var fileURL: URL? {
        didSet {
            guard oldValue != fileURL else { return }

            NotificationCenter.default.post(
                name: .markdownDocumentDidChangeFileURL,
                object: self
            )
        }
    }

    /// Synchronizes text already tracked by the document's undo manager.
    ///
    /// NSTextView registers typing, undo, and redo with the responder chain's
    /// undo manager. NSDocument observes that manager and updates its own
    /// change count, so doing that a second time here would leave the document
    /// marked as edited after a complete undo.
    func replaceMarkdownFromEditor(_ newValue: String) {
        guard newValue != storedMarkdown else { return }
        storedMarkdown = newValue
    }

    override class var autosavesInPlace: Bool { true }

    override class var readableTypes: [String] {
        [markdownTypeIdentifier]
    }

    override class var writableTypes: [String] {
        [markdownTypeIdentifier]
    }

    override class func isNativeType(_ type: String) -> Bool {
        type == markdownTypeIdentifier
    }

    override init() {
        super.init()
        fileType = Self.markdownTypeIdentifier
    }

    override func makeWindowControllers() {
        addWindowController(EditorWindowController(document: self))
    }

    override func read(from data: Data, ofType typeName: String) throws {
        guard let decodedMarkdown = String(data: data, encoding: .utf8) else {
            throw CocoaError(
                .fileReadInapplicableStringEncoding,
                userInfo: [
                    NSDebugDescriptionErrorKey: "The document is not valid UTF-8.",
                    NSStringEncodingErrorKey: String.Encoding.utf8.rawValue,
                ]
            )
        }

        storedMarkdown = decodedMarkdown
        originalUTF8Data = data
        originalMarkdown = decodedMarkdown
        preservesByteOrderMark = data.starts(with: Self.utf8ByteOrderMark)

        NotificationCenter.default.post(
            name: .markdownDocumentDidReplaceContents,
            object: self
        )
    }

    override func data(ofType typeName: String) throws -> Data {
        if storedMarkdown == originalMarkdown, let originalUTF8Data {
            return originalUTF8Data
        }

        guard var data = storedMarkdown.data(using: .utf8, allowLossyConversion: false) else {
            throw CocoaError(
                .fileWriteInapplicableStringEncoding,
                userInfo: [NSStringEncodingErrorKey: String.Encoding.utf8.rawValue]
            )
        }

        if preservesByteOrderMark {
            data.insert(contentsOf: Self.utf8ByteOrderMark, at: data.startIndex)
        }

        return data
    }

    override func fileNameExtension(
        forType typeName: String,
        saveOperation: NSDocument.SaveOperationType
    ) -> String? {
        if let existingExtension = fileURL?.pathExtension.lowercased(),
           Self.supportedFilenameExtensions.contains(existingExtension) {
            return existingExtension
        }

        return "md"
    }
}

typealias WritingDocument = MarkdownDocument

extension Notification.Name {
    static let markdownDocumentDidReplaceContents = Notification.Name(
        "MarkdownDocumentDidReplaceContents"
    )
    static let markdownDocumentDidChangeFileURL = Notification.Name(
        "MarkdownDocumentDidChangeFileURL"
    )
}
