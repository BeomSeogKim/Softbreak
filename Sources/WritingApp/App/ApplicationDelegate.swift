import AppKit

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private var documentController: MarkdownDocumentController?
    private var recentDocumentsMenuCoordinator: RecentDocumentsMenuCoordinator?
    private var themeController: DocumentThemeController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false

        // NSDocumentController keeps the first instance created during launch as
        // its shared controller. Install ours before AppKit asks for one so the
        // document lifecycle also works without relying on a generated nib.
        let documentController = MarkdownDocumentController()
        let recentDocumentsMenuCoordinator = RecentDocumentsMenuCoordinator(
            documentController: documentController
        )
        let themeController = DocumentThemeController()

        self.documentController = documentController
        self.recentDocumentsMenuCoordinator = recentDocumentsMenuCoordinator
        self.themeController = themeController

        let application = notification.object as? NSApplication ?? NSApplication.shared
        themeController.applyAppearance(to: application)
        application.mainMenu = MainMenuFactory.makeMainMenu(
            for: application,
            documentController: documentController,
            recentDocumentsMenuCoordinator: recentDocumentsMenuCoordinator,
            themeController: themeController
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        guard let documentController else { return false }
        documentController.newDocument(sender)
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let documentController else { return }

        for url in urls {
            documentController.openDocument(
                withContentsOf: url,
                display: true
            ) { [weak documentController] _, _, error in
                if let error {
                    documentController?.presentError(error)
                }
            }
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        guard !flag, let documentController else { return true }

        if let document = documentController.currentDocument {
            document.showWindows()
        } else {
            documentController.newDocument(sender)
        }

        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
