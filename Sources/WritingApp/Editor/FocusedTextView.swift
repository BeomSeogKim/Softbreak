import AppKit

/// A plain-text Markdown editor backed by an explicitly constructed TextKit 2 stack.
///
/// Presentation attributes live only in the text storage. Callers persist `string`, so
/// paragraph focus can never alter the Markdown source of truth.
@MainActor
final class FocusedTextView: NSTextView {
    private enum Metrics {
        static let maximumLineWidth: CGFloat = 700
        static let minimumHorizontalInset: CGFloat = 32
        static let minimumVerticalInset: CGFloat = 64
        static let typewriterPosition: CGFloat = 0.42
    }

    private let contentStorage: NSTextContentStorage
    private let modernLayoutManager: NSTextLayoutManager
    private var focusedParagraphRange = NSRange(location: NSNotFound, length: 0)
    private var isApplyingPresentationAttributes = false
    private var lastAppliedInset = NSSize(width: -1, height: -1)

    private static let editorFont = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)

    private static let paragraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 7
        style.paragraphSpacing = 2
        style.lineBreakMode = .byWordWrapping
        return style
    }()

    init() {
        let contentStorage = NSTextContentStorage()
        let layoutManager = NSTextLayoutManager()
        let textContainer = NSTextContainer(
            size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        )

        contentStorage.addTextLayoutManager(layoutManager)
        layoutManager.textContainer = textContainer

        self.contentStorage = contentStorage
        self.modernLayoutManager = layoutManager

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
        drawsBackground = false
        insertionPointColor = .labelColor
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
        restyleForCurrentAppearance()
    }

    /// Replaces source text without registering an undo action or emitting a document edit.
    func loadMarkdown(_ markdown: String) {
        withoutUndoRegistration {
            isApplyingPresentationAttributes = true

            let attributedString = NSAttributedString(
                string: markdown,
                attributes: dimmedAttributes
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
                textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: nextFocusedRange)
            }

            textStorage.endEditing()
        }

        focusedParagraphRange = nextFocusedRange
        typingAttributes = focusedAttributes
    }

    /// Keeps the insertion point near the vertical reading position. Generous top and bottom
    /// text-container insets let the first and last paragraphs reach the same position.
    func scrollSelectionToTypewriterPosition() {
        guard selectedRange().length == 0,
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
        let proposedY = editorRect.midY - (clipView.bounds.height * Metrics.typewriterPosition)
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

    private var dimmedTextColor: NSColor {
        let alpha: CGFloat = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? 0.58 : 0.32
        return NSColor.labelColor.withAlphaComponent(alpha)
    }

    private var focusedAttributes: [NSAttributedString.Key: Any] {
        [
            .font: Self.editorFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: Self.paragraphStyle,
        ]
    }

    private var dimmedAttributes: [NSAttributedString.Key: Any] {
        [
            .font: Self.editorFont,
            .foregroundColor: dimmedTextColor,
            .paragraphStyle: Self.paragraphStyle,
        ]
    }

    private func updateTextContainerInsetIfNeeded() {
        guard let scrollView = enclosingScrollView else { return }

        let viewportSize = scrollView.contentView.bounds.size
        let horizontalInset = max(
            Metrics.minimumHorizontalInset,
            floor((viewportSize.width - Metrics.maximumLineWidth) / 2)
        )
        let verticalInset = max(
            Metrics.minimumVerticalInset,
            floor(viewportSize.height * Metrics.typewriterPosition)
        )
        let proposedInset = NSSize(width: horizontalInset, height: verticalInset)

        guard abs(lastAppliedInset.width - proposedInset.width) > 0.5
                || abs(lastAppliedInset.height - proposedInset.height) > 0.5
        else { return }

        lastAppliedInset = proposedInset
        textContainerInset = proposedInset
    }

    private func restyleForCurrentAppearance() {
        guard let textStorage else { return }

        withoutUndoRegistration {
            isApplyingPresentationAttributes = true
            defer { isApplyingPresentationAttributes = false }

            let fullRange = NSRange(location: 0, length: textStorage.length)
            if fullRange.length > 0 {
                textStorage.addAttributes(dimmedAttributes, range: fullRange)
            }
            focusedParagraphRange = NSRange(location: NSNotFound, length: 0)
        }
        applyParagraphFocus()
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
