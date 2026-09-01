import AppKit

/// A plain-text Markdown editor backed by an explicitly constructed TextKit 2 stack.
///
/// Presentation attributes live only in the text storage. Callers persist `string`, so
/// paragraph focus can never alter the Markdown source of truth.
@MainActor
final class FocusedTextView: NSTextView {
    private let contentStorage: NSTextContentStorage
    private let modernLayoutManager: NSTextLayoutManager
    private var theme: DocumentTheme
    private var editorBehaviorState: EditorBehaviorState
    private var focusedParagraphRange = NSRange(location: NSNotFound, length: 0)
    private var isApplyingPresentationAttributes = false
    private var lastAppliedInset = NSSize(width: -1, height: -1)

    init(
        theme: DocumentTheme = .defaultTheme,
        editorBehaviorState: EditorBehaviorState = .defaultState
    ) {
        let contentStorage = NSTextContentStorage()
        let layoutManager = NSTextLayoutManager()
        let textContainer = NSTextContainer(
            size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        )

        contentStorage.addTextLayoutManager(layoutManager)
        layoutManager.textContainer = textContainer

        self.contentStorage = contentStorage
        self.modernLayoutManager = layoutManager
        self.theme = theme
        self.editorBehaviorState = editorBehaviorState

        super.init(frame: .zero, textContainer: textContainer)

        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        textContainer.lineFragmentPadding = 0

        isRichText = false
        importsGraphics = false
        allowsUndo = true
        isEditable = true
        isSelectable = true
        isHorizontallyResizable = false
        isVerticallyResizable = true
        minSize = .zero
        maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        autoresizingMask = [.width]
        drawsBackground = true
        backgroundColor = theme.backgroundColor
        insertionPointColor = theme.textColor
        selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .foregroundColor: NSColor.selectedTextColor,
        ]

        // Smart substitutions are valuable in prose editors, but silently changing Markdown
        // punctuation makes source files surprising and can break syntax.
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false

        typingAttributes = focusedAttributes
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updateTextContainerInsetIfNeeded()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        restyleForCurrentTheme()
    }

    func applyTheme(_ theme: DocumentTheme) {
        self.theme = theme
        restyleForCurrentTheme()
    }

    func applyEditorBehaviorState(_ state: EditorBehaviorState) {
        guard state != editorBehaviorState else { return }

        let paragraphFocusChanged = state.paragraphFocusEnabled
            != editorBehaviorState.paragraphFocusEnabled
        let typewriterScrollingChanged = state.typewriterScrollingEnabled
            != editorBehaviorState.typewriterScrollingEnabled
        editorBehaviorState = state

        if paragraphFocusChanged {
            restyleForCurrentTheme()
        }

        if typewriterScrollingChanged {
            lastAppliedInset = NSSize(width: -1, height: -1)
            updateTextContainerInsetIfNeeded()
            if state.typewriterScrollingEnabled {
                scrollSelectionToTypewriterPosition()
            }
        }
    }

    /// Replaces source text without registering an undo action or emitting a document edit.
    func loadMarkdown(_ markdown: String) {
        withoutUndoRegistration {
            isApplyingPresentationAttributes = true

            let attributedString = NSAttributedString(
                string: markdown,
                attributes: editorBehaviorState.paragraphFocusEnabled
                    ? dimmedAttributes
                    : focusedAttributes
            )
            textStorage?.setAttributedString(attributedString)
            focusedParagraphRange = NSRange(location: NSNotFound, length: 0)
            setSelectedRange(NSRange(location: 0, length: 0))
            isApplyingPresentationAttributes = false
        }
        applyParagraphFocus()
    }

    /// Applies focus only to affected paragraphs, keeping per-keystroke work independent of
    /// total document size. Pass the post-edit range for paste and multi-paragraph edits.
    func applyParagraphFocus(editedRange: NSRange? = nil) {
        guard !isApplyingPresentationAttributes, let textStorage else { return }
        guard editorBehaviorState.paragraphFocusEnabled else {
            focusedParagraphRange = NSRange(location: NSNotFound, length: 0)
            typingAttributes = focusedAttributes
            return
        }

        isApplyingPresentationAttributes = true
        defer { isApplyingPresentationAttributes = false }

        let source = string as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        let nextFocusedRange = paragraphRange(for: selectedRange(), in: source)

        withoutUndoRegistration {
            textStorage.beginEditing()

            if focusedParagraphRange.location != NSNotFound {
                let oldRange = clamped(focusedParagraphRange, to: fullRange)
                if oldRange.length > 0 {
                    textStorage.addAttribute(.foregroundColor, value: dimmedTextColor, range: oldRange)
                }
            }

            if let editedRange {
                let affectedRange = paragraphRange(for: editedRange, in: source)
                if affectedRange.length > 0 {
                    textStorage.addAttribute(.foregroundColor, value: dimmedTextColor, range: affectedRange)
                }
            }

            if nextFocusedRange.length > 0 {
                textStorage.addAttribute(
                    .foregroundColor,
                    value: theme.textColor,
                    range: nextFocusedRange
                )
            }

            textStorage.endEditing()
        }

        focusedParagraphRange = nextFocusedRange
        typingAttributes = focusedAttributes
    }

    /// Keeps the insertion point near the vertical reading position. Generous top and bottom
    /// text-container insets let the first and last paragraphs reach the same position.
    func scrollSelectionToTypewriterPosition() {
        guard editorBehaviorState.typewriterScrollingEnabled,
              selectedRange().length == 0,
              let window,
              let scrollView = enclosingScrollView
        else { return }

        layoutSubtreeIfNeeded()

        var actualRange = NSRange(location: NSNotFound, length: 0)
        let screenRect = firstRect(forCharacterRange: selectedRange(), actualRange: &actualRange)
        // An insertion-point rect may legitimately have zero width.
        guard screenRect.height > 0, screenRect.origin.x.isFinite, screenRect.origin.y.isFinite else {
            return
        }

        let windowRect = window.convertFromScreen(screenRect)
        let editorRect = convert(windowRect, from: nil)
        let clipView = scrollView.contentView
        let maximumY = max(0, bounds.height - clipView.bounds.height)
        let proposedY = editorRect.midY
            - (clipView.bounds.height * DocumentTheme.typewriterPosition)
        let targetY = min(maximumY, max(0, proposedY))

        guard abs(clipView.bounds.origin.y - targetY) > 0.5 else { return }
        clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: targetY))
        scrollView.reflectScrolledClipView(clipView)
    }

    var isApplyingFocusStyling: Bool {
        isApplyingPresentationAttributes
    }

    func updateViewportMetrics() {
        updateTextContainerInsetIfNeeded()
    }

    @objc func setHeading(_ sender: Any?) {
        let level = (sender as? NSMenuItem)?.tag ?? 0
        performMarkdownEdit { source, selection in
            MarkdownFormatting.heading(level: level, source: source, selection: selection)
        }
    }

    @objc func promoteHeading(_ sender: Any?) {
        performMarkdownEdit { source, selection in
            MarkdownFormatting.adjustHeading(
                promoting: true,
                source: source,
                selection: selection
            )
        }
    }

    @objc func demoteHeading(_ sender: Any?) {
        performMarkdownEdit { source, selection in
            MarkdownFormatting.adjustHeading(
                promoting: false,
                source: source,
                selection: selection
            )
        }
    }

    @objc func toggleBold(_ sender: Any?) {
        toggleInline(prefix: "**")
    }

    @objc func toggleItalic(_ sender: Any?) {
        performMarkdownEdit { source, selection in
            MarkdownFormatting.toggleItalic(source: source, selection: selection)
        }
    }

    @objc func toggleStrikethrough(_ sender: Any?) {
        toggleInline(prefix: "~~")
    }

    @objc func toggleInlineCode(_ sender: Any?) {
        performMarkdownEdit { source, selection in
            MarkdownFormatting.toggleInlineCode(source: source, selection: selection)
        }
    }

    @objc func insertLink(_ sender: Any?) {
        performMarkdownEdit { source, selection in
            MarkdownFormatting.link(source: source, selection: selection)
        }
    }

    @objc func toggleBlockQuote(_ sender: Any?) {
        toggleBlock(.quote)
    }

    @objc func toggleUnorderedList(_ sender: Any?) {
        toggleBlock(.unorderedList)
    }

    @objc func toggleOrderedList(_ sender: Any?) {
        toggleBlock(.orderedList)
    }

    @objc func toggleTaskList(_ sender: Any?) {
        toggleBlock(.taskList)
    }

    @objc func toggleCodeBlock(_ sender: Any?) {
        performMarkdownEdit { source, selection in
            MarkdownFormatting.fencedCode(source: source, selection: selection)
        }
    }

    private var dimmedTextColor: NSColor {
        let alpha: CGFloat = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? 0.58 : 0.32
        return theme.textColor.withAlphaComponent(alpha)
    }

    private var focusedAttributes: [NSAttributedString.Key: Any] {
        [
            .font: DocumentTheme.bodyFont,
            .foregroundColor: theme.textColor,
            .paragraphStyle: DocumentTheme.paragraphStyle,
        ]
    }

    private var dimmedAttributes: [NSAttributedString.Key: Any] {
        [
            .font: DocumentTheme.bodyFont,
            .foregroundColor: dimmedTextColor,
            .paragraphStyle: DocumentTheme.paragraphStyle,
        ]
    }

    private func updateTextContainerInsetIfNeeded() {
        guard let scrollView = enclosingScrollView else { return }

        let viewportSize = scrollView.contentView.bounds.size
        let horizontalInset = max(
            DocumentTheme.minimumHorizontalInset,
            floor((viewportSize.width - DocumentTheme.maximumLineWidth) / 2)
        )
        let verticalInset = editorBehaviorState.typewriterScrollingEnabled
            ? max(
                DocumentTheme.minimumVerticalInset,
                floor(viewportSize.height * DocumentTheme.typewriterPosition)
            )
            : DocumentTheme.minimumVerticalInset
        let proposedInset = NSSize(width: horizontalInset, height: verticalInset)

        guard abs(lastAppliedInset.width - proposedInset.width) > 0.5
                || abs(lastAppliedInset.height - proposedInset.height) > 0.5
        else { return }

        lastAppliedInset = proposedInset
        textContainerInset = proposedInset
    }

    private func restyleForCurrentTheme() {
        guard let textStorage else { return }

        backgroundColor = theme.backgroundColor
        insertionPointColor = theme.textColor
        enclosingScrollView?.backgroundColor = theme.backgroundColor

        withoutUndoRegistration {
            isApplyingPresentationAttributes = true
            defer { isApplyingPresentationAttributes = false }

            let fullRange = NSRange(location: 0, length: textStorage.length)
            if fullRange.length > 0 {
                let baseAttributes = editorBehaviorState.paragraphFocusEnabled
                    ? dimmedAttributes
                    : focusedAttributes
                textStorage.addAttributes(baseAttributes, range: fullRange)
            }
            focusedParagraphRange = NSRange(location: NSNotFound, length: 0)
        }
        applyParagraphFocus()
    }

    private func toggleInline(prefix: String) {
        performMarkdownEdit { source, selection in
            MarkdownFormatting.toggleInline(
                prefix: prefix,
                source: source,
                selection: selection
            )
        }
    }

    private func toggleBlock(_ style: MarkdownFormatting.BlockStyle) {
        performMarkdownEdit { source, selection in
            MarkdownFormatting.block(style, source: source, selection: selection)
        }
    }

    private func performMarkdownEdit(
        _ makeEdit: (String, NSRange) -> MarkdownEdit?
    ) {
        guard isEditable else { return }

        if hasMarkedText() {
            unmarkText()
        }
        guard let edit = makeEdit(string, selectedRange()) else { return }

        breakUndoCoalescing()
        insertText(edit.replacement, replacementRange: edit.replacementRange)
        setSelectedRange(edit.selectionAfter)
        breakUndoCoalescing()
    }

    private func paragraphRange(for proposedRange: NSRange, in source: NSString) -> NSRange {
        let fullRange = NSRange(location: 0, length: source.length)
        guard fullRange.length > 0 else { return NSRange(location: 0, length: 0) }

        let safeRange = clamped(proposedRange, to: fullRange)
        if safeRange.location == source.length {
            // NSString accepts an insertion point at the end and returns the trailing paragraph.
            return source.paragraphRange(for: NSRange(location: source.length, length: 0))
        }
        return source.paragraphRange(for: safeRange)
    }

    private func clamped(_ range: NSRange, to fullRange: NSRange) -> NSRange {
        guard range.location != NSNotFound else { return NSRange(location: 0, length: 0) }

        let location = min(max(0, range.location), fullRange.length)
        let availableLength = max(0, fullRange.length - location)
        return NSRange(location: location, length: min(max(0, range.length), availableLength))
    }

    private func withoutUndoRegistration(_ body: () -> Void) {
        let manager = undoManager
        let shouldDisable = manager?.isUndoRegistrationEnabled == true
        if shouldDisable {
            manager?.disableUndoRegistration()
        }
        body()
        if shouldDisable {
            manager?.enableUndoRegistration()
        }
    }
}
