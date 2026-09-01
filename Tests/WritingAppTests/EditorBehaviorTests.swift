import AppKit
import Foundation
import Testing
@testable import WritingApp

@Suite("Editor behavior preferences")
struct EditorBehaviorPreferenceTests {
    @Test("Paragraph focus starts on while typewriter scrolling starts off")
    func defaultAndPersistedState() throws {
        let suiteName = "EditorBehaviorPreferenceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = EditorBehaviorPreferences(defaults: defaults)

        #expect(preferences.selectedState == .defaultState)
        #expect(preferences.selectedState.paragraphFocusEnabled)
        #expect(!preferences.selectedState.typewriterScrollingEnabled)

        let typewriterOnly = EditorBehaviorState(
            paragraphFocusEnabled: false,
            typewriterScrollingEnabled: true
        )
        preferences.select(typewriterOnly)

        #expect(EditorBehaviorPreferences(defaults: defaults).selectedState == typewriterOnly)
    }
}

@Suite("Native editor behaviors")
@MainActor
struct NativeEditorBehaviorTests {
    @Test("View menu toggles and persists independent behavior settings")
    func viewMenuState() throws {
        let suiteName = "EditorBehaviorMenuTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let notificationCenter = NotificationCenter()
        let preferences = EditorBehaviorPreferences(defaults: defaults)
        let controller = EditorBehaviorController(
            preferences: preferences,
            notificationCenter: notificationCenter
        )
        let menu = MainMenuFactory.makeViewMenu(editorBehaviorController: controller)
        let visibleItems = menu.items.filter { !$0.isSeparatorItem }

        #expect(visibleItems.map(\.title) == [
            "Toggle Read View",
            "Paragraph Focus",
            "Typewriter Scrolling",
            "Enter Full Screen",
        ])

        let paragraphItem = try #require(menu.item(withTitle: "Paragraph Focus"))
        let typewriterItem = try #require(menu.item(withTitle: "Typewriter Scrolling"))
        let recorder = EditorBehaviorNotificationRecorder()
        let observer = notificationCenter.addObserver(
            forName: .editorBehaviorDidChange,
            object: controller,
            queue: nil
        ) { notification in
            recorder.record(notification.userInfo?[EditorBehaviorController.notificationStateKey])
        }
        defer { notificationCenter.removeObserver(observer) }

        _ = controller.validateMenuItem(paragraphItem)
        _ = controller.validateMenuItem(typewriterItem)
        #expect(paragraphItem.state == .on)
        #expect(typewriterItem.state == .off)

        controller.toggleTypewriterScrolling(typewriterItem)
        controller.toggleParagraphFocus(paragraphItem)
        _ = controller.validateMenuItem(paragraphItem)
        _ = controller.validateMenuItem(typewriterItem)

        let expected = EditorBehaviorState(
            paragraphFocusEnabled: false,
            typewriterScrollingEnabled: true
        )
        #expect(controller.selectedState == expected)
        #expect(preferences.selectedState == expected)
        #expect(recorder.count == 2)
        #expect(recorder.latestState == expected)
        #expect(paragraphItem.state == .off)
        #expect(typewriterItem.state == .on)
    }

    @Test("Paragraph focus is presentational and stays off across theme changes")
    func paragraphFocusToggle() throws {
        let textView = FocusedTextView(
            theme: .paper,
            editorBehaviorState: .defaultState
        )
        let markdown = "첫 문단\n\n둘째 문단"
        let secondParagraph = (markdown as NSString).range(of: "둘째")
        textView.loadMarkdown(markdown)
        textView.setSelectedRange(secondParagraph)
        textView.applyParagraphFocus()

        let textStorage = try #require(textView.textStorage)
        let firstColor = try #require(
            textStorage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        )
        let selectedColor = try #require(
            textStorage.attribute(
                .foregroundColor,
                at: secondParagraph.location,
                effectiveRange: nil
            ) as? NSColor
        )
        #expect(firstColor != DocumentTheme.paper.textColor)
        #expect(selectedColor == DocumentTheme.paper.textColor)

        let focusOff = EditorBehaviorState(
            paragraphFocusEnabled: false,
            typewriterScrollingEnabled: false
        )
        textView.applyEditorBehaviorState(focusOff)
        textView.applyTheme(.midnight)

        let firstColorAfter = try #require(
            textStorage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        )
        let secondColorAfter = try #require(
            textStorage.attribute(
                .foregroundColor,
                at: secondParagraph.location,
                effectiveRange: nil
            ) as? NSColor
        )
        #expect(textView.string == markdown)
        #expect(textView.selectedRange() == secondParagraph)
        #expect(firstColorAfter == DocumentTheme.midnight.textColor)
        #expect(secondColorAfter == DocumentTheme.midnight.textColor)
        #expect(!textView.isApplyingFocusStyling)
    }

    @Test("Typewriter scrolling changes the vertical inset only when enabled")
    func typewriterInset() {
        let textView = FocusedTextView(editorBehaviorState: .defaultState)
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
        textView.frame = scrollView.contentView.bounds
        scrollView.documentView = textView
        textView.updateViewportMetrics()

        #expect(textView.textContainerInset.height == DocumentTheme.minimumVerticalInset)

        let typewriterOn = EditorBehaviorState(
            paragraphFocusEnabled: true,
            typewriterScrollingEnabled: true
        )
        textView.applyEditorBehaviorState(typewriterOn)
        let expectedInset = max(
            DocumentTheme.minimumVerticalInset,
            floor(scrollView.contentView.bounds.height * DocumentTheme.typewriterPosition)
        )
        #expect(textView.textContainerInset.height == expectedInset)

        textView.applyEditorBehaviorState(.defaultState)
        #expect(textView.textContainerInset.height == DocumentTheme.minimumVerticalInset)
    }
}

private final class EditorBehaviorNotificationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var states: [EditorBehaviorState] = []

    var count: Int {
        lock.withLock { states.count }
    }

    var latestState: EditorBehaviorState? {
        lock.withLock { states.last }
    }

    func record(_ value: Any?) {
        guard let state = value as? EditorBehaviorState else { return }
        lock.withLock { states.append(state) }
    }
}
