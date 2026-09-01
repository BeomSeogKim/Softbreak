import AppKit
import Foundation
import Testing
@testable import WritingApp

@Suite("Document themes")
struct DocumentThemeTests {
    @Test("The catalog contains three explicit light and dark themes")
    func catalogFamilies() {
        #expect(DocumentTheme.defaultTheme == .paper)
        #expect(DocumentTheme.lightThemes == [.paper, .snow, .sage])
        #expect(DocumentTheme.darkThemes == [.ink, .midnight, .pine])
        #expect(Set(DocumentTheme.allCases.map(\.rawValue)).count == DocumentTheme.allCases.count)
    }

    @Test("Every theme keeps document text and accents readable")
    func paletteContrast() throws {
        for theme in DocumentTheme.allCases {
            let background = try rgb(theme.palette.background)

            #expect(contrast(background, try rgb(theme.palette.text)) >= 7)
            #expect(contrast(background, try rgb(theme.palette.mutedText)) >= 4.5)
            #expect(contrast(background, try rgb(theme.palette.link)) >= 4.5)
        }
    }

    @Test("Theme CSS is explicit and carries every palette token")
    func cssTokens() {
        for theme in DocumentTheme.allCases {
            let css = theme.screenCSS
            let palette = theme.palette

            #expect(css.contains("color-scheme: \(theme.family.rawValue);"))
            #expect(css.contains("--document-background: \(palette.background);"))
            #expect(css.contains("--document-text: \(palette.text);"))
            #expect(css.contains("--document-muted-text: \(palette.mutedText);"))
            #expect(css.contains("--document-surface: \(palette.surface);"))
            #expect(css.contains("--document-border: \(palette.border);"))
            #expect(css.contains("--document-quote-border: \(palette.quoteBorder);"))
            #expect(css.contains("--document-link: \(palette.link);"))
            #expect(css.contains("print-color-adjust: exact"))
            #expect(css.contains("@page {\n  background: \(palette.background);"))
            #expect(!css.contains("prefers-color-scheme"))
        }
    }

    @Test("Theme preferences persist and reject unknown values")
    func preferenceRoundTrip() throws {
        let suiteName = "DocumentThemeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = DocumentThemePreferences(defaults: defaults)

        #expect(preferences.selectedTheme == .paper)

        for theme in DocumentTheme.allCases {
            preferences.select(theme)
            #expect(DocumentThemePreferences(defaults: defaults).selectedTheme == theme)
        }

        defaults.set("removed-theme", forKey: DocumentThemePreferences.storageKey)
        #expect(preferences.selectedTheme == .paper)
    }

    @Test("A theme-only change invalidates a render request")
    func renderRequestIdentityIncludesTheme() {
        let paper = DocumentRenderRequest(
            markdown: "# 같은 문서",
            baseURL: URL(fileURLWithPath: "/tmp/draft"),
            theme: .paper
        )
        let midnight = DocumentRenderRequest(
            markdown: paper.markdown,
            baseURL: paper.baseURL,
            theme: .midnight
        )

        #expect(paper != midnight)
        #expect(paper == DocumentRenderRequest(
            markdown: paper.markdown,
            baseURL: paper.baseURL,
            theme: .paper
        ))
    }

    private func rgb(_ hex: String) throws -> (Double, Double, Double) {
        let digits = hex.dropFirst()
        let value = try #require(UInt32(digits, radix: 16))
        return (
            Double((value >> 16) & 0xFF) / 255,
            Double((value >> 8) & 0xFF) / 255,
            Double(value & 0xFF) / 255
        )
    }

    private func contrast(
        _ first: (Double, Double, Double),
        _ second: (Double, Double, Double)
    ) -> Double {
        let values = [relativeLuminance(first), relativeLuminance(second)].sorted(by: >)
        return (values[0] + 0.05) / (values[1] + 0.05)
    }

    private func relativeLuminance(_ color: (Double, Double, Double)) -> Double {
        func linear(_ component: Double) -> Double {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        return (0.2126 * linear(color.0))
            + (0.7152 * linear(color.1))
            + (0.0722 * linear(color.2))
    }
}

@Suite("Native theme application")
@MainActor
struct NativeThemeApplicationTests {
    @Test("Changing theme preserves Markdown and selection")
    func textViewPresentationOnly() {
        let textView = FocusedTextView(theme: .paper)
        let markdown = "첫 문단 ✍️\n\n둘째 문단"
        let selection = NSRange(location: (markdown as NSString).range(of: "둘째").location, length: 2)

        textView.loadMarkdown(markdown)
        textView.setSelectedRange(selection)
        textView.applyParagraphFocus()
        textView.applyTheme(.midnight)

        #expect(textView.string == markdown)
        #expect(textView.selectedRange() == selection)
        #expect(textView.backgroundColor == DocumentTheme.midnight.backgroundColor)
        #expect(textView.insertionPointColor == DocumentTheme.midnight.textColor)
        #expect(!textView.isApplyingFocusStyling)
    }

    @Test("Theme menu exposes and persists every catalog item")
    func themeMenu() throws {
        let suiteName = "ThemeMenuTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            NSApplication.shared.appearance = nil
        }

        let notificationCenter = NotificationCenter()
        let preferences = DocumentThemePreferences(defaults: defaults)
        let controller = DocumentThemeController(
            preferences: preferences,
            notificationCenter: notificationCenter
        )
        let menu = MainMenuFactory.makeThemeMenu(themeController: controller)

        #expect(menu.items.map(\.title) == ["Light", "Dark"])
        #expect(menu.items[0].submenu?.items.map(\.title) == ["Paper", "Snow", "Sage"])
        #expect(menu.items[1].submenu?.items.map(\.title) == ["Ink", "Midnight", "Pine"])

        let paperItem = try #require(menu.items[0].submenu?.items[0])
        let midnightItem = try #require(menu.items[1].submenu?.items[1])
        let notificationCount = NotificationCounter()
        let observer = notificationCenter.addObserver(
            forName: .documentThemeDidChange,
            object: controller,
            queue: nil
        ) { _ in
            notificationCount.increment()
        }
        defer { notificationCenter.removeObserver(observer) }

        controller.selectTheme(paperItem)
        #expect(notificationCount.value == 0)

        controller.selectTheme(midnightItem)
        #expect(notificationCount.value == 1)
        #expect(preferences.selectedTheme == .midnight)

        _ = controller.validateMenuItem(paperItem)
        _ = controller.validateMenuItem(midnightItem)
        #expect(paperItem.state == .off)
        #expect(midnightItem.state == .on)
    }
}

private final class NotificationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock { count += 1 }
    }
}
