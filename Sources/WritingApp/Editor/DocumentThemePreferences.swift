import AppKit
import Foundation

struct DocumentThemePreferences {
    static let storageKey = "WritingApp.DocumentTheme"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedTheme: DocumentTheme {
        guard let storedValue = defaults.string(forKey: Self.storageKey),
              let theme = DocumentTheme(rawValue: storedValue)
        else {
            return .defaultTheme
        }

        return theme
    }

    func select(_ theme: DocumentTheme) {
        defaults.set(theme.rawValue, forKey: Self.storageKey)
    }
}

@MainActor
final class DocumentThemeController: NSObject, NSMenuItemValidation {
    static let notificationThemeKey = "theme"

    private let preferences: DocumentThemePreferences
    private let notificationCenter: NotificationCenter

    private(set) var selectedTheme: DocumentTheme

    init(
        preferences: DocumentThemePreferences = DocumentThemePreferences(),
        notificationCenter: NotificationCenter = .default
    ) {
        self.preferences = preferences
        self.notificationCenter = notificationCenter
        self.selectedTheme = preferences.selectedTheme
        super.init()
    }

    func applyAppearance(to application: NSApplication) {
        application.appearance = selectedTheme.appearance
    }

    @objc func selectTheme(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let theme = DocumentTheme(rawValue: rawValue),
              theme != selectedTheme
        else {
            return
        }

        selectedTheme = theme
        preferences.select(theme)
        applyAppearance(to: NSApplication.shared)
        notificationCenter.post(
            name: .documentThemeDidChange,
            object: self,
            userInfo: [Self.notificationThemeKey: theme]
        )
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(selectTheme(_:)),
              let rawValue = menuItem.representedObject as? String
        else {
            return true
        }

        menuItem.state = rawValue == selectedTheme.rawValue ? .on : .off
        return DocumentTheme(rawValue: rawValue) != nil
    }
}

extension Notification.Name {
    static let documentThemeDidChange = Notification.Name("DocumentThemeDidChange")
}
