import AppKit

@MainActor
final class EditorWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate, NSMenuItemValidation {
    private enum Mode: Int {
        case write
        case read
        case pdf
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
    private var lastGeneratedMarkdown: String?
    private var lastGeneratedBaseURL: URL?
    private var exportAfterPDFGeneration = false
    private var isGeneratingPDF = false {
        didSet {
            progressIndicator.isHidden = !isGeneratingPDF
            if isGeneratingPDF {
                progressIndicator.startAnimation(nil)
            } else {
                progressIndicator.stopAnimation(nil)
            }
            exportToolbarItem?.isEnabled = !isGeneratingPDF
        }
    }

    init(document: WritingDocument) {
        let previewController = DocumentPreviewController()
        self.previewController = previewController
        self.writingDocument = document
        self.modeControl = NSSegmentedControl(
            labels: ["Write", "Read", "PDF"],
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

    @objc func showPDFMode(_ sender: Any?) {
        setMode(.pdf)
    }

    @objc func exportPDF(_ sender: Any?) {
        guard let document = writingDocument, let window else { return }

        let baseURL = document.fileURL?.deletingLastPathComponent()
        let cachedPDFIsCurrent = previewController.cachedPDFURL != nil
            && lastGeneratedMarkdown == document.markdown
            && lastGeneratedBaseURL == baseURL

        if cachedPDFIsCurrent, !isGeneratingPDF {
            previewController.exportCachedPDF(from: window)
            return
        }

        setMode(.pdf, exportWhenReady: true)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(showWriteMode(_:)):
            menuItem.state = mode == .write ? .on : .off
            return true
        case #selector(showReadMode(_:)):
            menuItem.state = mode == .read ? .on : .off
            return true
        case #selector(showPDFMode(_:)):
            menuItem.state = mode == .pdf ? .on : .off
            return true
        case #selector(exportPDF(_:)):
            return !isGeneratingPDF
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
            item.toolTip = "Switch between writing, reading, and the actual PDF"
            item.view = modeControl
            return item

        case Self.exportItemIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Export PDF"
            item.paletteLabel = "Export PDF"
            item.toolTip = "Export the PDF shown in preview"
            item.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Export PDF")
            item.target = self
            item.action = #selector(exportPDF(_:))
            item.isEnabled = !isGeneratingPDF
            exportToolbarItem = item
            return item

        default:
            return nil
        }
    }

    private func configureContentViews() {
        let rootView = NSView()
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        rootViewController.view = rootView

        addChildView(editorViewController.view, to: rootView)
        addChildView(previewController.readView, to: rootView)
        addChildView(previewController.pdfView, to: rootView)

        previewController.readView.isHidden = true
        previewController.pdfView.isHidden = true

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .regular
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.isHidden = true
        rootView.addSubview(progressIndicator)
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressIndicator.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: rootView.centerYAnchor),
        ])

        window?.contentViewController = rootViewController
    }

    private func configureToolbar(for window: NSWindow) {
        modeControl.segmentStyle = .rounded
        modeControl.selectedSegment = Mode.write.rawValue
        modeControl.target = self
        modeControl.action = #selector(modeControlChanged(_:))
        modeControl.setAccessibilityLabel("Document mode")
        modeControl.widthAnchor.constraint(equalToConstant: 210).isActive = true

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

    private func setMode(_ nextMode: Mode, exportWhenReady: Bool = false) {
        guard let document = writingDocument else { return }

        mode = nextMode
        modeControl.selectedSegment = nextMode.rawValue

        editorViewController.view.isHidden = nextMode != .write
        previewController.readView.isHidden = nextMode != .read
        previewController.pdfView.isHidden = nextMode != .pdf

        switch nextMode {
        case .write:
            editorViewController.focusEditor()

        case .read:
            previewController.showReadPreview(
                markdown: document.markdown,
                baseURL: document.fileURL?.deletingLastPathComponent()
            )

        case .pdf:
            generatePDF(exportWhenReady: exportWhenReady)
        }
    }

    private func generatePDF(exportWhenReady: Bool) {
        guard let document = writingDocument else { return }

        exportAfterPDFGeneration = exportAfterPDFGeneration || exportWhenReady
        guard !isGeneratingPDF else { return }

        let markdown = document.markdown
        let baseURL = document.fileURL?.deletingLastPathComponent()
        isGeneratingPDF = true

        previewController.generatePDF(
            markdown: markdown,
            baseURL: baseURL
        ) { [weak self] result in
            guard let self else { return }
            self.isGeneratingPDF = false

            switch result {
            case .success:
                self.lastGeneratedMarkdown = markdown
                self.lastGeneratedBaseURL = baseURL

                let shouldExport = self.exportAfterPDFGeneration
                self.exportAfterPDFGeneration = false
                let currentBaseURL = self.writingDocument?.fileURL?.deletingLastPathComponent()
                let generatedPDFIsCurrent = self.writingDocument?.markdown == markdown
                    && currentBaseURL == baseURL

                if !generatedPDFIsCurrent, self.mode == .pdf || shouldExport {
                    self.generatePDF(exportWhenReady: shouldExport)
                } else if shouldExport, let window = self.window {
                    self.previewController.exportCachedPDF(from: window)
                }
            case .failure(let error):
                self.exportAfterPDFGeneration = false
                self.presentPDFError(error)
            }
        }
    }

    private func presentPDFError(_ error: Error) {
        guard let window else { return }

        let alert = NSAlert(error: error)
        alert.messageText = "The PDF could not be prepared"
        alert.informativeText = "Your Markdown is unchanged. Try opening PDF preview again."
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
        case .pdf:
            generatePDF(exportWhenReady: false)
        }
    }
}
