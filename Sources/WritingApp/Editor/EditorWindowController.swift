import AppKit
import UniformTypeIdentifiers

@MainActor
final class EditorWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate, NSMenuItemValidation {
    private enum Mode: Int {
        case write
        case read
    }

    private struct PDFRequest: Equatable {
        let markdown: String
        let baseURL: URL?
    }

    private static let modeItemIdentifier = NSToolbarItem.Identifier("WritingApp.Mode")
    private static let exportItemIdentifier = NSToolbarItem.Identifier("WritingApp.ExportPDF")

    private weak var writingDocument: WritingDocument?
    private let editorViewController = EditorViewController()
    private let previewController: DocumentPreviewController
    private let rootViewController = NSViewController()
    private let modeControl: NSSegmentedControl
    private let progressIndicator = NSProgressIndicator()

    private weak var exportToolbarItem: NSToolbarItem?
    private var mode = Mode.write
    private var activePDFRequest: PDFRequest?
    private var pendingPDFDestination: URL?
    private var isChoosingPDFDestination = false {
        didSet { updateExportAvailability() }
    }
    private var isGeneratingPDF = false {
        didSet {
            progressIndicator.isHidden = !isGeneratingPDF
            if isGeneratingPDF {
                progressIndicator.startAnimation(nil)
            } else {
                progressIndicator.stopAnimation(nil)
            }
            updateExportAvailability()
        }
    }

    private var exportIsBusy: Bool {
        isChoosingPDFDestination || isGeneratingPDF
    }

    init(document: WritingDocument) {
        let previewController = DocumentPreviewController()
        self.previewController = previewController
        self.writingDocument = document
        self.modeControl = NSSegmentedControl(
            labels: ["Write", "Read"],
            trackingMode: .selectOne,
            target: nil,
            action: nil
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 640, height: 480)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.toolbarStyle = .unifiedCompact
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("WritingApp.EditorWindow")

        super.init(window: window)

        window.delegate = self
        configureContentViews()
        configureToolbar(for: window)

        editorViewController.markdown = document.markdown
        editorViewController.onMarkdownChange = { [weak self] markdown in
            guard let self, let document = self.writingDocument, document.markdown != markdown else {
                return
            }
            document.replaceMarkdownFromEditor(markdown)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(documentDidReplaceContents(_:)),
            name: .markdownDocumentDidReplaceContents,
            object: document
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(documentFileURLDidChange(_:)),
            name: .markdownDocumentDidChangeFileURL,
            object: document
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        showWriteMode(nil)
    }

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        writingDocument?.undoManager
    }

    @objc func showWriteMode(_ sender: Any?) {
        setMode(.write)
    }

    @objc func showReadMode(_ sender: Any?) {
        setMode(.read)
    }

    @objc func toggleReadMode(_ sender: Any?) {
        setMode(mode == .read ? .write : .read)
    }

    @objc func exportPDF(_ sender: Any?) {
        guard !exportIsBusy, let document = writingDocument, let window else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        let documentName = document.fileURL?.deletingPathExtension().lastPathComponent
        panel.nameFieldStringValue = "\(documentName ?? "Document").pdf"

        isChoosingPDFDestination = true
        panel.beginSheetModal(for: window) { [weak self] response in
            Task { @MainActor in
                guard let self else { return }
                self.isChoosingPDFDestination = false
                guard response == .OK, let destinationURL = panel.url else { return }

                self.pendingPDFDestination = destinationURL
                self.generatePDF()
            }
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(showWriteMode(_:)):
            menuItem.state = mode == .write ? .on : .off
            return true
        case #selector(showReadMode(_:)):
            menuItem.state = mode == .read ? .on : .off
            return true
        case #selector(toggleReadMode(_:)):
            menuItem.state = mode == .read ? .on : .off
            return true
        case #selector(exportPDF(_:)):
            return !exportIsBusy
        default:
            return true
        }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .flexibleSpace,
            Self.modeItemIdentifier,
            Self.exportItemIdentifier,
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .flexibleSpace,
            Self.modeItemIdentifier,
            .flexibleSpace,
            Self.exportItemIdentifier,
        ]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case Self.modeItemIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Document Mode"
            item.paletteLabel = "Document Mode"
            item.toolTip = "Switch between source writing and rendered reading"
            item.view = modeControl
            return item

        case Self.exportItemIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Export PDF"
            item.paletteLabel = "Export PDF"
            item.toolTip = "Generate and export an A4 PDF"
            item.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Export PDF")
            item.target = self
            item.action = #selector(exportPDF(_:))
            item.isEnabled = !exportIsBusy
            exportToolbarItem = item
            return item

        default:
            return nil
        }
    }

    private func configureContentViews() {
        let rootView = NSView()
        rootViewController.view = rootView

        addChildView(editorViewController.view, to: rootView)
        addChildView(previewController.readView, to: rootView)

        previewController.readView.isHidden = true

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.isHidden = true
        rootView.addSubview(progressIndicator)
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressIndicator.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -20),
            progressIndicator.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -20),
        ])

        window?.contentViewController = rootViewController
    }

    private func configureToolbar(for window: NSWindow) {
        modeControl.segmentStyle = .rounded
        modeControl.selectedSegment = Mode.write.rawValue
        modeControl.target = self
        modeControl.action = #selector(modeControlChanged(_:))
        modeControl.setAccessibilityLabel("Document mode")
        modeControl.widthAnchor.constraint(equalToConstant: 150).isActive = true

        let toolbar = NSToolbar(identifier: "WritingApp.EditorToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.showsBaselineSeparator = false
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.centeredItemIdentifier = Self.modeItemIdentifier
        window.toolbar = toolbar
    }

    private func addChildView(_ child: NSView, to rootView: NSView) {
        rootView.addSubview(child)
        child.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            child.topAnchor.constraint(equalTo: rootView.topAnchor),
            child.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
        ])
    }

    @objc private func modeControlChanged(_ sender: NSSegmentedControl) {
        guard let nextMode = Mode(rawValue: sender.selectedSegment) else { return }
        setMode(nextMode)
    }

    private func setMode(_ nextMode: Mode) {
        guard let document = writingDocument else { return }

        mode = nextMode
        modeControl.selectedSegment = nextMode.rawValue

        editorViewController.view.isHidden = nextMode != .write
        previewController.readView.isHidden = nextMode != .read

        switch nextMode {
        case .write:
            editorViewController.focusEditor()

        case .read:
            previewController.showReadPreview(
                markdown: document.markdown,
                baseURL: document.fileURL?.deletingLastPathComponent()
            )
            window?.makeFirstResponder(previewController.readView)
        }
    }

    private func generatePDF() {
        guard let document = writingDocument, pendingPDFDestination != nil else { return }
        guard !isGeneratingPDF else { return }

        let request = PDFRequest(
            markdown: document.markdown,
            baseURL: document.fileURL?.deletingLastPathComponent()
        )
        activePDFRequest = request
        isGeneratingPDF = true

        previewController.generatePDF(
            markdown: request.markdown,
            baseURL: request.baseURL
        ) { [weak self] result in
            guard let self, self.activePDFRequest == request else { return }

            self.activePDFRequest = nil
            self.isGeneratingPDF = false
            let latestRequest = self.currentPDFRequest

            if latestRequest != request {
                self.generatePDF()
                return
            }

            switch result {
            case .success:
                guard let destinationURL = self.pendingPDFDestination else { return }
                self.pendingPDFDestination = nil
                do {
                    try self.previewController.writeGeneratedPDF(to: destinationURL)
                } catch {
                    self.presentPDFError(error)
                }
            case .failure(let error):
                self.pendingPDFDestination = nil
                self.presentPDFError(error)
            }
        }
    }

    private var currentPDFRequest: PDFRequest? {
        guard let document = writingDocument else { return nil }

        return PDFRequest(
            markdown: document.markdown,
            baseURL: document.fileURL?.deletingLastPathComponent()
        )
    }

    private func presentPDFError(_ error: Error) {
        guard let window else { return }

        let alert = NSAlert(error: error)
        alert.messageText = "The PDF could not be exported"
        alert.informativeText = "Your Markdown is unchanged. Try exporting again."
        alert.beginSheetModal(for: window)
    }

    @objc private func documentDidReplaceContents(_ notification: Notification) {
        guard let document = writingDocument else { return }

        editorViewController.markdown = document.markdown
        switch mode {
        case .write:
            break
        case .read:
            previewController.showReadPreview(
                markdown: document.markdown,
                baseURL: document.fileURL?.deletingLastPathComponent()
            )
        }
    }

    @objc private func documentFileURLDidChange(_ notification: Notification) {
        guard let document = writingDocument else { return }

        switch mode {
        case .write:
            break
        case .read:
            previewController.showReadPreview(
                markdown: document.markdown,
                baseURL: document.fileURL?.deletingLastPathComponent()
            )
        }
    }

    private func updateExportAvailability() {
        exportToolbarItem?.isEnabled = !exportIsBusy
    }
}
