import AppKit

@MainActor
final class EditorViewController: NSViewController, NSTextViewDelegate {
    let textView: FocusedTextView

    var onMarkdownChange: ((String) -> Void)?

    private var theme: DocumentTheme
    private var pendingEditedRange: NSRange?
    private var isLoadingMarkdown = false

    init(theme: DocumentTheme = .defaultTheme) {
        self.theme = theme
        self.textView = FocusedTextView(theme: theme)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var markdown: String {
        get { textView.string }
        set {
            guard newValue != textView.string else { return }
            isLoadingMarkdown = true
            textView.loadMarkdown(newValue)
            isLoadingMarkdown = false
        }
    }

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = theme.backgroundColor
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = textView

        textView.frame = scrollView.contentView.bounds
        textView.drawsBackground = true
        textView.backgroundColor = theme.backgroundColor
        textView.delegate = self

        let rootView = NSView()
        rootView.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: rootView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
        ])

        view = rootView
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        focusEditor()
        textView.applyParagraphFocus()
        textView.scrollSelectionToTypewriterPosition()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        textView.updateViewportMetrics()
    }

    func focusEditor() {
        view.window?.makeFirstResponder(textView)
    }

    func applyTheme(_ theme: DocumentTheme) {
        self.theme = theme
        if isViewLoaded {
            textView.applyTheme(theme)
        }
    }

    func textView(
        _ textView: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        let replacementLength = ((replacementString ?? "") as NSString).length
        let postEditRange = NSRange(location: affectedCharRange.location, length: replacementLength)

        if let pendingEditedRange {
            self.pendingEditedRange = NSUnionRange(pendingEditedRange, postEditRange)
        } else {
            pendingEditedRange = postEditRange
        }
        return true
    }

    func textDidChange(_ notification: Notification) {
        guard let focusedTextView = notification.object as? FocusedTextView,
              !focusedTextView.isApplyingFocusStyling
        else { return }

        focusedTextView.applyParagraphFocus(editedRange: pendingEditedRange)
        pendingEditedRange = nil

        if !isLoadingMarkdown {
            onMarkdownChange?(focusedTextView.string)
        }
        focusedTextView.scrollSelectionToTypewriterPosition()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard let focusedTextView = notification.object as? FocusedTextView,
              !focusedTextView.isApplyingFocusStyling
        else { return }

        focusedTextView.applyParagraphFocus()
        focusedTextView.scrollSelectionToTypewriterPosition()
    }
}
