import AppKit
import Foundation

struct EditorBehaviorState: Equatable, Sendable {
    static let defaultState = EditorBehaviorState(
        paragraphFocusEnabled: true,
        typewriterScrollingEnabled: false
    )

    let paragraphFocusEnabled: Bool
    let typewriterScrollingEnabled: Bool
}

struct EditorBehaviorPreferences {
    static let paragraphFocusKey = "WritingApp.ParagraphFocus"
    static let typewriterScrollingKey = "WritingApp.TypewriterScrolling"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedState: EditorBehaviorState {
        EditorBehaviorState(
            paragraphFocusEnabled: value(
                forKey: Self.paragraphFocusKey,
                defaultValue: EditorBehaviorState.defaultState.paragraphFocusEnabled
            ),
            typewriterScrollingEnabled: value(
                forKey: Self.typewriterScrollingKey,
                defaultValue: EditorBehaviorState.defaultState.typewriterScrollingEnabled
            )
        )
    }

    func select(_ state: EditorBehaviorState) {
        defaults.set(state.paragraphFocusEnabled, forKey: Self.paragraphFocusKey)
        defaults.set(state.typewriterScrollingEnabled, forKey: Self.typewriterScrollingKey)
    }

    private func value(forKey key: String, defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }
}

@MainActor
final class EditorBehaviorController: NSObject, NSMenuItemValidation {
    nonisolated static let notificationStateKey = "state"

    private let preferences: EditorBehaviorPreferences
    private let notificationCenter: NotificationCenter

    private(set) var selectedState: EditorBehaviorState

    init(
        preferences: EditorBehaviorPreferences = EditorBehaviorPreferences(),
        notificationCenter: NotificationCenter = .default
    ) {
        self.preferences = preferences
        self.notificationCenter = notificationCenter
        self.selectedState = preferences.selectedState
        super.init()
    }

    @objc func toggleParagraphFocus(_ sender: NSMenuItem) {
        select(EditorBehaviorState(
            paragraphFocusEnabled: !selectedState.paragraphFocusEnabled,
            typewriterScrollingEnabled: selectedState.typewriterScrollingEnabled
        ))
    }

    @objc func toggleTypewriterScrolling(_ sender: NSMenuItem) {
        select(EditorBehaviorState(
            paragraphFocusEnabled: selectedState.paragraphFocusEnabled,
            typewriterScrollingEnabled: !selectedState.typewriterScrollingEnabled
        ))
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleParagraphFocus(_:)):
            menuItem.state = selectedState.paragraphFocusEnabled ? .on : .off
        case #selector(toggleTypewriterScrolling(_:)):
            menuItem.state = selectedState.typewriterScrollingEnabled ? .on : .off
        default:
            break
        }
        return true
    }

    private func select(_ state: EditorBehaviorState) {
        guard state != selectedState else { return }

        selectedState = state
        preferences.select(state)
        notificationCenter.post(
            name: .editorBehaviorDidChange,
            object: self,
            userInfo: [Self.notificationStateKey: state]
        )
    }
}

extension Notification.Name {
    static let editorBehaviorDidChange = Notification.Name("EditorBehaviorDidChange")
}
