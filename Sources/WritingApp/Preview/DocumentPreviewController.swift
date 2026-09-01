import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers
import WebKit

@MainActor
final class DocumentPreviewController: NSObject, WKNavigationDelegate {
    let readView: WKWebView
    let pdfView: PDFView
    private(set) var cachedPDFURL: URL?

    private let printView: WKWebView
    private let renderer: MarkdownHTMLRenderer
    private var generationCompletion: ((Result<URL, Error>) -> Void)?
    private var activeNavigation: WKNavigation?
    private var isWaitingForPrintResources = false
    private var resourceWaitToken: UUID?
    private var resourceWatchdog: Task<Void, Never>?
    private var activePrintOperation: NSPrintOperation?
    private var activePrintOperationID: ObjectIdentifier?
    private var pendingPDFURL: URL?
    private var abandonedPrintURLs: [ObjectIdentifier: URL] = [:]

    override init() {
        let css = Self.loadDocumentCSS()
        renderer = MarkdownHTMLRenderer(css: css)
        readView = WKWebView(frame: .zero, configuration: Self.makeWebConfiguration())
        printView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 794, height: 1_123),
            configuration: Self.makeWebConfiguration()
        )
        pdfView = PDFView(frame: .zero)

        super.init()

        readView.allowsMagnification = true

        printView.navigationDelegate = self
        printView.mediaType = "print"

        pdfView.autoScales = true
        pdfView.displayDirection = .vertical
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysPageBreaks = true
    }

    deinit {
        if let cachedPDFURL {
            try? FileManager.default.removeItem(at: cachedPDFURL)
        }

        if let pendingPDFURL, pendingPDFURL != cachedPDFURL {
            try? FileManager.default.removeItem(at: pendingPDFURL)
        }

        for url in abandonedPrintURLs.values where url != cachedPDFURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func showReadPreview(markdown: String, baseURL: URL?) {
        readView.loadHTMLString(renderer.render(markdown, baseURL: baseURL), baseURL: baseURL)
    }

    func clearDisplayedPDF() {
        pdfView.document = nil
    }

    func generatePDF(
        markdown: String,
        baseURL: URL?,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard generationCompletion == nil else {
            completion(.failure(DocumentPreviewError.generationInProgress))
            return
        }

        generationCompletion = completion
        let html = renderer.render(markdown, baseURL: baseURL)
        activeNavigation = printView.loadHTMLString(html, baseURL: baseURL)
    }

    func exportCachedPDF(from window: NSWindow) {
        guard let cachedPDFURL else {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "No PDF preview"
            alert.informativeText = "Create a PDF preview before exporting."
            alert.beginSheetModal(for: window)
            return
        }

        let pdfBytes: Data
        do {
            pdfBytes = try Data(contentsOf: cachedPDFURL)
        } catch {
            let alert = NSAlert(error: error)
            alert.beginSheetModal(for: window)
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Document.pdf"
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let destinationURL = panel.url else {
                return
            }

            do {
                try pdfBytes.write(to: destinationURL, options: .atomic)
            } catch {
                let alert = NSAlert(error: error)
                alert.beginSheetModal(for: window)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard
            webView === printView,
            navigation === activeNavigation,
            generationCompletion != nil,
            !isWaitingForPrintResources,
            activePrintOperation == nil
        else {
            return
        }

        isWaitingForPrintResources = true
        waitForPrintResources()
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        guard webView === printView, navigation === activeNavigation else {
            return
        }

        finishGeneration(with: .failure(error))
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        guard webView === printView, navigation === activeNavigation else {
            return
        }

        finishGeneration(with: .failure(error))
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard webView === printView, generationCompletion != nil else {
            return
        }

        finishGeneration(with: .failure(DocumentPreviewError.webContentProcessTerminated))
    }

    private func waitForPrintResources() {
        let waitToken = UUID()
        resourceWaitToken = waitToken
        resourceWatchdog?.cancel()
        resourceWatchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard
                !Task.isCancelled,
                let self,
                self.resourceWaitToken == waitToken,
                self.generationCompletion != nil
            else {
                return
            }

            self.finishGeneration(with: .failure(DocumentPreviewError.resourceLoadTimedOut))
        }

        printView.callAsyncJavaScript(
            Self.printResourcesReadyScript,
            arguments: [:],
            in: nil,
            in: .defaultClient
        ) { [weak self] result in
            guard let self else {
                return
            }

            guard
                self.isWaitingForPrintResources,
                self.resourceWaitToken == waitToken,
                self.generationCompletion != nil
            else {
                return
            }

            self.isWaitingForPrintResources = false
            self.resourceWaitToken = nil
            self.resourceWatchdog?.cancel()
            self.resourceWatchdog = nil

            switch result {
            case .success:
                self.createPDF()
            case .failure(let error):
                self.finishGeneration(with: .failure(error))
            }
        }
    }

    private func createPDF() {
        guard let window = readView.window ?? pdfView.window ?? NSApp.keyWindow ?? NSApp.mainWindow else {
            finishGeneration(with: .failure(DocumentPreviewError.missingPrintWindow))
            return
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WritingApp-\(UUID().uuidString)")
            .appendingPathExtension("pdf")

        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: 595.28, height: 841.89)
        printInfo.orientation = .portrait
        printInfo.scalingFactor = 1
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.headerAndFooter] = false
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = outputURL

        let operation = printView.printOperation(with: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        operation.canSpawnSeparateThread = true

        activePrintOperation = operation
        activePrintOperationID = ObjectIdentifier(operation)
        pendingPDFURL = outputURL
        operation.runModal(
            for: window,
            delegate: self,
            didRun: #selector(printOperationDidRun(_:success:contextInfo:)),
            contextInfo: nil
        )
    }

    @objc
    private nonisolated func printOperationDidRun(
        _ operation: NSPrintOperation,
        success: Bool,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        let operationID = ObjectIdentifier(operation)
        Task { @MainActor [weak self] in
            self?.completePrintOperation(operationID: operationID, succeeded: success)
        }
    }

    private func completePrintOperation(operationID: ObjectIdentifier, succeeded: Bool) {
        guard operationID == activePrintOperationID else {
            if let abandonedURL = abandonedPrintURLs.removeValue(forKey: operationID) {
                try? FileManager.default.removeItem(at: abandonedURL)
            }
            return
        }

        guard let outputURL = pendingPDFURL else {
            activePrintOperation = nil
            activePrintOperationID = nil
            finishGeneration(with: .failure(DocumentPreviewError.printOperationFailed))
            return
        }

        pendingPDFURL = nil
        activePrintOperation = nil
        activePrintOperationID = nil

        guard succeeded else {
            try? FileManager.default.removeItem(at: outputURL)
            finishGeneration(with: .failure(DocumentPreviewError.printOperationFailed))
            return
        }

        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
            let byteCount = attributes[.size] as? NSNumber,
            byteCount.intValue > 0,
            let document = PDFDocument(url: outputURL)
        else {
            try? FileManager.default.removeItem(at: outputURL)
            finishGeneration(with: .failure(DocumentPreviewError.invalidGeneratedPDF))
            return
        }

        let previousURL = cachedPDFURL
        cachedPDFURL = outputURL
        pdfView.document = document

        if let previousURL, previousURL != outputURL {
            try? FileManager.default.removeItem(at: previousURL)
        }

        finishGeneration(with: .success(outputURL))
    }

    private func finishGeneration(with result: Result<URL, Error>) {
        if let activePrintOperationID, let pendingPDFURL {
            abandonedPrintURLs[activePrintOperationID] = pendingPDFURL
            self.activePrintOperation = nil
            self.activePrintOperationID = nil
            self.pendingPDFURL = nil
        }

        let completion = generationCompletion
        generationCompletion = nil
        activeNavigation = nil
        isWaitingForPrintResources = false
        resourceWaitToken = nil
        resourceWatchdog?.cancel()
        resourceWatchdog = nil
        completion?(result)
    }

    private static func makeWebConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.shouldPrintBackgrounds = true

        let pagePreferences = WKWebpagePreferences()
        pagePreferences.allowsContentJavaScript = false
        configuration.defaultWebpagePreferences = pagePreferences

        return configuration
    }

    private static func loadDocumentCSS() -> String {
        let cssURL = Bundle.main.url(forResource: "document", withExtension: "css")
            ?? Bundle.module.url(forResource: "document", withExtension: "css")

        guard let cssURL else {
            preconditionFailure("The bundled document.css resource is required.")
        }

        do {
            return try String(contentsOf: cssURL, encoding: .utf8)
        } catch {
            preconditionFailure("Unable to read bundled document.css: \(error.localizedDescription)")
        }
    }

    private static let printResourcesReadyScript = """
        const fontsReady = document.fonts ? document.fonts.ready : Promise.resolve();
        const imagesReady = Promise.all(Array.from(document.images).map(async (image) => {
          if (!image.complete) {
            await new Promise((resolve) => {
              image.addEventListener('load', resolve, { once: true });
              image.addEventListener('error', resolve, { once: true });
            });
          }

          if (typeof image.decode === 'function') {
            try {
              await image.decode();
            } catch (_) {
              // Failed images have already reached a terminal state and should not stall printing.
            }
          }
        }));

        await Promise.all([fontsReady, imagesReady]);
        // This web view stays detached, so requestAnimationFrame is not a reliable completion signal.
        return true;
        """
}

private enum DocumentPreviewError: LocalizedError {
    case generationInProgress
    case resourceLoadTimedOut
    case webContentProcessTerminated
    case missingPrintWindow
    case printOperationFailed
    case invalidGeneratedPDF

    var errorDescription: String? {
        switch self {
        case .generationInProgress:
            "A PDF preview is already being created."
        case .resourceLoadTimedOut:
            "The document's fonts or images did not finish loading."
        case .webContentProcessTerminated:
            "The document renderer stopped before the PDF was ready."
        case .missingPrintWindow:
            "A document window is required to create the PDF preview."
        case .printOperationFailed:
            "The PDF print operation did not complete."
        case .invalidGeneratedPDF:
            "The generated PDF could not be opened."
        }
    }
}
